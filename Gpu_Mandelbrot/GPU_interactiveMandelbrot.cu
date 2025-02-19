// Mandelbrot explorer, based on my old Julia demo plus parts of Nicolas Melot's Lab 1 code.
// CPU only! Your task: Rewrite for CUDA! Test and evaluate performance.

// Your CUDA version should compile with something like
// nvcc -lglut -lGL interactiveMandelbrotCUDA.cu -o interactiveMandelbrotCUDA

#ifdef __APPLE__
#include <OpenGL/gl.h>
#include <GLUT/glut.h>
#else
#include <GL/glut.h>
#include <GL/gl.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define DIM 512

// Select precision here! float or double!
#define MYFLOAT float
// Image data
unsigned char	*pixels = NULL;
int	 gImageWidth, gImageHeight, size;
float  theTime;
unsigned char *d_pixels;
// Init image data
void initBitmap(int width, int height)
{
	if (pixels) free(pixels);

	gImageWidth = width;
	gImageHeight = height;
  	size = width * height * sizeof(char) *4;
	pixels = (unsigned char *)malloc(size);
}


// User controlled parameters
int maxiter = 20;
MYFLOAT offsetx = -200, offsety = 0, zoom = 0;
MYFLOAT scale = 1.5;

// Complex number class
struct cuComplex
{
    MYFLOAT   r;
    MYFLOAT   i;

    __device__ cuComplex( MYFLOAT a, MYFLOAT b ) : r(a), i(b)  {}

    __device__ float magnitude2( void )
    {
        return r * r + i * i;
    }

    __device__ cuComplex operator*(const cuComplex& a)
    {
        return cuComplex(r*a.r - i*a.i, i*a.r + r*a.i);
    }

    __device__    cuComplex operator+(const cuComplex& a)
    {
        return cuComplex(r+a.r, i+a.i);
    }
};

    
    
__device__ int mandelbrot_gpu(int x, int y, MYFLOAT offsetx, MYFLOAT offsety,MYFLOAT  scale,
       int  maxiter, int gImageWidth,int gImageHeight ){

    MYFLOAT jx = scale * (MYFLOAT)(gImageWidth/2 - x + offsetx/ scale)/(gImageWidth/2);
    MYFLOAT jy = scale * (MYFLOAT)(gImageHeight/2 - y +offsety/ scale)/(gImageWidth/2);

    cuComplex c(jx, jy);
    cuComplex a(jx, jy);

    int i = 0;
    for (i=0; i<maxiter; i++)
    {
        a = a * a + c;
        if (a.magnitude2() > 1000)
            return i;
    }

    return i;
    
}

__global__ void computeFractal(unsigned char *ptr, MYFLOAT  d_offsetx, MYFLOAT d_offsety, MYFLOAT d_scale,
        int  d_maxiter, int d_gImageWidth, int d_gImageHeight){

    // map from x, y to pixel position
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int offset = x + y * gridDim.x * blockDim.x;

    // now calculate the value at that position
    int fractalValue = mandelbrot_gpu( x, y, d_offsetx, d_offsety, d_scale, d_maxiter, d_gImageWidth, d_gImageHeight);
    
    // Colorize it
    int red = 255 * fractalValue/ d_maxiter;
    if (red > 255) red = 255 - red;
    int green = 255 * fractalValue*4/ d_maxiter;
    if (green > 255) green = 255 - green;
    int blue = 255 * fractalValue*20/ d_maxiter;
    if (blue > 255) blue = 255 - blue;
    
    ptr[offset*4 + 0] = red;
    ptr[offset*4 + 1] = green;
    ptr[offset*4 + 2] = blue;
    
    ptr[offset*4 + 3] = 255;
}

char print_help = 0;

// Yuck, GLUT text is old junk that should be avoided... but it will have to do
static void print_str(void *font, const char *string)
{
	int i;

	for (i = 0; string[i]; i++)
		glutBitmapCharacter(font, string[i]);
}

void PrintHelp()
{
	if (print_help)
	{
		glPushMatrix();
		glLoadIdentity();
		glOrtho(-0.5, 639.5, -0.5, 479.5, -1.0, 1.0);

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glColor4f(0.f, 0.f, 0.5f, 0.5f);
		glRecti(40, 40, 600, 440);

		glColor3f(1.f, 1.f, 1.f);
		glRasterPos2i(300, 420);
		print_str(GLUT_BITMAP_HELVETICA_18, "Help");

		glRasterPos2i(60, 390);
		print_str(GLUT_BITMAP_HELVETICA_18, "h - Toggle Help");
		glRasterPos2i(60, 300);
		print_str(GLUT_BITMAP_HELVETICA_18, "Left click + drag - move picture");
		glRasterPos2i(60, 270);
		print_str(GLUT_BITMAP_HELVETICA_18,
		    "Right click + drag up/down - unzoom/zoom");
		glRasterPos2i(60, 240);
		print_str(GLUT_BITMAP_HELVETICA_18, "+ - Increase max. iterations by 32");
		glRasterPos2i(60, 210);
		print_str(GLUT_BITMAP_HELVETICA_18, "- - Decrease max. iterations by 32");
		glRasterPos2i(0, 0);

		glDisable(GL_BLEND);
		
		glPopMatrix();
	}
}

// Compute fractal and display image
void Draw()
{
    

    cudaEvent_t myEvent, laterEvent;
    cudaEventCreate(&myEvent);
    cudaEventCreate(&laterEvent);
    cudaEventRecord(myEvent, 0);

    cudaMalloc((void **)&d_pixels, size); 

    cudaMemcpy(d_pixels,pixels,size,cudaMemcpyHostToDevice);

    int BLOCK = 16;
	dim3 dimBlock( BLOCK, BLOCK );
	dim3 dimGrid( gImageWidth/BLOCK, gImageHeight/BLOCK );

	computeFractal<<< dimGrid,dimBlock>>> (d_pixels,  offsetx, offsety, scale,
         maxiter, gImageWidth, gImageHeight );

    cudaThreadSynchronize();

    cudaMemcpy(pixels,d_pixels,size,cudaMemcpyDeviceToHost);

    cudaEventRecord(laterEvent, 0);
    cudaEventSynchronize(laterEvent); 
    cudaEventElapsedTime(&theTime, myEvent, laterEvent);
    printf("%f\n", theTime);
    cudaFree(d_pixels);
    cudaEventDestroy(myEvent);
    cudaEventDestroy(laterEvent);

// Dump the whole picture onto the screen. (Old-style OpenGL but without lots of geometry that doesn't matter so much.)
	glClearColor( 0.0, 0.0, 0.0, 1.0 );
	glClear( GL_COLOR_BUFFER_BIT );
	glDrawPixels( gImageWidth, gImageHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixels );
	
	if (print_help)
		PrintHelp();
	
	glutSwapBuffers();
}

char explore = 1;

static void Reshape(int width, int height)
{
	glViewport(0, 0, width, height);
	glLoadIdentity();
	glOrtho(-0.5f, width - 0.5f, -0.5f, height - 0.5f, -1.f, 1.f);
	initBitmap(width, height);

	glutPostRedisplay();
}

int mouse_x, mouse_y, mouse_btn;

// Mouse down
static void mouse_button(int button, int state, int x, int y)
{
	if (state == GLUT_DOWN)
	{
		// Record start position
		mouse_x = x;
		mouse_y = y;
		mouse_btn = button;
	}
}

// Drag mouse
static void mouse_motion(int x, int y)
{
	if (mouse_btn == 0)
	// Ordinary mouse button - move
	{
		offsetx += (x - mouse_x)*scale;
		mouse_x = x;
		offsety += (mouse_y - y)*scale;
		mouse_y = y;
		
		glutPostRedisplay();
	}
	else
	// Alt mouse button - scale
	{
		scale *= pow(1.1, y - mouse_y);
		mouse_y = y;
		glutPostRedisplay();
	}
}

void KeyboardProc(unsigned char key, int x, int y)
{
	switch (key)
	{
	case 27: /* Escape key */
	case 'q':
	case 'Q':
		exit(0);
		break;
	case '+':
		maxiter += maxiter < 1024 - 32 ? 32 : 0;
		break;
	case '-':
		maxiter -= maxiter > 0 + 32 ? 32 : 0;
		break;
	case 'h':
		print_help = !print_help;
		break;
	}
	glutPostRedisplay();
}

// Main program, inits
int main( int argc, char** argv) 
{
	glutInit(&argc, argv);
	glutInitDisplayMode( GLUT_DOUBLE | GLUT_RGBA );
	glutInitWindowSize( DIM, DIM );
	glutCreateWindow("Mandelbrot explorer (CPU)");
	glutDisplayFunc(Draw);
	glutMouseFunc(mouse_button);
	glutMotionFunc(mouse_motion);
	glutKeyboardFunc(KeyboardProc);
	glutReshapeFunc(Reshape);
	
	initBitmap(DIM, DIM);
	
	glutMainLoop();
}

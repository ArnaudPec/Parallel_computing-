/*
 * Image filter in OpenCL
 */

#define KERNELSIZE 2
#define WORK_GROUP_DIM 16
#define LOCAL_SIZE 16*16

__kernel void filter(__global unsigned char *image, __global unsigned char *out, const unsigned int n, const unsigned int m)
{ 
  unsigned int i = get_global_id(1) % 512;
  unsigned int j = get_global_id(0) % 512;

  //size_t wg_i = get_group_id(1) % WORK_GROUP_DIM*2;
  //size_t wg_j = get_group_id(0) % WORK_GROUP_DIM*2;
	
	//size of local image
	unsigned local_n = n/32;
	//unsigned local_m = m/32;
  unsigned local_i = get_local_id(1);//i + wg_i * WORK_GROUP_DIM;
  unsigned local_j = get_local_id(2);//i + wg_i * WORK_GROUP_DIM;

  __local unsigned char* local_image[LOCAL_SIZE];
  __local unsigned char* local_out[LOCAL_SIZE];
  unsigned local_v = (local_i * local_n + local_j) * 3;
  unsigned v = (i*n+j)*3;
  local_image[local_v+0] = image[v+0];
  local_image[local_v+1] = image[v+1];
  local_image[local_v+2] = image[v+2];

	barrier(CLK_LOCAL_MEM_FENCE);

  int k, l;
  unsigned int sumx, sumy, sumz;

  //IMAGES SHOULD BE CALCULATE IN LOCAL MEMORY AND THEN WRITTEN TO GLOBAL
	int divby = (2*KERNELSIZE+1)*(2*KERNELSIZE+1);
	if (j < n && i < m) // If inside image
	{
	
		if (i >= KERNELSIZE && i < m-KERNELSIZE && j >= KERNELSIZE && j < n-KERNELSIZE)
		{
		// Filter kernel
			sumx=0;sumy=0;sumz=0;
			for(k=-KERNELSIZE;k<=KERNELSIZE;k++)
				for(l=-KERNELSIZE;l<=KERNELSIZE;l++)	
				{
					//sumx += local_image[local_v+0];
					//sumy += local_image[local_v+1];
					//sumz += local_image[local_v+2];
				}
			local_out[local_v+0] = sumx/divby;
			local_out[local_v+1] = sumy/divby;
			local_out[local_v+2] = sumz/divby;
		}
		else
		// Edge pixels are not filtered
		{
			local_out[local_v+0] = local_image[local_v+0];
			local_out[local_v+1] = local_image[local_v+1];
			local_out[local_v+2] = local_image[local_v+2];
		}
	}
	out[(i*n+j)*3+0] = local_image[local_v+0];
	out[(i*n+j)*3+1] = local_image[local_v+1];
	out[(i*n+j)*3+2] = local_image[local_v+2];
}

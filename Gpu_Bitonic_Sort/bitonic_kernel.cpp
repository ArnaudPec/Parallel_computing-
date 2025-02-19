
// This is not really C++-code but pretty plain C code, but we compile it
// as C++ so we can integrate with CUDA seamlessly.

// If you plan on submitting your solution for the Parallel Sorting Contest,
// please keep the split into main file and kernel file, so we can easily
// insert other data.

static void exchange(int *i, int *j)
{
	int k;
	k = *i;
	*i = *j;
	*j = k;
}

// No, this is not GPU code yet but just a copy of the CPU code, but this
// is where I want to see your GPU code!
__global__ void bitonic(int *data, int N)
{
  int i,j,k;
  for (k=2;k<=N;k=2*k) // Outer loop, double size for each step
  {
    for (j=k>>1;j>0;j=j>>1) // Inner loop, half size for each step
    {
      for (i=0;i<N;i++) // Loop over data
      {
        int ixj=i^j; // Calculate indexing!
        if ((ixj)>i)
        {
          if ((i&k)==0 && data[i]>data[ixj]) exchange(&data[i],&data[ixj]);
          if ((i&k)!=0 && data[i]<data[ixj]) exchange(&data[i],&data[ixj]);
        }
      }
    }
  }
}

void bitonic_gpu(int *data, int N){

    int *d_data;
    const int size = N*sizeof(int);
    
    cudaMalloc((void**)&d_data, size);

    dim3 dimBlock(1);
    dim3 dimGrid(1);
    
    cudaMemcpy(d_data, data, size,cudaMemcpyHostToDevice);
    
    bitonic <<< dimGrid, dimBlock >>> (d_data, size);
    
    cudaThreadSynchronize();

    cudaMemcpy(data, d_data, size,cudaMemcpyDeviceToHost);
    
    cudaFree(d_data);
    

    
}

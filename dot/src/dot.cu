/*
 testeando
 */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

const static int threadsPerBlock = 1024;
const static int blocksPerGrid = 10;
const static int M = 3;
/////////

__global__ void dot_pdt(float* d_vtr_a, float* d_vtr_b, const int M,
		float* d_vtr_o);

int parseCLI(const int argc, char**argv, char *filename_0, char *filename_1);
void read_mtx(const char *in_filename, float *mtx, const unsigned int M,
		const unsigned int N);

/////////

int main(int argc, char** argv) {

	// CPU
	char in_filename_1[20], in_filename_2[20];
	float *vtr_a, *vtr_b, *vtr_out;

	vtr_a = (float*) malloc(M * sizeof(float));
	vtr_b = (float*) malloc(M * sizeof(float));
	vtr_out = (float*) malloc(blocksPerGrid * sizeof(float));

//	parseCLI(argc, argv, in_filename_1, in_filename_2);
//	read_mtx(in_filename_1, vtr_a, M, 1);
//	read_mtx(in_filename_2, vtr_b, M, 1);
	vtr_a[0] = 1.;
	vtr_a[1] = 1.;
	vtr_a[2] = 1.;
	vtr_b[0] = 1.;
	vtr_b[1] = 1.;
	vtr_b[2] = 1.;

//
	printf("Vtor a:\n");
	for (size_t i = 0; i < M; i++) {
		printf("%f\t", vtr_a[i]);
	}
	printf("\nVtor b:\n");
	for (size_t i = 0; i < M; i++) {
		printf("%f\t", vtr_b[i]);
	}
	printf("\n");
//

// GPU
	dim3 dimBlock(threadsPerBlock, 1, 1);
	dim3 dimGrid(blocksPerGrid, 1, 1);
	float *d_vtr_a, *d_vtr_b, *d_vtr_out;
	cudaMalloc((void**) &d_vtr_a, M * sizeof(float));
	cudaMalloc((void**) &d_vtr_b, M * sizeof(float));
	cudaMalloc((void**) &d_vtr_out, blocksPerGrid * sizeof(float));
	cudaMemcpy(d_vtr_a, vtr_a, M * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(d_vtr_b, vtr_b, M * sizeof(float), cudaMemcpyHostToDevice);

	dot_pdt<<<dimGrid, dimBlock>>>(d_vtr_a, d_vtr_b, M, d_vtr_out);

	cudaMemcpy(vtr_out, d_vtr_out, M * sizeof(float), cudaMemcpyDeviceToHost);

	float result = 0.;
	for (size_t i = 0; i < M; ++i) {
		printf("vtr_out:  %f\n", vtr_out[i]);
		result += vtr_out[i];
	}
	printf("dot pdt:  %f\n", result);

	return 0;
}

///////// Kernels

__global__ void dot_pdt(float* d_vtr_a, float* d_vtr_b, const int M,
		float* d_vtr_o) {

	int ti = threadIdx.x + blockIdx.x * blockDim.x;
	__shared__ float tmp_sum[threadsPerBlock];
	tmp_sum[threadIdx.x] = 0;

	float tmp = 0;
	while (ti < M) {
		tmp += d_vtr_a[ti] * d_vtr_b[ti];
		ti += blockDim.x * gridDim.x;
	}
	tmp_sum[threadIdx.x] = tmp;
	__syncthreads();

	// Ahora tengo q reducir tmp_sum
	size_t idx = blockDim.x / 2;
	while (idx != 0) {
		if (threadIdx.x < idx) {
			tmp_sum[threadIdx.x] += tmp_sum[threadIdx.x + idx];
		}
		__syncthreads();
		idx /= 2;
	}
	if (threadIdx.x == 0) {
		d_vtr_o[blockIdx.x] = tmp_sum[0];
	}

	return;
}

///////// Functions

int parseCLI(const int argc, char**argv, char *filename_0, char *filename_1) {

	bool m_flag, v_flag;
	char c;

	while ((c = getopt(argc, argv, "m:v:")) != -1) {
		switch (c) {
		case 'm':
			if (sizeof(optarg) > 20) {
				fprintf(stderr, "Filename too big.\n");
				return 1;
			}

			memset(filename_0, '\0', sizeof(optarg));
			strcpy(filename_0, optarg);
			m_flag = 1;
			break;
		case 'v':
			if (sizeof(optarg) > 20) {
				fprintf(stderr, "Filename too big.\n");
				return 1;
			}

			memset(filename_1, '\0', sizeof(optarg));
			strcpy(filename_1, optarg);
			filename_1 = optarg;
			v_flag = 1;
			break;
		case '?':
			if (optopt == 'i' || optopt == 'o')
				fprintf(stderr, "Options require an argument.\n");
			return 1;
		default:
			fprintf(stderr, "Mal\n");
			return 1;
		}
	}
	if ((m_flag && v_flag) != 1) {
		fprintf(stderr, "Mal\n");
		return 1;
	}

	return 0;
}

void read_mtx(const char *in_filename, float *mtx, const unsigned int M,
		const unsigned int N) {

	FILE *in_file;
	in_file = fopen(in_filename, "r");

	for (int i = 0; i < M; i++) {
		for (int j = 0; j < N; j++) {
			fscanf(in_file, "%f\t", &mtx[j + (i * N)]);
		}
	}

	return;
}

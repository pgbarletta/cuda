
/**
 * Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 */
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cuda.h>

#include "chemfiles.hpp"

const static int threadsPerBlock = 1024;
const static int blocksPerGrid = 10;
const static int M = 3;
/////////

__global__ void dot_pdt(float* d_vtr_a, float* d_vtr_b, const int M,
                float* d_vtr_o);
template <typename T> std::vector<unsigned int> sort_indices(const std::vector<T> &v);

//int parseCLI(const int argc, char**argv, char *filename_0, char *filename_1);
//void read_mtx(const char *in_filename, float *mtx, const unsigned int M,
                //const unsigned int N);

/////////
using V3D = std::array<double, 3>;
using ANA_molecule = std::vector<std::pair<V3D, double>>;

int main(int argc, char **argv)
{
	// CPU

	chemfiles::Trajectory input_pdb_traj("/home/german/labo/16/ANA/1mtn.pdb");
	auto in_frm = input_pdb_traj.read();
	auto in_top = in_frm.topology();
	auto in_xyz = in_frm.positions();
	ANA_molecule tmp_molecule_points, molecule_points;
	std::vector<unsigned int> atom_indices_to_sort;

    for (const auto &residuo : in_top.residues()) {
    	for (const auto &i : residuo) {
            atom_indices_to_sort.push_back(i);
    		V3D atomo_xyz = { in_xyz[i][0], in_xyz[i][1], in_xyz[i][2] };
    		double radio = in_top[i].vdw_radius().value_or(1.5);
    		tmp_molecule_points.push_back(std::make_pair(atomo_xyz, radio));
    	}
    }


	const auto atom_sorting_indices = sort_indices(atom_indices_to_sort);
	molecule_points.reserve(tmp_molecule_points.size());
	for (const auto &i : atom_sorting_indices)
		molecule_points.push_back(std::move(tmp_molecule_points[i]));


    for (const auto &each : molecule_points) {
    	std::cout << each.first[0] << "  " << each.first[1] << "  " << each.first[2] << "  " << each.second << '\n';
    	//std::cout << each.second << '\n';
    }

//	vtr_a = (float*) malloc(M * sizeof(float));





	// GPU
	dim3 dimBlock(threadsPerBlock, 1, 1);
	dim3 dimGrid(blocksPerGrid, 1, 1);
	float *d_vtr_a, *d_vtr_b, *d_vtr_out;
	cudaMalloc((void**) &d_vtr_a, M * sizeof(float));
	cudaMalloc((void**) &d_vtr_b, M * sizeof(float));
	cudaMalloc((void**) &d_vtr_out, blocksPerGrid * sizeof(float));
	//cudaMemcpy(d_vtr_a, vtr_a, M * sizeof(float), cudaMemcpyHostToDevice);


//	dot_pdt<<<dimGrid, dimBlock>>>(d_vtr_a, d_vtr_b, M, d_vtr_out);

//	cudaMemcpy(vtr_out, d_vtr_out, M * sizeof(float), cudaMemcpyDeviceToHost);







	return 0;
}

///////// Functions
// Helper function for getting the indices that sort a vector.
template <typename T>
std::vector<unsigned int> sort_indices(const std::vector<T> &v) {

  // initialize original index locations
  std::vector<unsigned int> idx(v.size());
  std::iota(idx.begin(), idx.end(), 0);

  // sort indices based on comparing values in v
  sort(idx.begin(), idx.end(),
       [&v](unsigned int i1, unsigned int i2) { return v[i1] < v[i2]; });

  return idx;
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

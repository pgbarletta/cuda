
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

/////////

__global__ void init_grilla(float* grilla, int grilla_size, float x_min, float y_min,
		float z_min, float resolution);

template <typename T> std::vector<unsigned int> sort_indices(const std::vector<T> &v);

//int parseCLI(const int argc, char**argv, char *filename_0, char *filename_1);
//void read_mtx(const char *in_filename, float *mtx, const unsigned int M,
                //const unsigned int N);

/////////

int main(int argc, char **argv)
{
	// Get positions and get variables ready.
	chemfiles::Trajectory input_pdb_traj("/home/german/labo/16/ANA/1mtn.pdb");
	auto in_frm = input_pdb_traj.read();
	auto in_top = in_frm.topology();
	auto in_xyz = in_frm.positions();
	const static size_t in_xyz_memsize = in_xyz.size() * 3 * sizeof(double);
	const static size_t in_vdw_memsize = in_xyz.size() * sizeof(double);
	double *tmp_molecule_points, *molecule_points, *tmp_vdw_radii, *vdw_radii;
	std::vector<unsigned int> atom_indices_to_sort(in_xyz.size());

	// Allocate memory.
	tmp_molecule_points = (double*) malloc(in_xyz_memsize);
	tmp_vdw_radii = (double*) malloc(in_vdw_memsize);
	cudaMallocManaged((void**)&molecule_points, in_xyz_memsize);
	cudaMallocManaged((void**)&vdw_radii, in_vdw_memsize);
	cudaStream_t stream1;
	cudaStreamCreate(&stream1);
	cudaMemPrefetchAsync(molecule_points, in_xyz_memsize, cudaCpuDeviceId, stream1);
	cudaMemPrefetchAsync(vdw_radii, in_xyz_memsize, cudaCpuDeviceId, stream1);

	// Get atoms positions and VdW radii.
	size_t j = 0;
    for (const auto &residuo : in_top.residues()) {
    	for (const auto &i : residuo) {
            tmp_molecule_points[j * 3] = in_xyz[i][0];
    		tmp_molecule_points[j * 3 + 1] = in_xyz[i][1];
    		tmp_molecule_points[j * 3 + 2] = in_xyz[i][2];
    		tmp_vdw_radii[j] = in_top[i].vdw_radius().value_or(1.5);

    		atom_indices_to_sort[j] = i;
    		++j;
    	}
    }
	const auto atom_sorting_indices = sort_indices(atom_indices_to_sort);

	// Move sorted data to UM.
	for (size_t i = 0 ; i < in_xyz.size() ; ++i) {
		molecule_points[i * 3] = std::move(tmp_molecule_points[atom_sorting_indices[i] * 3]);
		molecule_points[i * 3 + 1] = std::move(tmp_molecule_points[atom_sorting_indices[i] * 3 + 1]);
		molecule_points[i * 3 + 2] = std::move(tmp_molecule_points[atom_sorting_indices[i] * 3 + 2]);
		vdw_radii[i] = std::move(tmp_vdw_radii[atom_sorting_indices[i]]);
	}
	// Done with unordered data.
	free(tmp_vdw_radii);
	free(tmp_molecule_points);
	//std::cout <<  << "  " << '\n';

	// GPU


	const float x_min = 2.0f;
	const float x_max = 4.0f;
	const float y_min = 8.0f;
	const float y_max = 10.0f;
	const float z_min = -28.0f;
	const float z_max = -30.0f;
	const float rtion = 0.1f;
	const float x_cnt = (x_max - x_min) / rtion;
	const float y_cnt = (y_max - y_min) / rtion;
	const float z_cnt = (z_min - z_max) / rtion;
	const int grilla_size = x_cnt * y_cnt * z_cnt;


	static const int threadsPerBlock = 512;
	static const int blocksPerGrid = 10;
	dim3 dimBlock(threadsPerBlock, 1, 1);
	dim3 dimGrid(blocksPerGrid, 1, 1);
	float *grilla, *grilla_fill;
	cudaMallocManaged((void**)&grilla, sizeof(float) * grilla_size);
	cudaMallocManaged((void**)&grilla_fill, sizeof(float) * grilla_size);

//	cudaMalloc((void**)&grilla, sizeof(float) * 8000);
//	float *tempo = (float *)malloc(sizeof(float) * 8000);


//	cudaMemPrefetchAsync(grilla, sizeof(float) * (x_cnt + y_cnt + z_cnt), 0, 0);


	init_grilla<<<dimGrid, dimBlock>>>(grilla, grilla_size, x_min, y_min, z_min, rtion);

//	cudaMemcpy(grilla, tempo, sizeof(float) * 8000, cudaMemcpyDeviceToHost);

	cudaMemPrefetchAsync(grilla, sizeof(float) * (x_cnt + y_cnt + z_cnt), cudaCpuDeviceId, 0);

	for (size_t i = 0 ; i < grilla_size ; ++i) {
    	std::cout << grilla[i] << '\n';
    }



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

__global__ void init_grilla(float* grilla, int grilla_size, float x_min, float y_min,
		float z_min, float resolution) {

	int ti = threadIdx.x + blockIdx.x * blockDim.x;

	for (int i = ti; i <= (grilla_size/3) ; i++) {
		grilla[i * 3] = x_min + resolution * (float)i;
		grilla[i * 3 + 1] = y_min + resolution * (float)i;
		grilla[i * 3 + 2] = z_min + resolution * (float)i;
	}

	return;
}

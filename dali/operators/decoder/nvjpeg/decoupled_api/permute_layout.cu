// Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "dali/operators/decoder/nvjpeg/decoupled_api/permute_layout.h"
#include "dali/core/static_switch.h"
#include "dali/core/util.h"
#include "dali/core/format.h"
#include "dali/core/error_handling.h"


namespace dali {

template <int64_t C, typename T>
__global__ void permuteToInterleavedK(T *output, const T *input, int64_t comp_size) {
  auto tid = blockIdx.x * blockDim.x + threadIdx.x;
  if (tid >= comp_size) return;
  T *out = output + C * tid;
  for (int c = 0; c < C; ++c) {
    auto l = input[c * comp_size + tid];
    out[c] = l;
  }
}

void PermuteToInterleaved(uint8_t *output, const uint8_t *input,
                          int64_t comp_size, int64_t comp_count, cudaStream_t stream) {
  if (comp_count < 2) {
    cudaMemcpyAsync(output, input, comp_size * comp_count, cudaMemcpyDeviceToDevice, stream);
    return;
  }
  VALUE_SWITCH(comp_count, c_static, (2, 3, 4), (
    int num_blocks = div_ceil(comp_size, 1024);
    int block_size = (comp_size < 1024) ? comp_size : 1024;
    permuteToInterleavedK<c_static>
      <<<num_blocks, block_size, 0, stream>>>(output, input, comp_size);
  ), (  // NOLINT
    DALI_FAIL(make_string("Unsupported number of components: ", comp_count));
  ));  // NOLINT
}

}  // namespace dali

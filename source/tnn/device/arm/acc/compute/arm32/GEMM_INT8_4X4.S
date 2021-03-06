// Tencent is pleased to support the open source community by making TNN available.
//
// Copyright (C) 2020 THL A29 Limited, a Tencent company. All rights reserved.
//
// Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
//
// https://opensource.org/licenses/BSD-3-Clause
//
// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the 
// specific language governing permissions and limitations under the License.

#ifdef __arm__
#ifndef __aarch64__

#include "tnn/device/arm/acc/compute/asm_func_name.S"

.align 5
asm_function GemmInt8Unit4x4 
//void GemmInt8Unit4x4(int8_t* src, const int8_t* weight, int8_t* dst, int src_w_step, int dst_depth, 
//                            int cdiv8, float *scale, int32_t*bias)
src          .req r0
weight       .req r1
dst          .req r2
src_w_step   .req r3
dst_depth    .req r4
cdiv8        .req r5
scale        .req r6
bias         .req r7


push {r4, r5, r6, r7, r8, lr}


//prefetch data
//assume buffer c>=16, even c==8
vld1.8 {q12, q13}, [weight]!
vld1.8 {q14, q15}, [src]!

ldr r4, [sp, #24]
ldr r5, [sp, #28]
ldr r6, [sp, #32]
ldr r7, [sp, #36]
vpush {q4-q7}

C8Start:
    subs cdiv8, cdiv8, #1
    vmull.s8 q0, d28, d24 
    vmull.s8 q1, d30, d24 
    vmull.s8 q2, d28, d26
    vmull.s8 q3, d30, d26
    vmlal.s8 q0, d29, d25
    vmlal.s8 q1, d31, d25
    vrev64.32 q12, q12
    vmlal.s8 q2, d29, d27 
    vmlal.s8 q3, d31, d27
    vrev64.32 q13, q13
    vpaddl.s16 q4, q0 
    vmull.s8 q0, d28, d24 
    vpaddl.s16 q5, q1 
    vmull.s8 q1, d30, d24 
    vpaddl.s16 q6, q2 
    vmull.s8 q2, d28, d26
    vpaddl.s16 q7, q3 
    vmull.s8 q3, d30, d26

    vmlal.s8 q0, d29, d25
    vmlal.s8 q1, d31, d25
    vld1.8 {q12}, [weight]!
    vmlal.s8 q2, d29, d27 
    vmlal.s8 q3, d31, d27
    vld1.8 {q13}, [weight]!
    vpaddl.s16 q8, q0 
    vld1.8 {q14, q15}, [src]!
    vpaddl.s16 q9, q1 
    vpaddl.s16 q10, q2
    vpaddl.s16 q11, q3 
     
    beq LoopEnd 
      
    C8Loop: 
        subs cdiv8, cdiv8, #1
        vmull.s8 q0, d28, d24 
        vmull.s8 q1, d30, d24 
        vmull.s8 q2, d28, d26
        vmull.s8 q3, d30, d26
        vmlal.s8 q0, d29, d25
        vmlal.s8 q1, d31, d25
        vrev64.32 q12, q12
        vmlal.s8 q2, d29, d27 
        vmlal.s8 q3, d31, d27
        vrev64.32 q13, q13
        vpadal.s16 q4, q0 
        vmull.s8 q0, d28, d24 
        vpadal.s16 q5, q1 
        vmull.s8 q1, d30, d24 
        vpadal.s16 q6, q2 
        vmull.s8 q2, d28, d26
        vpadal.s16 q7, q3 
        vmull.s8 q3, d30, d26
        
        vmlal.s8 q0, d29, d25
        vmlal.s8 q1, d31, d25
        vld1.8 {q12}, [weight]!
        vmlal.s8 q2, d29, d27 
        vmlal.s8 q3, d31, d27
        vld1.8 {q13}, [weight]!
        vpadal.s16 q8, q0 
        vpadal.s16 q9, q1 
        vld1.8 {q14, q15}, [src]!
        vpadal.s16 q10, q2
        vpadal.s16 q11, q3 

        bne C8Loop 

      
LoopEnd: 
    //bias q14, scale q15
    vld1.8 {q14}, [bias]
    vmov.s32 q12, 0x3f000000
    vld1.8 {q15}, [scale]
    vmov.s32 q13, 0x3f000000
    //q4 ~ q11  --> q4, q5 
    //c00, c11; c20, c31;  d8 -d11
    //c02, c13; c22, c33;  d12-d15
    //c01, c10; c21, c30   d16-d19
    //c03, c12; c23, c32   d20-d23
    
    //c00 c01, c02 c03
    vpadd.s32 d0, d8, d16
    vpadd.s32 d1, d12, d20 
    //c10 c11, c12 c13
    vpadd.s32 d2, d17, d9
    vpadd.s32 d3, d21, d13 
    //c20 c21 c22 c23
    vpadd.s32 d4, d10, d18 
    vpadd.s32 d5, d14, d22
    //c32 c31 c32 c33
    vpadd.s32 d6, d19, d11 
    vpadd.s32 d7, d23, d15


    //c0x ~ c3x
    vqadd.s32 q0, q14 
    vqadd.s32 q1, q14 
    vqadd.s32 q2, q14 
    vqadd.s32 q3, q14 
    vmov.s32 q4, 0x3f000000
    vmov.s32 q5, 0x3f000000

    //(q2, q3 + bias) * scale --> q0, q1
    vcvt.f32.s32 q0, q0 
    vcvt.f32.s32 q1, q1 
    vcvt.f32.s32 q2, q2 
    vcvt.f32.s32 q3, q3 

    vmla.f32 q12, q0, q15
    vmla.f32 q13, q1, q15
    vmla.f32 q4,  q2, q15
    vmla.f32 q5,  q3, q15

    //f32 --> s8
    vcvt.s32.f32 q12, q12
    vcvt.s32.f32 q13, q13
    vcvt.s32.f32 q4, q4
    vcvt.s32.f32 q5, q5

    vqmovn.s32 d0,q12
    vqmovn.s32 d1,q13
    vqmovn.s32 d2,q4
    vqmovn.s32 d3,q5
    vqmovn.s16 d4,q0
    vqmovn.s16 d6,q1
    
    vst1.s32 d4[0], [dst], dst_depth
    vst1.s32 d4[1], [dst], dst_depth
    vst1.s32 d6[0], [dst], dst_depth
    vst1.s32 d6[1], [dst]
    
vpop {q4-q7}
pop {r4, r5, r6, r7, r8, pc}

#endif
#endif

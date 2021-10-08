module libbc.co.aco;

// Copyright 2018 Sen Han <00hnes@gmail.com>
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

import core.stdc.stdlib;

extern (C) @nogc nothrow:

enum ACO_VERSION_MAJOR = 1;
enum ACO_VERSION_MINOR = 2;
enum ACO_VERSION_PATCH = 4;

enum ACO_REG_IDX_RETADDR = 4;
enum ACO_REG_IDX_SP = 5;
enum ACO_REG_IDX_BP = 7;
enum ACO_REG_IDX_FPU = 8;

struct aco_save_stack_t
{
    void* ptr;
    size_t sz;
    size_t valid_sz;
    // max copy size in bytes
    size_t max_cpsz;
    // copy from share stack to this save stack
    size_t ct_save;
    // copy from this save stack to share stack 
    size_t ct_restore;
}

alias aco_t = aco_s;

struct aco_share_stack_t
{
    void* ptr;
    size_t sz;
    void* align_highptr;
    void* align_retptr;
    size_t align_validsz;
    size_t align_limit;
    aco_t* owner;

    char guard_page_enabled;
    void* real_ptr;
    size_t real_sz;
}

alias aco_cofuncp_t = void function ();

struct aco_s
{
    // cpu registers' state

    void*[9] reg;

    aco_t* main_co;
    void* arg;
    char is_end;

    aco_cofuncp_t fp;

    aco_save_stack_t save_stack;
    aco_share_stack_t* share_stack;
}

extern (D) auto aco_assert(T)(auto ref T EX)
{
    return (EX) ? (cast(void) 0) : (abort());
}

void aco_runtime_test ();

void aco_thread_init (aco_cofuncp_t last_word_co_fp);

void* acosw (aco_t* from_co, aco_t* to_co); // asm

void aco_save_fpucw_mxcsr (void* p); // asm

void aco_funcp_protector_asm (); // asm

void aco_funcp_protector ();

aco_share_stack_t* aco_share_stack_new (size_t sz);

aco_share_stack_t* aco_share_stack_new2 (size_t sz, char guard_page_enabled);

void aco_share_stack_destroy (aco_share_stack_t* sstk);

aco_t* aco_create (
    aco_t* main_co,
    aco_share_stack_t* share_stack,
    size_t save_stack_sz,
    aco_cofuncp_t fp,
    void* arg);

// aco's Global Thread Local Storage variable `co`
extern aco_t* aco_gtls_co;

void aco_resume (aco_t* resume_co);

//extern void aco_yield1(aco_t* yield_co);

extern (D) auto aco_get_arg()
{
    return aco_gtls_co.arg;
}

void aco_destroy (aco_t* co);

auto aco_yield1(aco_t* yield_co) {            
    assert((yield_co));                    
    assert((yield_co).main_co);           
    acosw((yield_co), (yield_co).main_co);   
}

auto aco_yield() {       
    aco_yield1(aco_gtls_co);    
}

auto aco_get_arg() { return (aco_gtls_co.arg); }

auto aco_get_co() { return aco_gtls_co; }

auto aco_co() { return aco_gtls_co; }

auto aco_is_main_co(aco_t* co) { return co.main_co == null; }

auto aco_exit1(aco_t* co) {    
    (co).is_end = 1;           
    aco_assert((co).share_stack.owner == (co)); 
    (co).share_stack.owner = null; 
    (co).share_stack.align_validsz = 0; 
    aco_yield1((co));            
    aco_assert(0);                  
}

auto aco_exit() {      
    aco_exit1(aco_gtls_co); 
}
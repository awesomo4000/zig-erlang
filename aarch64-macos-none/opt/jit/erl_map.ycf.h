/* YCF stub - yielding versions not generated */
#ifndef YCF_YIELDING_C_FUN_HELPERS
#define YCF_YIELDING_C_FUN_HELPERS 1
#endif

/* YCF macros for special code blocks */
#ifndef ON_SAVE_YIELD_STATE
#define ON_SAVE_YIELD_STATE
#define ON_DESTROY_STATE
#define ON_DESTROY_STATE_OR_RETURN
#define YCF_SPECIAL_CODE_START(PARAM) if(0){
#define YCF_SPECIAL_CODE_END() }
#endif

#include "erl_process.h"
#include "erl_nfunc_sched.h"

/* Stub implementations for maps_from_list_1_helper YCF functions */
static Eterm maps_from_list_1_helper_ycf_gen_continue(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    return THE_NON_VALUE; /* Should not be called in non-yielding build */
}
static void maps_from_list_1_helper_ycf_gen_destroy(void *trap_state) {
    (void)trap_state; /* No-op in stub */
}
static Eterm maps_from_list_1_helper_ycf_gen_yielding(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context,
    void* (*ycf_yield_alloc_fun)(size_t,void*), void (*ycf_yield_free_fun)(void*,void*), void* ycf_yield_alloc_free_context,
    size_t ycf_stack_alloc_size_or_max_size, void* ycf_stack_alloc_data, Process* p, Eterm* bif_args) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    (void)ycf_yield_alloc_fun; (void)ycf_yield_free_fun; (void)ycf_yield_alloc_free_context;
    (void)ycf_stack_alloc_size_or_max_size; (void)ycf_stack_alloc_data; (void)p; (void)bif_args;
    return THE_NON_VALUE; /* Should not be called in non-yielding build */
}

/* Stub implementations for maps_from_keys_2_helper YCF functions */
static Eterm maps_from_keys_2_helper_ycf_gen_continue(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    return THE_NON_VALUE;
}
static void maps_from_keys_2_helper_ycf_gen_destroy(void *trap_state) {
    (void)trap_state;
}
static Eterm maps_from_keys_2_helper_ycf_gen_yielding(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context,
    void* (*ycf_yield_alloc_fun)(size_t,void*), void (*ycf_yield_free_fun)(void*,void*), void* ycf_yield_alloc_free_context,
    size_t ycf_stack_alloc_size_or_max_size, void* ycf_stack_alloc_data, Process* p, Eterm* bif_args) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    (void)ycf_yield_alloc_fun; (void)ycf_yield_free_fun; (void)ycf_yield_alloc_free_context;
    (void)ycf_stack_alloc_size_or_max_size; (void)ycf_stack_alloc_data; (void)p; (void)bif_args;
    return THE_NON_VALUE;
}

/* Stub implementations for maps_keys_1_helper YCF functions */
static Eterm maps_keys_1_helper_ycf_gen_continue(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    return THE_NON_VALUE;
}
static void maps_keys_1_helper_ycf_gen_destroy(void *trap_state) {
    (void)trap_state;
}
static Eterm maps_keys_1_helper_ycf_gen_yielding(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context,
    void* (*ycf_yield_alloc_fun)(size_t,void*), void (*ycf_yield_free_fun)(void*,void*), void* ycf_yield_alloc_free_context,
    size_t ycf_stack_alloc_size_or_max_size, void* ycf_stack_alloc_data, Process* p, Eterm* bif_args) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    (void)ycf_yield_alloc_fun; (void)ycf_yield_free_fun; (void)ycf_yield_alloc_free_context;
    (void)ycf_stack_alloc_size_or_max_size; (void)ycf_stack_alloc_data; (void)p; (void)bif_args;
    return THE_NON_VALUE;
}

/* Stub implementations for maps_values_1_helper YCF functions */
static Eterm maps_values_1_helper_ycf_gen_continue(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    return THE_NON_VALUE;
}
static void maps_values_1_helper_ycf_gen_destroy(void *trap_state) {
    (void)trap_state;
}
static Eterm maps_values_1_helper_ycf_gen_yielding(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context,
    void* (*ycf_yield_alloc_fun)(size_t,void*), void (*ycf_yield_free_fun)(void*,void*), void* ycf_yield_alloc_free_context,
    size_t ycf_stack_alloc_size_or_max_size, void* ycf_stack_alloc_data, Process* p, Eterm* bif_args) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    (void)ycf_yield_alloc_fun; (void)ycf_yield_free_fun; (void)ycf_yield_alloc_free_context;
    (void)ycf_stack_alloc_size_or_max_size; (void)ycf_stack_alloc_data; (void)p; (void)bif_args;
    return THE_NON_VALUE;
}


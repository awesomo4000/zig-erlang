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

/* Stub implementations for ets_insert_2_list YCF functions */
static Eterm ets_insert_2_list_ycf_gen_continue(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    return THE_NON_VALUE;
}
static void ets_insert_2_list_ycf_gen_destroy(void *trap_state) {
    (void)trap_state;
}
static Eterm ets_insert_2_list_ycf_gen_yielding(long* ycf_nr_of_reductions_param, void** ycf_trap_state, void* ycf_extra_context,
    void* (*ycf_yield_alloc_fun)(size_t,void*), void (*ycf_yield_free_fun)(void*,void*), void* ycf_yield_alloc_free_context,
    size_t ycf_stack_alloc_size_or_max_size, void* ycf_stack_alloc_data,
    Process* p, Eterm table_id, Binary* btid, DbTable* tb, Eterm list, int is_insert_new) {
    (void)ycf_nr_of_reductions_param; (void)ycf_trap_state; (void)ycf_extra_context;
    (void)ycf_yield_alloc_fun; (void)ycf_yield_free_fun; (void)ycf_yield_alloc_free_context;
    (void)ycf_stack_alloc_size_or_max_size; (void)ycf_stack_alloc_data;
    (void)p; (void)table_id; (void)btid; (void)tb; (void)list; (void)is_insert_new;
    return THE_NON_VALUE;
}


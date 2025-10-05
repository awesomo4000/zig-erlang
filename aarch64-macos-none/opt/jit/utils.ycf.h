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

/* No YCF functions needed for utils.c yet */


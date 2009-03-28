extern int test_display(int narg, const char** argv);
extern int test_execute(int narg, const char** argv);
extern int test_expr(int narg, const char** argv);
extern int test_stack(int narg, const char** argv);
extern int test_start(int narg, const char** argv);
extern int test_type(int narg, const char** argv);
extern int test_xpoint(int narg, const char** argv);

extern int wdtp_dummy_counter;
/* the WDTP_INSN_BARRIER is a macro to prevent the compiler to reorder instructions
 * (at least memory reads and writes) before and after the barrier
 * it's also supposed to be breakable (ie to contain code that's not optimized out)
 */
#ifdef __GNUC__
#define WDTP_INSN_BARRIER() { asm volatile ("" ::: "memory"); wdtp_dummy_counter++; }
#elif defined(_MSC_VER)
#  if _MSC_VER < 1400
     extern void _ReadWriteBarrier();
#  else
#    include <intrin.h>
#  endif
#  pragma intrinsic(_ReadWriteBarrier)
#  define WDTP_INSN_BARRIER() { _ReadWriteBarrier(); wdtp_dummy_counter++; }
#else
#error Undefined WDTP_INSN_BARRIER macro
#endif


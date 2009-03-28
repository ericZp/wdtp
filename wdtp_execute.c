/* sample tests for execution */

#include <stdlib.h>
#include "wdtp.h"

int wdtp_test_exec_g(int a)
{
    a = a - 4;
    a = a >> 2;
    return a ? a : wdtp_test_exec_g(0);
}

int wdtp_test_exec_f(int a, int b)
{
    a = a + 2;                  WDTP_INSN_BARRIER();
    a *= 3;
    a <<= b;
    /* this is a comment */
    a = wdtp_test_exec_g(a);
    // and another one
    return a * wdtp_test_exec_g(b);
}

int test_execute(int argc, const char** ptr)
{
    int ret = 0;

    ret += wdtp_test_exec_f(12, 2);
    ret += wdtp_test_exec_f(12, 2);
    return 0;
}

/* sample tests for execution */

#include <stdlib.h>
#include "wdtp.h"

static int exec_g(int a)
{
    a = a - 4;
    a = a >> 2;
    return a ? a : exec_g(0);
}

static int exec_f(int a, int b)
{
    a = a + 2;
    a *= 3;
    a <<= b;
    /* this is a comment */
    a = exec_g(a);
    // and another one
    return a * exec_g(b);
}
    
int test_execute(int argc, const char** ptr)
{
    int ret = 0;

    ret += exec_f(12, 2);
    ret += exec_f(12, 2);
    return 0;
}

#include <stdlib.h>
#include "wdtp.h"

int wdtp_test_stack_func(int i)
{
    if (i < 10)
        wdtp_test_stack_func(i + 1);
    else
    {
        WDTP_INSN_BARRIER();
        i = 40;
    }
    return i * 2;
}

WDTP_DONT_INLINE int wdtp_test_stack_float(int i, float f, double d)
{
    return i + wdtp_test_stack_func(i) - (int)(d/f);
}

int test_stack(int argc, const char** argv)
{
    wdtp_test_stack_float(1, 1.2345, -1.4567);
    WDTP_INSN_BARRIER();
    return 0;
}

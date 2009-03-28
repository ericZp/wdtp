#include <stdlib.h>
#include "wdtp.h"

static int xpoint_int = 3;

int wdtp_test_xpoint_write(int* ptr)
{
    *ptr = 3;
    xpoint_int += *ptr;
    WDTP_INSN_BARRIER();
    return *ptr ^ xpoint_int;
}

int wdtp_test_xpoint_g(int i)
{
    volatile int ret;
    ret = 12 + i;
    WDTP_INSN_BARRIER();
    return ret;
}

int wdtp_test_xpoint_cond(void)
{
    int i;
    int ret = 0;

    for (i = 0; i < 10; i++)
        ret += wdtp_test_xpoint_g(i);
    return ret;
}
int test_xpoint(int v1, const char** ptr)
{
    wdtp_test_xpoint_write(&v1);
    wdtp_test_xpoint_cond();
    return 0;
}

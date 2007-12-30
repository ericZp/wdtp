#include <stdlib.h>
#include "wdtp.h"

static int xpoint_int = 3;

static int xpoint_write(int* ptr)
{
    *ptr = 3;
    xpoint_int += *ptr;
    return *ptr ^ xpoint_int;
}

static int xpoint_g(int i)
{
    int ret;
    ret = 12 + i;
    return ret;
}

static int xpoint_cond(void)
{
    int i;
    int ret = 0;

    for (i = 0; i < 10; i++)
        ret += xpoint_g(i);
    return ret;
}
int test_xpoint(int v1, const char** ptr)
{
    xpoint_write(&v1);
    xpoint_cond();
    return 0;
}

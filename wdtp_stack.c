#include <stdlib.h>
#include "wdtp.h"

static int stack_func(int i)
{
    if (i < 10)
        stack_func(i + 1);
    else
        i = 40;
    return i * 2;
}

int test_stack(int argc, const char** argv)
{
    stack_func(1);
    return 0;
}

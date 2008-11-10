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

static int stack_float(int i, float f, double d)
{
    return stack_func(i);
}

int test_stack(int argc, const char** argv)
{
    stack_float(1, 1.2345, -1.4567);
    return 0;
}

/* sample tests for display */

#include <stdlib.h>
#include "wdtp.h"

/* FIXME:
 */

struct xx
{
    int         v;
    const char* string;
};

static int display_bar(const char*, int, int, struct xx);

static int display_foo(const char* phase, int a, int b, struct xx xx)
{
    struct xx xx2;
    xx2 = xx;
    xx2.v -= a * b;
    xx2.string = phase;
    return display_bar(phase, a, b, xx2);
}

static int display_bar(const char* phase, int a, int b, struct xx xx)
{
    if (a == 0) return 0;
    if (a == 1) return b;
    return display_foo("left", a - 1, b, xx) + display_foo("right", a - 2, b, xx);
}

int test_display(int argc, const char** ptr)
{
    struct xx xx;
    int v;
    xx.v = 34;
    xx.string = "mambo!!";

    v = display_foo("first", 3, 4, xx);
    return v;
}

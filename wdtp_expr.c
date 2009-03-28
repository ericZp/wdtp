/* sample tests for expressions */

#include <stdlib.h>
#include "wdtp.h"

/* FIXME: strangely enough, msvc wrongly handles types 
 * where struct foo exists and foo is a typedef to another struct
 */

int             myint1;
static int      myint2;

struct toto
{
    int toto_a;
    int toto_b;
    unsigned bf1 : 10, bf2 : 6;
    int bf3 : 13, bf4 : 3;
    struct {
        int a;
        int b;
    } s;
    union {
        int i;
        unsigned u;
    } u;
};

static void f(struct toto* t)
{
    t->toto_a *= 2;
    t->toto_b += t->toto_a;
}

int test_expr(int argc, const char** ptr)
{
    struct toto t = {0, 0, 12, 63, -34, -4, {0x5A5A5A5A, 0xA5A5A5A5}, {0xAAAAAAAA}};

    myint1 = argc;
    myint2 = 3 * t.bf1;
    t.toto_a = 1 + argc;
    t.toto_b = 2 + (argc << 3);
    t.toto_a <<= t.bf1;
    f(&t);
    
    return t.toto_a + t.toto_b;
}

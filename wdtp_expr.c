/* sample tests for expressions */

#include <stdlib.h>
#include "wdtp.h"

/* FIXME: strangely enough, msvc wrongly handles types
 * where struct foo exists and foo is a typedef to another struct
 */

int             myint0;
int             myint1;
static int      myint2;
enum toto_enum {zero, one, two, three, four};

struct toto
{
    int toto_a;
    int toto_b;
    unsigned bf1 : 10, bf2 : 6;
    int bf3 : 13, bf4 : 3;
    float       ff;
    double      fd;
    struct {
        int a;
        int b;
    } s;
    union {
        int i;
        unsigned u;
    } u;
    enum toto_enum x;
};

struct titi
{
    void*               pA;
    struct titi*        pB;
    const char*         pC;
} titi = {(void*)0x87654321, (struct titi*)0x43218765, "foo"};

static long long sll;
static unsigned long long ull;
enum toto_enum wdtp_test_expr_te = three;

struct tata
{
    int                 i;
    short               s;
    char                c;
} mytata[] = {{12,2,'a'},{13,3,'b'},{14,4,'c'}}, *pmytata = mytata;

static int g(int a)
{
    sll = -((long long)1234567 * 100000 + 99000);
    ull = -sll;
    return a;
}

/* we need a separate global function so that the toto struct isn't optimized out */
int wdtp_test_expr_part(struct toto* t, int argc)
{
    t->toto_a += 1 + argc;
    t->toto_b += 2 + (argc << 3);
    WDTP_INSN_BARRIER();
    t->toto_a <<= t->bf1;
    WDTP_INSN_BARRIER();
    t->toto_a *= 2;
    t->toto_b += t->toto_a + ((t->x == two) ? 2 : 1);
    return 0;
}

int test_expr(int argc, const char** ptr)
{
    struct toto t = {0, 0, 12, 63, -34, -4, 1.23, 4.56e-2, {0x5A5A5A5A, 0xA5A5A5A5}, {0xAAAAAAAA}, one};

    WDTP_INSN_BARRIER();
    myint0 = -4;
    myint1 = g(argc);
    myint2 = 3 * t.bf1;
    wdtp_test_expr_part(&t, argc);

    return t.toto_a + t.toto_b;
}

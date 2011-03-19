/* sample tests for types */

#include <stdlib.h>
#include "wdtp.h"

struct ms
{
    int         value;
    const char* key;
    struct ms*  next;
};

static int*     foo;
int             wdtp_bar = 0;
struct ms       first = {0, NULL, NULL};
struct ms       myarray[] = {{0,NULL, &first},{1,NULL,&myarray[0]},{2,NULL,&myarray[1]}};

static struct ms*       fn(int v, const char* k)
{
    struct ms* ms = malloc(sizeof(*ms));
    ms->value = v + *foo * wdtp_bar;
    ms->key = k;
    ms->next = first.next;
    first.next = ms;
    return ms;
}

static struct ms*       fn2(int v, const char* k) {return NULL;}

struct ms* (*wdtp_test_pfn)(int, const char*) = fn;

static WDTP_DONT_INLINE void test_void(void)
{
    wdtp_bar += *foo;
}

static WDTP_DONT_INLINE void test_varargs(int toto, ...)
{
    wdtp_bar *= toto;
}

int test_type(int argc, const char** ptr)
{
    struct ms*  ms;
    int         lfoo = 3;

    wdtp_bar += argc;
    if (argc == 10) wdtp_test_pfn = fn2;
    foo = &lfoo;
    ms = wdtp_test_pfn(12, "foo");
    test_void();
    test_varargs(12, 3, 4, wdtp_bar);
    test_varargs(10, "foo");

    return wdtp_bar + ms->value;
}

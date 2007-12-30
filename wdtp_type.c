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
static int      bar;
struct ms       first = {0, NULL, NULL};

static struct ms*       fn(int v, const char* k)
{
    struct ms* ms = malloc(sizeof(*ms));
    ms->value = v + *foo * bar;
    ms->key = k;
    ms->next = first.next;
    first.next = ms;
    return ms;
}

static struct ms* (*pfn)(int, const char*) = fn;

int test_type(int argc, const char** ptr)
{
    struct ms*  ms;
    int         lfoo = 3;
    foo = &lfoo;
    ms = pfn(12, "foo");
    return ms->value;
}

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
struct ms       myarray[] = {{0,NULL, &first},{1,NULL,&myarray[0]},{2,NULL,&myarray[1]}};

static struct ms*       fn(int v, const char* k)
{
    struct ms* ms = malloc(sizeof(*ms));
    ms->value = v + *foo * bar;
    ms->key = k;
    ms->next = first.next;
    first.next = ms;
    return ms;
}

struct ms* (*wdtp_test_pfn)(int, const char*) = fn;

int test_type(int argc, const char** ptr)
{
    struct ms*  ms;
    int         lfoo = 3;
    foo = &lfoo;
    ms = wdtp_test_pfn(12, "foo");
    return ms->value;
}

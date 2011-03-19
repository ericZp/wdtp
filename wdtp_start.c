#include <stdlib.h>
#include "wdtp.h"

/* just to avoid to include all the Windows stuff */
extern void* __stdcall CreateEventA(void*, unsigned, unsigned, void*);
extern int   __stdcall WaitForSingleObject(void*, unsigned);
extern void  __stdcall CloseHandle(void*);

static WDTP_DONT_INLINE int start_real(int a, int z)
{
    return a + z;
}

/* internal startup code... test code won't depend on it
 * it's mainly used as a work around for MingW's not supporting
 * in its crt0 (FIXME: check it!!!) a process started suspended
 */
int test_start(int argc, const char** argv)
{
    void* event = CreateEventA(NULL, 0, 0, NULL);
    int z = WaitForSingleObject(event, 0xFFFFFFFF /* INFINITE */);
    CloseHandle(event);

    return start_real(argc, z);
}

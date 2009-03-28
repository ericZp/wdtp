#include <stdlib.h>
#include <windef.h>
#include "wdtp.h"

/* just to avoid to include all the Windows stuff */
extern int  __stdcall WaitForSingleObject(unsigned long, unsigned long);
extern void __stdcall CloseHandle(unsigned long);

static int start_real(void)
{
    return 0;
}

/* internal startup code... test code won't depend on it
 * it's mainly used as a work around for MingW's not supporting
 * in its crt0 (FIXME: check it!!!) a process started suspended
 */
int test_start(int argc, const char** argv)
{
    if (argc >= 1 && !memcmp(argv[0], "--event=", 8))
    {
        long event = atoi(argv[0] + 8);
        WaitForSingleObject(event, 0xFFFFFFFF /* INFINITE */);
        CloseHandle(event);
        argc--; argv++;
    }
    return start_real();
}

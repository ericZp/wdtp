/*
 * Wine test
 * Helper routines for testing command-line programs
 *
 * Copyright 2005 Eric Pouech
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <time.h>
#include <windef.h>
#include <winbase.h>
#include <winuser.h>

/* FIXME:
 *      + handle time out in send/recv
 *      + full error handling in wtcl_start
 *      + clean-up the eof conditions in recv
 *      + comment up this file
 */

struct cl_child_info
{
    PROCESS_INFORMATION info;           /* as returned by CreateProcess */
    HANDLE              hInput;         /* handle to input stream to child */
    HANDLE              hOutput;        /* handle to output stream from child */
    /* the following fields apply when the child process uses a prompt interface
     * (wcmd, winedbg are programs of this kind)
     */
    const char*         prompt;         /* prompt used in child (if needed) */
    char*               buffer;         /* internal buffer for prompt reading */
    char*               buf_ptr;        /* pointer into buffer. Handly for iterative lookups in buffer */
    size_t              buf_size;       /* size of this buffer */
    DWORD               timeout;        /* default timeout in ms when waiting for the prompt */
};

static inline void wtcl_set_prompt(struct cl_child_info* cci, const char* p)
{
    if (cci->prompt) free((void*)cci->prompt);
    if (cci->buffer) free(cci->buffer);
    if (p)
    {
        cci->prompt = strcpy(malloc(strlen(p) + 1), p);
        cci->buffer = malloc(cci->buf_size = 1024);
        assert(cci->buffer);
    }
    else
    {
        cci->prompt = cci->buffer = NULL;
        cci->buf_size = 0;
    }
}

static inline void wtcl_set_timeout(struct cl_child_info* cci, DWORD to)
{
    cci->timeout = to;
}

static inline void wtcl_stop(struct cl_child_info* cci)
{
    TerminateProcess(cci->info.hProcess, 0);
    CloseHandle(cci->hInput);
    CloseHandle(cci->hOutput);
    CloseHandle(cci->info.hThread);
    CloseHandle(cci->info.hProcess);
    wtcl_set_prompt(cci, NULL);
    memset(cci, 0xA5, sizeof(*cci));
}

static inline int wtcl_start(struct cl_child_info* cci, char* cmdline, unsigned show)
{
    HANDLE              hChildOut, hChildOutInh;
    HANDLE              hChildIn, hChildInInh;
    STARTUPINFOA        startup;

    CreatePipe(&cci->hInput, &hChildOut, NULL, 0);
    DuplicateHandle(GetCurrentProcess(), hChildOut, GetCurrentProcess(),
                    &hChildOutInh, 0, TRUE, DUPLICATE_SAME_ACCESS);
    CloseHandle(hChildOut);

    CreatePipe(&hChildIn, &cci->hOutput, NULL, 0);
    DuplicateHandle(GetCurrentProcess(), hChildIn, GetCurrentProcess(),
                    &hChildInInh, 0, TRUE, DUPLICATE_SAME_ACCESS);
    CloseHandle(hChildIn);

    memset(&startup, 0, sizeof(startup));
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW|STARTF_USESTDHANDLES;
    startup.wShowWindow = show ? SW_SHOWNORMAL : SW_HIDE;
    startup.hStdInput = hChildInInh;
    startup.hStdOutput = hChildOutInh;
    startup.hStdError = hChildOutInh;

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, TRUE, DETACHED_PROCESS, NULL, NULL, &startup, &cci->info))
    {
        printf("cmd line %s\n", cmdline);
        wtcl_stop(cci);
        return -1;
    }
    CloseHandle(hChildInInh);
    CloseHandle(hChildOutInh);

    wtcl_set_timeout(cci, 10000);
    return 0;
}

static inline int wtcl_send_vcmd(struct cl_child_info* cci, const char* msg, va_list valist)
{
    char        buffer[1024];
    DWORD       w;
    size_t      len;
    char        ch = '\n';

    len = vsnprintf(buffer, sizeof(buffer), msg, valist);
    return (WriteFile(cci->hOutput, buffer, len, &w, NULL) && w == len &&
            WriteFile(cci->hOutput, &ch, 1, &w, NULL)      && w == 1      ) ? 0 : -1;
}

static inline void wtcl_send_cmd(struct cl_child_info* cci, const char* msg, ...)
{
    va_list     valist;

    va_start(valist, msg);
    wtcl_send_vcmd(cci, msg, valist);
    va_end(valist);
}

static inline int wtcl_recv_raw(struct cl_child_info* cci, char* buffer, unsigned sz)
{
    DWORD r;
    ReadFile(cci->hInput, buffer, sz, &r, NULL);
    return (int)r;
}

static inline int _wtcl_recv_raw_b(struct cl_child_info* cci, char* buffer, unsigned sz, time_t to, BOOL* eof)
{
    DWORD r;
    time_t start = time(NULL);
    int in = 0;

    *eof = FALSE;
    do
    {
        if (WaitForSingleObject(cci->hInput, to) != WAIT_OBJECT_0) return -1;
        if (!ReadFile(cci->hInput, buffer + in, sz - in, &r, NULL))// || r == 0) /* FIXME: the last part is the Wine's bug workaround */
        {
            *eof = TRUE;
            break;
        }
        in += r;
    } while (in < sz && time(NULL) - start < to);
    return in ? in : -1;
}

static inline int _wtcl_ensure_bufsize(struct cl_child_info* cci, unsigned sz)
{
    while (cci->buf_size < sz)
    {
        void* p = realloc(cci->buffer, cci->buf_size += 1024);
        if (!p) return -1;
        cci->buf_ptr = (char*)p + (cci->buf_ptr - cci->buffer);
        cci->buffer = p;
    }
    return 0;
}

static inline int wtcl_recv_up_to_prompt(struct cl_child_info* cci)
{
    int         idx = 0;
    size_t      pl;
    BOOL        eof;
    time_t      curr, end = time(NULL) + cci->timeout;

    assert(cci->prompt);
    pl = strlen(cci->prompt);
    assert(pl);
    if (_wtcl_ensure_bufsize(cci, pl) == -1 || _wtcl_recv_raw_b(cci, cci->buffer, pl, cci->timeout, &eof) != pl)
        return -1;
    do
    {
        // fprintf(stderr, "-> %.*s\n", idx + pl, cci->buffer);
        if (!memcmp(cci->buffer + idx, cci->prompt, pl))
        {
            if (idx && cci->buffer[idx - 1] == '\n') idx--;
            cci->buffer[idx] = '\0';
            cci->buf_ptr = cci->buffer;
            return 0;
        }
    } while (!eof && _wtcl_ensure_bufsize(cci, idx + pl + 1) == 0 && (curr = time(NULL)) <= end &&
             _wtcl_recv_raw_b(cci, &cci->buffer[idx + pl], 1, end - curr, &eof) == 1 && ++idx);
    cci->buffer[idx + pl] = '\0';
    cci->buf_ptr = cci->buffer;
    return -1;
}

static inline int wtcl_execute(struct cl_child_info* cci, const char* msg, ...)
{
    va_list     valist;
    int         ret;

    va_start(valist, msg);
    ret = wtcl_send_vcmd(cci, msg, valist);
    va_end(valist);
    if (ret != -1) ret = wtcl_recv_up_to_prompt(cci);
    return ret;
}

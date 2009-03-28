/* WineDbg test
 * Helper routines for testing WineDbg
 * Copyright 2005-2006 Eric Pouech
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
#include "test_cl.h"
#include <stdarg.h>
#include "windef.h"
#include "winbase.h"
#include "winerror.h"
#include "winuser.h"
#include <sys/types.h>
#include <regex.h>

/* TODO:
 *      - document function usage (what are they intended for...)
 *      - wdt_to_num looks utterly wrong wrt. signed / unsigned numbers
 *      - exception (either in running code, or expr evaluation) is wrong
 *      - evaluate should use a VARIANT, not a home grown struct mv
 */

/* to store information about a location (address, source file, module...) */
struct location
{
    void*       address;        /* address of location */
    char*       name;           /* name of var/function at this location */
    unsigned    offset;         /* offset between <name> and <address> */
    char*       srcfile;        /* source file of this location */
    unsigned    lineno;         /* line number in <srcfile> of this location */
    char*       module;         /* module of this location */
};

/* to store the result of an evaluation */
struct mval
{
    enum {mv_null, mv_integer, mv_hexa, mv_float, mv_string, mv_char, mv_struct, mv_func, mv_error} type;
    union
    {
        int             integer;
        double          flt_number;
        const char*     str;
    } u;
};

/* to store information about a variable displayed */
struct display
{
    struct mval         mval;   /* it's value */
    char*               expr;
};

/* all we need to handle a WineDbg instance */
struct debuggee
{
    struct cl_child_info        cl;             /* child as defined in test_cl.h */
    struct location             loc;            /* current location of PC */
    enum {ss_none, ss_started, ss_xpoint, ss_exception, ss_step}
                                status;         /* cause of debuggee stop */
    int                         info;           /* extra info on status (xpoint -> xpoint #) */
    char                        err_msg[256];   /* contains error message in case of failure of an API */
    struct display*             display;
    int                         num_display;
};

/* internal variable */
struct id
{
    const char*                 name;           /* its name */
    struct mval                 mval;           /* its value */
    struct id*                  next;           /* linked list */
    unsigned                    is_system;      /* system id */
};

/* Each entry in this enum matches a RE in previous array. Be sure to keep them in sync */
enum re_val {re_started, re_stopped_bp_m, re_stopped_bp_b, re_stopped_wp_m, re_stopped_wp_b, re_terminated, re_srcline, re_asmline, re_funcchange, re_display,
             re_integer, re_hexa, re_float1, re_float2, re_float3, re_string, re_char, re_struct, re_func, re_id,
             re_set_break_m, re_set_break_b, re_set_watch1_m, re_set_watch1_b, re_set_watch2, re_backtrace_m, re_backtrace_b,
             re_last};

extern int do_trace;
extern int do_dump;
#define TRACE   (!do_trace) ? 0 : printf

int wdt_free_location(struct location* loc);
BOOL wdt_ends_with(const char* src, const char* end);

int wdt_start(struct debuggee* dbg, char* start);
int wdt_set_xpoint(struct debuggee* dbg, const char* cmd,
                   int* xp_num, struct location* loc);
int wdt_execute(struct debuggee* dbg, const char* cmd, ...);
int wdt_evaluate(struct debuggee* dbg, struct mval* mv, const char* expr, ...);
int wdt_backtrace(struct debuggee* dbg);
int wdt_backtrace_next(struct debuggee* dbg, int* frame, struct location* loc, char** args);
int wdt_whatis(struct debuggee* dbg, const char* args);

int wdt_stop(struct debuggee* dbg);

struct id* fetch_id(const char* name);

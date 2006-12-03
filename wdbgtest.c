/*
 * Tool for testing the Wine debugger
 *
 * Copyright 2006 Eric Pouech
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
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "wdbgtest.h"

int do_dump;
int do_trace;

/* RE for parsing child output */
static BOOL     re_init_done;
static struct
{
    const char*         init_string;    /* RE to be matched */
    unsigned            num;            /* number of extended parts in RE */
    regex_t             re;             /* compiled RE */
}
re[] =
{
/* RE for execution ---------- */
    /* re_started    */ {"^WineDbg starting on pid (0x[0-9a-fA-F]+)$", 1},
    /* re_stopped_bp_m */ {"^Stopped on breakpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\] in ([^\n]*)", 6},
    /* re_stopped_bp_b */ {"^Stopped on breakpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\]", 5},
    /* re_stopped_wp_m */ {"^Stopped on watchpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\] in ([^\n]*) values: old=[0-9]+ new=[0-9]+", 6},
    /* re_stopped_wp_b */ {"^Stopped on watchpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\] values: old=[0-9]+ new=[0-9]+", 5},
    /* re_terminated */ {"^WineDbg terminated on pid (0x[0-9a-fA-F]+)$", 1},
    /* re_srcline    */ {"^([0-9]+)", 1},
    /* re_asmline    */ {"^(0x[0-9a-fA-F]+) ([^ ]*) in ([^:]*):", 3},
    /* re_funcchange */ {"^([^ ]+) \\(\\) at (.*):([0-9]+)\n[0-9]+", 3},
    /* re_display    */ {"^([0-9]+): ([^ ]+) = ([^\n]+)\n", 3},
/* RE for expressions -------- */
    /* re_integer    */ {"^([-+]?[0-9]+)$", 1},
    /* re_hexa       */ {"^(0x[0-9a-fA-F]+)$", 1},
    /* re_string     */ {"^\\\"([^\\\"]*)\\\"$", 1},
    /* re_char       */ {"^'(.)'$", 1},
    /* re_struct     */ {"^\\{(.*)\\}$", 1},
    /* re_func       */ {"^Function (0x[0-9a-fA-F]+): (.*)$", 2},
/* RE for commands ----------- */
    /* re_set_break_m  */ {"^Breakpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\] in ([^\n]*)$", 6},
    /* re_set_break_b  */ {"^Breakpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) \\[(.*):([0-9]+)\\]$", 5},
    /* re_set_watch1_m */ {"^Watchpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+) in ([^\n]*)$", 4},
    /* re_set_watch1_b */ {"^Watchpoint ([0-9]+) at (0x[0-9a-fA-F]+) ([^ ]+)$", 3},
    /* re_set_watch2   */ {"^Watchpoint ([0-9]+) at (0x[0-9a-fA-F]+)$", 2},
    /* re_backtrace_m  */ {"^[= ][> ]([0-9]+) (0x[0-9a-fA-F]+) ([^\\(]*)\\(([^\\)]*)\\) \\[([^\n]*):([0-9]+)\\] in ([^ ]*) \\((0x[0-9a-fA-F]+)\\)\n", 8},
    /* re_backtrace_b  */ {"^[= ][> ]([0-9]+) (0x[0-9a-fA-F]+) ([^\\(]*)\\(([^\\)]*)\\) \\[([^\n]*):([0-9]+)\\] \\((0x[0-9a-fA-F]+)\\)\n", 7},
};
static regmatch_t  rm[9];

static BOOL compare(enum re_val v, const char* str)
{
    return regexec(&re[v].re, str, re[v].num + 1, rm, 0) == 0;
}

#define C(c) (isprint(c) ? c : '.')

static void dump_data( const char *ptr, const char *prefix )
{
    unsigned int i, j;
    size_t size;

    if (!do_dump) return;

    printf( "%s%08x: ", prefix, 0 );
    if (!ptr)
    {
        printf( "NULL\n" );
        return;
    }
    size = strlen(ptr);
    for (i = 0; i < size; i++)
    {
        printf( "%02x%c", (unsigned char)ptr[i], (i % 16 == 7) ? '-' : ' ' );
        if ((i % 16) == 15)
        {
            printf( " " );
            for (j = 0; j < 16; j++)
                printf( "%c", C((unsigned char)ptr[i-15+j]));
            if (i < size-1) printf( "\n%s%08x: ", prefix, i + 1 );
        }
    }
    if (i % 16)
    {
        printf( "%*s ", 3 * (16-(i%16)), "" );
        for (j = 0; j < i % 16; j++)
            printf( "%c", C((unsigned char)ptr[i-(i%16)+j]));
    }
    printf( "\n" );
}

static int to_num(struct debuggee* dbg, int idx)
{
    const char* ptr = &dbg->cl.buf_ptr[rm[idx].rm_so];
    char* end;
    int val;

    if (ptr[0] == '0' && ptr[1] == 'x')
    {
        val = strtoul(&dbg->cl.buf_ptr[rm[idx].rm_so], &end, 16);
    }
    else
    {
        val = strtol(&dbg->cl.buf_ptr[rm[idx].rm_so], &end, 10);
    }
    if (end != &dbg->cl.buf_ptr[rm[idx].rm_eo]) val = -1;
    return val;
}

static char* to_string(struct debuggee* dbg, int idx)
{
    size_t len = rm[idx].rm_eo - rm[idx].rm_so;
    char* ret = malloc(len + 1);

    if (!ret) return NULL;
    memcpy(ret, &dbg->cl.buf_ptr[rm[idx].rm_so], len);
    ret[len] = '\0';
    return ret;
}

static char* empty_str(void)
{
    char* ptr = malloc(1);
    *ptr = '\0';
    return ptr;
}

static void grab_location(struct debuggee* dbg, struct location* loc,
                          int addr_idx, int name_idx, int src_idx, 
                          int line_idx, int module_idx)
{
    loc->address = (addr_idx != -1) ? (void*)to_num(dbg, addr_idx) : NULL;
    if (name_idx != -1)
    {
        unsigned pos = rm[name_idx].rm_eo;
        size_t len = rm[name_idx].rm_eo - rm[name_idx].rm_so;
        char* end;

        while (pos-- > rm[name_idx].rm_so)
        {
            if (dbg->cl.buf_ptr[pos] == '+')
            {
                len = pos - rm[name_idx].rm_so;
                break;
            }
        }
        if ((loc->name = malloc(len + 1)))
        {
            memcpy(loc->name, &dbg->cl.buf_ptr[rm[name_idx].rm_so], len);
            loc->name[len] = '\0';
        }
        loc->offset = (pos > rm[name_idx].rm_so) ? strtoul(&dbg->cl.buf_ptr[pos], &end, 16) : 0;
    }
    else
    {
        loc->name = empty_str();
        loc->offset = 0;
    }
    loc->srcfile = (src_idx != -1) ? to_string(dbg, src_idx) : empty_str();
    loc->lineno  = (line_idx != -1) ? to_num(dbg, line_idx) : 0;
    loc->module  = (module_idx != -1) ? to_string(dbg, module_idx) : empty_str();
}


static int free_mval(struct mval* mval)
{
    /* FIXME */
    return 0;
}

static void free_display(struct debuggee* dbg)
{
    int i;
    for (i = 0; i < dbg->num_display; i++)
    {
        free(dbg->display[i].expr);
        free_mval(&dbg->display[i].mval);
    }
    free(dbg->display);
    dbg->num_display = 0;
    dbg->display = NULL;
}

BOOL wdt_ends_with(const char* src, const char* end)
{
    size_t slen = strlen(src), elen = strlen(end);

    return (slen >= elen) && strcmp(src + slen - elen, end) == 0;
}

int wdt_free_location(struct location* loc)
{
    free(loc->name);
    free(loc->srcfile);
    free(loc->module);
    memset(loc, 0x5A, sizeof(*loc));
    return 0;
}

int wdt_fetch_value(struct debuggee* dbg, struct mval* mv)
{
    int ret = 0;

    if (!dbg->cl.buf_ptr[0])
    {
        mv->type = mv_null;
    }
    else if (compare(re_integer, dbg->cl.buf_ptr))
    {
        mv->type = mv_integer;
        mv->u.integer = to_num(dbg, 1);
    }
    else if (compare(re_hexa, dbg->cl.buf_ptr))
    {
        mv->type = mv_hexa;
        mv->u.integer = to_num(dbg, 1);
    }
    else if (compare(re_string, dbg->cl.buf_ptr))
    {
        mv->type = mv_string;
        mv->u.str = to_string(dbg, 1);
    }
    else if (compare(re_char, dbg->cl.buf_ptr))
    {
        mv->type = mv_char;
        mv->u.integer = dbg->cl.buf_ptr[rm[1].rm_so];
    }
    else if (compare(re_struct, dbg->cl.buf_ptr))
    {
        mv->type = mv_struct;
        mv->u.str = to_string(dbg, 1);
    }
    else if (compare(re_func, dbg->cl.buf_ptr))
    {
        mv->type = mv_func;
        mv->u.integer = to_num(dbg, 1);
    }
    else
    {
        mv->type = mv_error;
        ret = -1;
    }
    return ret;
}

int wdt_start(struct debuggee* dbg, char* start)
{
    int ret;

    if (!re_init_done)
    {
        int      i, mx = 0;;
        re_init_done = 1;
        /* init re's */
        for (i = 0; i < sizeof(re) / sizeof(re[0]); i++)
        {
            if (mx < re[i].num) mx = re[i].num;
            regcomp(&re[i].re, re[i].init_string, REG_EXTENDED);
        }
        assert(sizeof(rm) / sizeof(rm[0]) >= mx + 1);
        assert(re_last == sizeof(re) / sizeof(re[0]));
    }

    memset(dbg, 0, sizeof(*dbg));
    wtcl_set_prompt(&dbg->cl, "Wine-dbg>");
    wtcl_start(&dbg->cl, start);
    /* sync up to first prompt */
    ret = wtcl_recv_up_to_prompt(&dbg->cl);
    TRACE("Got for start-cmd='%s': '%s'\n", start, dbg->cl.buf_ptr);
    dump_data(dbg->cl.buf_ptr, "start> ");
    if (ret == -1)
    {
        strcpy(dbg->err_msg, "Couldn't start WineDbg");
        return -1;
    }

    if (compare(re_started, dbg->cl.buf_ptr))
    {
        TRACE("Started on pid='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so]);
        dbg->status = ss_started;
        if (to_num(dbg, 1) != dbg->cl.info.dwProcessId)
        {
            snprintf(dbg->err_msg, sizeof(dbg->err_msg), "Debugging wrong process (%x/%x)\n",
                     to_num(dbg, 1), dbg->cl.info.dwProcessId);
            return -1;
        }
    }
    else dbg->status = ss_none;
    return 0;
}

int wdt_set_xpoint(struct debuggee* dbg, const char* cmd, 
                   int* xp_num, struct location* loc)
{
    int         ret = 0;

    if (loc) memset(loc, 0, sizeof(*loc));

    if (wtcl_execute(&dbg->cl, cmd) == -1) return -1;

    TRACE("Got for cmd='%s': '%s'\n", cmd, dbg->cl.buf_ptr);
    /* Breakpoint 1 at 0x???????? main [srcfile:lineno] in module */
    if (compare(re_set_break_m, dbg->cl.buf_ptr))
    {
        TRACE("Found bp='%.*s' addr='%.*s' name='%.*s' src='%.*s'/lineno='%.*s' module='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so],
              (int)(rm[6].rm_eo - rm[6].rm_so), &dbg->cl.buf_ptr[rm[6].rm_so]);
        if (xp_num)  *xp_num = to_num(dbg, 1);
        if (loc)
        {
            grab_location(dbg, loc, 2, 3, 4, 5, 6);
        }
    }
    else if (compare(re_set_break_b, dbg->cl.buf_ptr))
    {
        TRACE("Found bp='%.*s' addr='%.*s' name='%.*s' src='%.*s'/lineno='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so]);
        if (xp_num)  *xp_num = to_num(dbg, 1);
        if (loc)
        {
            grab_location(dbg, loc, 2, 3, 4, 5, -1);
        }
    }
    else if (compare(re_set_watch1_m, dbg->cl.buf_ptr))
    {
        TRACE("Found wp='%.*s' addr='%.*s' name='%.*s' module='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so]);
        if (xp_num) *xp_num = to_num(dbg, 1);
        if (loc) grab_location(dbg, loc, 2, 3, -1, -1, 4);
    }
    else if (compare(re_set_watch1_b, dbg->cl.buf_ptr))
    {
        TRACE("Found wp='%.*s' addr='%.*s' name='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so]);
        if (xp_num) *xp_num = to_num(dbg, 1);
        if (loc) grab_location(dbg, loc, 2, 3, -1, -1, -1);
    }
    else if (compare(re_set_watch2, dbg->cl.buf_ptr))
    {
        TRACE("Found wp='%.*s' addr='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so]);
        if (xp_num) *xp_num = to_num(dbg, 1);
        if (loc) grab_location(dbg, loc, 2, -1, -1, -1, -1);
    }
    else
    {
        printf("No RE-set_bp for %s\n", dbg->cl.buf_ptr);
        ret = -1;
    }
    return ret;
}

int wdt_execute(struct debuggee* dbg, const char* cmd, ...)
{
    int         ret;
    va_list     valist;

    va_start(valist, cmd);
    wtcl_send_vcmd(&dbg->cl, cmd, valist);
    va_end(valist);
    ret = wtcl_recv_up_to_prompt(&dbg->cl);
    TRACE("Got for exec-cmd='%s': '%s'\n", cmd, dbg->cl.buf_ptr);
    dump_data(dbg->cl.buf_ptr, "exec> ");
    if (ret == -1)
    {
        snprintf(dbg->err_msg, sizeof(dbg->err_msg), "Couldn't execute command '%s' -> %s", cmd, dbg->cl.buf_ptr);
        return -1;
    }
    if (dbg->num_display) free_display(dbg);
    while (compare(re_display, dbg->cl.buf_ptr))
    {
        char* end;
        TRACE("Got display #%.*s: '%.*s' = '%.*s'\n", 
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so]);
        dbg->display = realloc(dbg->display, ++dbg->num_display * sizeof(dbg->display[0]));
        if (dbg->num_display != to_num(dbg, 1))
        {
            free_display(dbg);
            strcpy(dbg->err_msg, "Suspicious display index");
            return -1;
        }
        dbg->display[dbg->num_display - 1].expr = to_string(dbg, 2);
        end = dbg->cl.buf_ptr + rm[3].rm_eo;
        end[0] = '\0';
        dbg->cl.buf_ptr += rm[3].rm_so; /* start of expression */
        wdt_fetch_value(dbg, &dbg->display[dbg->num_display - 1].mval);
        dbg->cl.buf_ptr = end + 1;
    }
        
    /* different possible outputs:
     * Breakpoint (bpnum) at 0x(addr) (name) [(srcfile):(lineno)] in (module) (refcount=2)
     */
    if (compare(re_stopped_bp_m, dbg->cl.buf_ptr) || compare(re_stopped_wp_m, dbg->cl.buf_ptr))
    {
        TRACE("Stopped at xp='%.*s' addr='%.*s' name='%.*s' src='%.*s'/line=%.*s module='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so],
              (int)(rm[6].rm_eo - rm[6].rm_so), &dbg->cl.buf_ptr[rm[6].rm_so]);
        dbg->status = ss_xpoint;
        dbg->info = to_num(dbg, 1);
        wdt_free_location(&dbg->loc);
        grab_location(dbg, &dbg->loc, 2, 3, 4, 5, 6);
    }
    else if (compare(re_stopped_bp_b, dbg->cl.buf_ptr) || compare(re_stopped_wp_b, dbg->cl.buf_ptr))
    {
        TRACE("Stopped at xp='%.*s' addr='%.*s' name='%.*s' src='%.*s'/line=%.*s\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so]);
        dbg->status = ss_xpoint;
        dbg->info = to_num(dbg, 1);
        wdt_free_location(&dbg->loc);
        grab_location(dbg, &dbg->loc, 2, 3, 4, 5, -1);
    }
    else if (compare(re_funcchange, dbg->cl.buf_ptr))
    {
        TRACE("Entering function %.*s src='%.*s'/line=%.*s\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so]);
        dbg->status = ss_step;
        wdt_free_location(&dbg->loc);
        grab_location(dbg, &dbg->loc, -1, 1, 2, 3, -1);
    }
    else if (compare(re_srcline, dbg->cl.buf_ptr))
    {
        /* FIXME:
         * - this is wrong if we change to another function in the same file
         * - what happens if we move to a new function or file ??
         */
        dbg->status = ss_step;
        dbg->loc.lineno = to_num(dbg, 1);
    }
    else if (compare(re_asmline, dbg->cl.buf_ptr))
    {
        dbg->status = ss_step;
        wdt_free_location(&dbg->loc);
        grab_location(dbg, &dbg->loc, 1, 2, -1, -1, 3);
    }
    else if (compare(re_terminated, dbg->cl.buf_ptr))
    {
        TRACE("Terminated on pid %.*s\n", 
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so]);
        if (to_num(dbg, 1) != dbg->cl.info.dwProcessId)
        {
            snprintf(dbg->err_msg, sizeof(dbg->err_msg), "Wrong pid termination (%x/%x)\n",
                     to_num(dbg, 1), dbg->cl.info.dwProcessId);
            ret = -1;
        }
    }
    else TRACE("No RE-exec on '%s' for cmd=%s\n", dbg->cl.buf_ptr, cmd);
    return ret;
}

int wdt_evaluate(struct debuggee* dbg, struct mval* mv, const char* expr, ...)
{
    int         ret;
    va_list     valist;

    va_start(valist, expr);
    wtcl_send_vcmd(&dbg->cl, expr, valist);
    va_end(valist);
    ret = wtcl_recv_up_to_prompt(&dbg->cl);
    TRACE("Got for expr='%s': '%s'\n", expr, dbg->cl.buf_ptr);
    if (ret == -1)
    {
        snprintf(dbg->err_msg, sizeof(dbg->err_msg), "Couldn't evaluate expr '%s' -> %s",
                 expr, dbg->cl.buf_ptr);
        return -1;
    }
    ret = wdt_fetch_value(dbg, mv);
    if (ret == -1) TRACE("Wrong answer '%s' for expr=%s\n", dbg->cl.buf_ptr, expr);
    return ret;
}

int wdt_backtrace_next(struct debuggee* dbg, int* frame, struct location* loc, char** args)
{
    int ret = 0;

    if (loc) memset(loc, 0, sizeof(*loc));

    if (compare(re_backtrace_m, dbg->cl.buf_ptr))
    {
        /* FIXME:
         *      ebp -> _to_num(dbg, 8);
         */
        TRACE("Found frame='%.*s' addr='%.*s' name='%.*s' srcfile='%.*s' args='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so]);
        if (frame) *frame = to_num(dbg, 1);
        if (loc) grab_location(dbg, loc, 2, 3, 5, 6, 7);
        if (args) *args = to_string(dbg, 4);
        dbg->cl.buf_ptr += (int)(rm[0].rm_eo - rm[0].rm_so);
    }
    else if (compare(re_backtrace_b, dbg->cl.buf_ptr))
    {
        /* FIXME:
         *      ebp -> _to_num(dbg, 7);
         */
        TRACE("Found frame='%.*s' addr='%.*s' name='%.*s' srcfile='%.*s' args='%.*s'\n",
              (int)(rm[1].rm_eo - rm[1].rm_so), &dbg->cl.buf_ptr[rm[1].rm_so],
              (int)(rm[2].rm_eo - rm[2].rm_so), &dbg->cl.buf_ptr[rm[2].rm_so],
              (int)(rm[3].rm_eo - rm[3].rm_so), &dbg->cl.buf_ptr[rm[3].rm_so],
              (int)(rm[5].rm_eo - rm[5].rm_so), &dbg->cl.buf_ptr[rm[5].rm_so],
              (int)(rm[4].rm_eo - rm[4].rm_so), &dbg->cl.buf_ptr[rm[4].rm_so]);
        if (frame) *frame = to_num(dbg, 1);
        if (loc) grab_location(dbg, loc, 2, 3, 5, 6, -1);
        if (args) *args = to_string(dbg, 4);
        dbg->cl.buf_ptr += (int)(rm[0].rm_eo - rm[0].rm_so);
    }
    else
    {
        printf("No RE-backtrace for %s\n", dbg->cl.buf_ptr);
        ret = -1;
    }
    return ret;
}

int wdt_backtrace(struct debuggee* dbg)
{
    if (wtcl_execute(&dbg->cl, "backtrace") == -1) return -1;

    TRACE("Got for cmd='bt': '%s'\n", dbg->cl.buf_ptr);
    if (memcmp(dbg->cl.buf_ptr, "Backtrace:\n", 11))
    {
        strcpy(dbg->err_msg, "Couldn't find 'Backtrace:'");
        return -1;
    }
    dbg->cl.buf_ptr += 11;
    return 0;
}

int wdt_stop(struct debuggee* dbg)
{
    int ret;
    wtcl_send_cmd(&dbg->cl, "quit");
    ret = wtcl_recv_up_to_prompt(&dbg->cl);
    TRACE("Got for quit cmd: '%s'\n", dbg->cl.buf_ptr);
    wtcl_stop(&dbg->cl);
    dbg->status = ss_none;
    wdt_free_location(&dbg->loc);
    free_display(dbg);

    return 0;
}


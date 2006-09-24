%{
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

static int parse_error(const char* s);
int parse_lex(void);

static const char*      debugger;
static const char*      executable;
static struct debuggee  dbg;
static const char*      parse_file_name;
extern FILE*            parse_in;
extern int              parse_line;

static int test_ok(int condition, const char *msg, ...)
{
    va_list valist;

    if (!condition)
    {
        fprintf(stdout, "%s:%d: Test failed", parse_file_name, parse_line);
        va_start(valist, msg);
        fprintf( stdout,": ");
        vfprintf(stdout, msg, valist);
        va_end(valist);
    }
    return 1;
}

static void start_test(const char* args)
{
    int ret;
    char* run = malloc(strlen(debugger) + 1 + strlen(executable) + 1
                       + strlen(args) + 1);
    sprintf(run, "%s %s %s", debugger, executable, args);
    ret = wdt_start(&dbg, run);
    test_ok(ret != -1, dbg.err_msg);
}

static void check_location(const struct location* loc, const char* src, int line)
{
    if (src) test_ok(wdt_ends_with(loc->srcfile, src), "wrong src file %s\n", loc->srcfile);
    if (line) test_ok(loc->lineno == line, "wrong lineno %d\n", loc->lineno);
}

static void set_break(const char* b, int bp, const char* name, const char* src, int line)
{
    int                 xp_num;
    int                 ret;
    struct location     loc;

    ret = wdt_set_xpoint(&dbg, b, &xp_num, &loc);
    test_ok(ret != -1, dbg.err_msg);
    if (bp) test_ok(xp_num == bp, "Wrong bp number (%d)\n", xp_num);
    if (name) test_ok(!strcmp(name, loc.name), "wrong bp name (%s)\n", loc.name);
    check_location(&loc, src, line);
    wdt_free_location(&loc);
}

static void command(const char* c, int status, int bp)
{
    int                 ret;

    ret = wdt_execute(&dbg, c);
    test_ok(ret != -1, dbg.err_msg);
    if (status != -1) test_ok(dbg.status == status, "%s\n", dbg.err_msg);
    if (status == ss_xpoint) test_ok(dbg.info == bp, "hit wrong bp number %d\n", dbg.info);
}

static void check_eval(struct mval* mv, int type, int val, const char* str)
{
    switch (type)
    {
    case mv_null: case mv_error: break;
    case mv_integer: test_ok(val == mv->u.integer, "wrong int value (%d)\n", mv->u.integer); break;
    case mv_hexa:    test_ok(val == mv->u.integer, "wrong hexa value (%d)\n", mv->u.integer); break;
    case mv_char:    test_ok(val == mv->u.integer, "wrong char value (%d)\n", mv->u.integer); break;
    case mv_string:  test_ok(!strcmp(str, mv->u.str), "wrong string value (%s)\n", mv->u.str); break;
    case mv_struct:  test_ok(!strcmp(str, mv->u.str), "wrong struct value (%s)\n", mv->u.str); break;
    default: printf("Unsupported type %d\n", type);
    }
}

static void test_eval(const char* cmd, int type, int val, const char* str)
{
    struct mval mv;

    if (wdt_evaluate(&dbg, &mv, cmd) == 0)
    {
        if (mv.type != type)
            printf("Wrong returned type (%d)\n", mv.type);
        else
            check_eval(&mv, type, val, str);
    }
    else
        printf("Couldn't evaluate expression (%s)\n", dbg.err_msg);
}

static void check_display(int num, const char* name, int type, int val, const char* str)
{
    test_ok(dbg.num_display > num, "display number (%u) out of bounds (%u)\n", num, dbg.num_display);
    test_ok(!strcmp(dbg.display[num].expr, name), "wrong display (%s)\n", dbg.display[num].expr);
    check_eval(&dbg.display[num].mval, type, val, str);
}

static void check_frame(int num, const char* name, const char* file, int lineno, const char* ref_args)
{
    int                 ret, idx;
    struct location     loc;
    char*               args;

    ret = wdt_backtrace_next(&dbg, &idx, &loc, &args);
    test_ok(ret != -1, "%s\n", dbg.err_msg);
    test_ok(idx == num, "Wrong bt index (%d)\n", idx);
    if (name) test_ok(!strcmp(loc.name, name), "Wrong bt frame %s\n", loc.name);
    check_location(&loc, file, lineno);
    if (wdt_ends_with(ref_args, "...")) ret = memcmp(ref_args, args, strlen(ref_args) - 3);
    else ret = strcmp(ref_args, args);
    test_ok(!ret, "Wrong args in bt (%s)\n", args);
    wdt_free_location(&loc);
    HeapFree(GetProcessHeap(), 0, args);
}

%}

%union
{
    char*               string;
    int                 integer;
}

%token tEOF tDEBUGGER tEXECUTABLE tSTART tEND
%token tBACKTRACE tBREAK tCHECK_DISPLAY tCHECK_FRAME tCHECK_LOCATION tCOMMAND tEVAL
%token <string> tSTRING
%token <integer> tNUM tEVAL_STATUS tEXEC_STATUS

%%

input: header list_tests tEOF { return 1; }

header: tDEBUGGER tSTRING tEXECUTABLE tSTRING { debugger = strdup($2); executable = strdup($4); }

list_tests:
      test list_tests
    |
;

command: 
      tBACKTRACE {test_ok(wdt_backtrace(&dbg) == 0, dbg.err_msg);}
    | tBREAK tSTRING {set_break($2, 0, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM {set_break($2, $3, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM tSTRING tSTRING tNUM {set_break($2, $3, $4, $5, $6);}
    | tCHECK_DISPLAY tNUM {test_ok(dbg.num_display == $2, "Wrong number of displays (%d)\n", $2);}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tNUM {check_display($2, $3, $4, $5, NULL);}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tSTRING {check_display($2, $3, $4, 0, $5);}
    | tCHECK_FRAME tNUM tSTRING tSTRING tNUM tSTRING {check_frame($2, $3, $4, $5, $6);}
    | tCHECK_LOCATION tSTRING tNUM {check_location(&dbg.loc, $2, $3);}
    | tCOMMAND tSTRING {command($2, -1, -1);}
    | tCOMMAND tSTRING tEXEC_STATUS {command($2, $3, -1);}
    | tCOMMAND tSTRING tEXEC_STATUS tNUM {command($2, $3, $4);}
    | tEVAL tSTRING tEVAL_STATUS tNUM {test_eval($2, $3, $4, NULL);}
    | tEVAL tSTRING tEVAL_STATUS tSTRING {test_eval($2, $3, 0, $4);}
;

list_commands: command list_commands | ;

start_test:     tSTART tSTRING {start_test($2);};
end_test:       tEND {test_ok(wdt_stop(&dbg) == 0, dbg.err_msg);;};

test: start_test list_commands end_test;

%%

static void parse_file(const char* name)
{
    parse_in = fopen(name, "r+");
    if (!parse_in)
    {
        printf("Couldn't open %s\n", name);
        return;
    }
    parse_file_name = name;
    parse_parse();
    fclose(parse_in);
    parse_in = NULL;
}

int parse_error(const char* s)
{
    printf("Got error '%s' while parsing %s at line %d\n",
           s, parse_file_name, parse_line);
    return 0;
}

int main(int argc, char* argv[])
{
    argc--; argv++;

    do_trace = do_dump = 0;
    for (;;)
    {
        if (argc && !strcmp(argv[0], "--trace"))
        {
            do_trace = 1;
            argc--; argv++;
            continue;
        }
        if (argc && !strcmp(argv[0], "--dump"))
        {
            do_dump = 1;
            argc--; argv++;
            continue;
        }
#if YYDEBUG
        if (argc && !strcmp(argv[0], "--debug"))
        {
            parse_debug = 1;
            argc--; argv++;
            continue;
        }
#endif
        break;
    }
    if (argc != 1)
    {
        printf("Wrong number of arguments\n");
        return 0;
    }
    parse_file(argv[0]);
    return 0;
}

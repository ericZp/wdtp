%{
/*
 * Tool for testing the Wine debugger
 *
 * Copyright 2006-2008 Eric Pouech
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
static struct debuggee  dbg;
static const char*      parse_file_name;
extern FILE*            parse_in;
extern int              parse_line;
static const char*      condition;

static int str_compare(const char* ref, const char* cmp)
{
    if (!cmp) return 1;
    if (wdt_ends_with(ref, "..."))
        return memcmp(ref, cmp, strlen(ref) - 3);
    return strcmp(ref, cmp);
}

static int test_ok(int condition, const char *msg, ...)
{
    va_list valist;

    if (!condition)
    {
        fprintf(stdout, "%s:%d: Test failed", parse_file_name, parse_line);
        va_start(valist, msg);
        fprintf(stdout, ": ");
        vfprintf(stdout, msg, valist);
        fprintf(stdout, "\n");
        va_end(valist);
    }
    return 1;
}

static struct id* first_id;

struct id* fetch_id(const char* name)
{
    struct id*  id;

    for (id = first_id; id; id = id->next)
        if (!strcmp(id->name, name)) return id;
    id = malloc(sizeof(*id));
    id->name = strdup(name);
    id->mval.type = mv_error;
    id->is_system = 0;
    id->next = first_id;
    first_id = id;
    return id;
}

/* free non system ids (and keep the system ids in list) */
static void free_ids(void)
{
    struct id*  id, *next;

    for (id = first_id, first_id = NULL; id; id = next)
    {
        next = id->next;
        if (id->is_system)
        {
            id->next = first_id;
            first_id = id;
        }
        else
        {
            free((char*)id->name);
            free(id);
        }
    }
}

static const char* id_subst(const char* str)
{
    const char* ptr = str;
    const char* start;
    const char* end;
    unsigned    id_len;

    while ((start = strchr(ptr, '$')))
    {
        end = strchr(start + 1, '$');
        if (end)
        {
            struct id*  id;
            char*       tmp;

            id_len = end - start + 1;
            for (id = first_id; id; id = id->next)
            {
                if (memcmp(id->name, start, id_len) || id->name[id_len] != '\0')
                    continue;

                tmp = malloc(strlen(str) + 1 + 64 /* FIXME */ - id_len);
                memcpy(tmp, ptr, start - ptr);
                switch (id->mval.type)
                {
                case mv_char: case mv_integer: sprintf(tmp + (start - ptr), "%d", id->mval.u.integer); break;
                case mv_hexa: case mv_func: sprintf(tmp + (start - ptr), "0x%x", id->mval.u.integer); break;
                case mv_string: case mv_struct: strcpy(tmp + (start - ptr), id->mval.u.str); break;
                case mv_error: strcpy(tmp + (start - ptr), "<<*** error ***>>"); break;
                default: assert(0);
                }
                strcat(tmp, end + 1);
                if (ptr != str) free((char*)ptr);
                ptr = tmp;
                break;
            }
            assert(id);
        }
    }
    return ptr;
}

static int start_test(const char* exec, const char* args)
{
    int ret;
    char* run;

    exec = id_subst(exec);
    if (!debugger)
    {
        test_ok(debugger != NULL, "No debugger defined");
        exit(0);
    }
    run = malloc(strlen(debugger) + 1 + strlen(exec) + 1 + strlen(args) + 1);
    sprintf(run, "%s %s %s", debugger, exec, args);
    ret = wdt_start(&dbg, run);
    test_ok(ret != -1, dbg.err_msg);
    return ret;
}

static void check_location(const struct location* loc, const char* name, const char* src, int line)
{
    if (name) test_ok(loc->name && !strcmp(name, loc->name), "wrong function name %s", loc->name);
    if (src) test_ok(wdt_ends_with(loc->srcfile, src), "wrong src file %s", loc->srcfile);
    if (line) test_ok(loc->lineno == line, "wrong lineno %d", loc->lineno);
}

static void set_break(const char* cmd, int bp, const char* name, const char* src, int line)
{
    int                 xp_num;
    int                 ret;
    struct location     loc;

    ret = wdt_set_xpoint(&dbg, id_subst(cmd), &xp_num, &loc);
    test_ok(ret != -1, dbg.err_msg);
    if (bp) test_ok(xp_num == bp, "Wrong bp number (%d)", xp_num);
    if (name) test_ok(loc.name && !strcmp(name, loc.name), "wrong bp name (%s)", loc.name);
    check_location(&loc, NULL, src, line);
    wdt_free_location(&loc);
}

static void command_run(const char* c, int status, int bp)
{
    int                 ret;

    ret = wdt_execute(&dbg, c);
    test_ok(ret != -1, dbg.err_msg);
    if (status != -1) test_ok(dbg.status == status, "%s", dbg.err_msg);
    if (status == ss_xpoint) test_ok(dbg.info == bp, "hit wrong bp number %d", dbg.info);
}

static void command(const char* c, const char* result)
{
    int                 ret;

    ret = wdt_execute(&dbg, c);
    test_ok(ret != -1, dbg.err_msg);
    if (result) test_ok(!memcmp(dbg.cl.buf_ptr, result, strlen(result)),
                        "Unexpected command result %s\n", dbg.cl.buf_ptr);
}

static void check_eval(struct mval* mv, const struct mval* mv2)
{
    test_ok(mv->type == mv2->type, "Wrong returned type %d, while expecting %d", mv->type, mv2->type);
    /* FIXME: may have to do some type promotions */
    if (mv->type != mv2->type) return;
    switch (mv2->type)
    {
    case mv_null: case mv_error: break;
    case mv_integer: test_ok(mv2->u.integer == mv->u.integer, "wrong int value (%d)", mv->u.integer); break;
    case mv_hexa:    test_ok(mv2->u.integer == mv->u.integer, "wrong hexa value (%d)", mv->u.integer); break;
    case mv_float:   test_ok(mv2->u.flt_number == mv->u.flt_number, "wrong float value (%lf)", mv->u.flt_number); break;
    case mv_char:    test_ok(mv2->u.integer == mv->u.integer, "wrong char value (%d)", mv->u.integer); break;
    case mv_string:  test_ok(!str_compare(mv2->u.str, mv->u.str), "wrong string value (%s)", mv->u.str); break;
    case mv_struct:  test_ok(!str_compare(mv2->u.str, mv->u.str), "wrong struct value (%s)", mv->u.str); break;
    default: test_ok(0, "Unsupported type %d", mv2->type);
    }
}

static void test_eval(const char* cmd, const struct mval* mv2)
{
    struct mval mv;

    if (wdt_evaluate(&dbg, &mv, cmd) == 0)
    {
        check_eval(&mv, mv2);
    }
    else
        test_ok(mv2->type == mv_error, "Couldn't evaluate expression '%s' (%s)", cmd, dbg.err_msg);
}

static void set_eval(const char* cmd, struct id* id)
{
    test_ok(id != NULL, "Unknown id");
    if (!id) return;
    if (wdt_evaluate(&dbg, &id->mval, cmd) != 0)
    {
        test_ok(0, "Couldn't evaluate expression (%s)", dbg.err_msg);
        id->mval.type = mv_error;
    }
}

static void check_display(int num, const char* name, const struct mval* mv2)
{
    test_ok(dbg.num_display > num, "display number (%u) out of bounds (%u)", num, dbg.num_display);
    test_ok(!strcmp(dbg.display[num].expr, name), "wrong display (%s)", dbg.display[num].expr);
    check_eval(&dbg.display[num].mval, mv2);
}

static void check_frame(int num, const char* name, const char* file, int lineno, const char* ref_args)
{
    int                 ret, idx;
    struct location     loc;
    char*               args;

    ret = wdt_backtrace_next(&dbg, &idx, &loc, &args);
    test_ok(ret != -1, "%s", dbg.err_msg);
    test_ok(idx == num, "Wrong bt index (%d)", idx);
    check_location(&loc, name, file, lineno);
    test_ok(!str_compare(ref_args, args), "Wrong args in bt (%s)", args);
    wdt_free_location(&loc);
    free(args);
}

static void launch(const char* cmd, struct id* id)
{
    STARTUPINFOA        startup;
    PROCESS_INFORMATION info;
    BOOL                ret;

    memset(&startup, 0, sizeof(startup));
    startup.cb = sizeof(startup);

    ret = CreateProcessA(NULL, (char*)id_subst(cmd), NULL, NULL, TRUE, 0*DETACHED_PROCESS,
                         NULL, NULL, &startup, &info);
    test_ok(ret, "Couldn't create process with command line '%s'", cmd);
    if (ret)
    {
        id->mval.type = mv_integer;
        id->mval.u.integer = info.dwProcessId;
        CloseHandle(info.hProcess);
        CloseHandle(info.hThread);
    }
    else id->mval.type = mv_error;
}

static unsigned do_command = TRUE;
static unsigned exec_block = TRUE;

static void set_condition(const char* cond)
{
    do_command = !condition || !strcmp(condition, cond);
}

static unsigned doit(void)
{
    return do_command && exec_block;
}

%}

%union
{
    char*               string;
    int                 integer;
    double              flt_number;
    struct id*          id;
}

%token tEOF tEXECUTABLE tSTART tEND
%token tBACKTRACE tBREAK tCHECK_DISPLAY tCHECK_FRAME tCHECK_LOCATION tCOMMAND tEVAL
%token tLAUNCH tSYSTEM
%token <string> tSTRING tCONDITION
%token <integer> tNUM tEVAL_STATUS tEXEC_STATUS
%token <flt_number> tFLOAT
%token <id> tID

%%

input: list_items tEOF { return 1; }

list_items:
      item list_items
    |
;

item:
      start_test list_commands end_test
    | tLAUNCH tSTRING tID { launch($2, $3); }
;


command:
      tBACKTRACE {if (doit()) test_ok(wdt_backtrace(&dbg) == 0, dbg.err_msg);}
    | tBREAK tSTRING {if (doit()) set_break($2, 0, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM {if (doit()) set_break($2, $3, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM tSTRING {if (doit()) set_break($2, $3, $4, NULL, 0);}
    | tBREAK tSTRING tNUM tSTRING tSTRING tNUM {if (doit()) set_break($2, $3, $4, $5, $6);}
    | tCHECK_DISPLAY tNUM {if (doit()) test_ok(dbg.num_display == $2, "Wrong number of displays (%d)", $2);}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tNUM {if (doit()) {struct mval mv; mv.type = $4; mv.u.integer = $5; check_display($2, $3, &mv);}}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tFLOAT {if (doit()) {struct mval mv; mv.type = $4; mv.u.flt_number = $5; check_display($2, $3, &mv);}}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tSTRING {if (doit()) {struct mval mv; mv.type = $4; mv.u.str = $5; check_display($2, $3, &mv);}}
    | tCHECK_FRAME tNUM tSTRING tSTRING tNUM tSTRING {if (doit()) check_frame($2, $3, $4, $5, $6);}
    | tCHECK_LOCATION tSTRING tNUM {if (doit()) check_location(&dbg.loc, NULL, $2, $3);}
    | tCHECK_LOCATION tSTRING tSTRING tNUM {if (doit()) check_location(&dbg.loc, $2, $3, $4);}
    | tCOMMAND tSTRING {if (doit()) command($2, NULL);}
    | tCOMMAND tSTRING tSTRING {if (doit()) command($2, $3);}
    | tCOMMAND tSTRING tEXEC_STATUS {if (doit()) command_run($2, $3, -1);}
    | tCOMMAND tSTRING tEXEC_STATUS tNUM {if (doit()) command_run($2, $3, $4);}
    | tEVAL tSTRING tEVAL_STATUS {if (doit()) {struct mval mv; mv.type = $3; test_eval($2, &mv);}}
    | tEVAL tSTRING tEVAL_STATUS tNUM {if (doit()) {struct mval mv; mv.type = $3; mv.u.integer = $4; test_eval($2, &mv);}}
    | tEVAL tSTRING tEVAL_STATUS tSTRING {if (doit()) {struct mval mv; mv.type = $3; mv.u.str = $4; test_eval($2, &mv);}}
    | tEVAL tSTRING tEVAL_STATUS tFLOAT {if (doit()) {struct mval mv; mv.type = $3; mv.u.flt_number = $4; test_eval($2, &mv);}}
    | tEVAL tSTRING tID {if (doit()) set_eval($2, $3);}
    | tSYSTEM tSTRING {if (doit()) system($2);}
    | tSYSTEM tSTRING tNUM {if (doit()) {int r = system($2); test_ok(r == $3, "Wrong system() result (%d)\n", r);}}
;

cond_command:
      command
    | tCONDITION {set_condition($1);} command {do_command = TRUE;}
;

list_commands: cond_command list_commands | ;

start_test:
      tSTART tSTRING {if (start_test($2, "") == -1) exec_block = FALSE;}
    | tSTART tSTRING tSTRING {if (start_test($2, $3) == -1) exec_block = FALSE;}
;
end_test:
      tEND {if (exec_block) test_ok(wdt_stop(&dbg) == 0, dbg.err_msg); else exec_block = TRUE; free_ids()};

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
    parse_line = 1;
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
        if (argc > 1 && !strcmp(argv[0], "--condition"))
        {
            argc--; argv++;
            condition = argv[0];
            argc--; argv++;
            continue;
        }
        if (argc > 1 && !strcmp(argv[0], "--flavor"))
        {
            struct id*  id;

            argc--; argv++;
            id = fetch_id("$flavor$");
            id->mval.type = mv_string;
            id->mval.u.str = argv[0];
            id->is_system = 1;
            argc--; argv++;
            continue;
        }
        if (argc > 1 && !strcmp(argv[0], "--debugger"))
        {
            argc--; argv++;
            free((char*)debugger);
            debugger = strdup(argv[0]);
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

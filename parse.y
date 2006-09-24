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
static struct debuggee  dbg;
static const char*      parse_file_name;
extern FILE*            parse_in;
extern int              parse_line;
static const char*      condition;

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
    id->next = first_id;
    first_id = id;
    return id;
}

static void free_ids(void)
{
    struct id*  id, *next;

    for (id = first_id; id; id = next)
    {
        next = id->next;
        free((char*)id->name);
        free(id);
    }
    first_id = NULL;
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
                    /* mv_error */
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

static void start_test(const char* exec, const char* args)
{
    int ret;
    char* run;
    const char* ext = ".so"; /* FIXME */

    exec = id_subst(exec);
    if (!debugger)
    {
        test_ok(debugger != NULL, "No debugger defined");
        exit(0);
    }
    if (!wdt_ends_with(exec, ".exe")) ext = "";
    run = malloc(strlen(debugger) + 1 + strlen(exec) + strlen(ext) + 1 +
                 strlen(args) + 1);
    sprintf(run, "%s %s%s %s", debugger, exec, ext, args);
    ret = wdt_start(&dbg, run);
    test_ok(ret != -1, dbg.err_msg);
}

static void check_location(const struct location* loc, const char* name, const char* src, int line)
{
    if (name) test_ok(!strcmp(name, loc->name), "wrong function name %s", loc->name);
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
    if (name) test_ok(!strcmp(name, loc.name), "wrong bp name (%s)", loc.name);
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

static void check_eval(struct mval* mv, int type, int val, const char* str)
{
    switch (type)
    {
    case mv_null: case mv_error: break;
    case mv_integer: test_ok(val == mv->u.integer, "wrong int value (%d)", mv->u.integer); break;
    case mv_hexa:    test_ok(val == mv->u.integer, "wrong hexa value (%d)", mv->u.integer); break;
    case mv_char:    test_ok(val == mv->u.integer, "wrong char value (%d)", mv->u.integer); break;
    case mv_string:  test_ok(!strcmp(str, mv->u.str), "wrong string value (%s)", mv->u.str); break;
    case mv_struct:  test_ok(!strcmp(str, mv->u.str), "wrong struct value (%s)", mv->u.str); break;
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

static void set_eval(const char* cmd, struct id* id)
{
    test_ok(id != NULL, "Unknown id");
    if (!id) return;
    if (wdt_evaluate(&dbg, &id->mval, cmd) != 0)
    {
        printf("Couldn't evaluate expression (%s)\n", dbg.err_msg);
        id->mval.type = mv_error;
    }
}

static void check_display(int num, const char* name, int type, int val, const char* str)
{
    test_ok(dbg.num_display > num, "display number (%u) out of bounds (%u)", num, dbg.num_display);
    test_ok(!strcmp(dbg.display[num].expr, name), "wrong display (%s)", dbg.display[num].expr);
    check_eval(&dbg.display[num].mval, type, val, str);
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
    if (wdt_ends_with(ref_args, "...")) ret = memcmp(ref_args, args, strlen(ref_args) - 3);
    else ret = strcmp(ref_args, args);
    test_ok(!ret, "Wrong args in bt (%s)", args);
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

    ret = CreateProcessA(NULL, (char*)cmd, NULL, NULL, TRUE, 0*DETACHED_PROCESS,
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

static void set_condition(const char* cond)
{
    do_command = !condition || !strcmp(condition, cond);
}

static unsigned doit(void)
{
    return do_command;
}

%}

%union
{
    char*               string;
    int                 integer;
    struct id*          id;
}

%token tEOF tDEBUGGER tEXECUTABLE tSTART tEND
%token tBACKTRACE tBREAK tCHECK_DISPLAY tCHECK_FRAME tCHECK_LOCATION tCOMMAND tEVAL
%token tLAUNCH
%token <string> tSTRING tCONDITION
%token <integer> tNUM tEVAL_STATUS tEXEC_STATUS
%token <id> tID

%%

input: list_items tEOF { return 1; }

list_items:
      item list_items
    |
;

item:
      start_test list_commands end_test
    | tDEBUGGER tSTRING { free((char*)debugger); debugger = strdup($2); }
    | tLAUNCH tSTRING tID { launch($2, $3); }
;


command: 
      tBACKTRACE {if (doit()) test_ok(wdt_backtrace(&dbg) == 0, dbg.err_msg);}
    | tBREAK tSTRING {if (doit()) set_break($2, 0, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM {if (doit()) set_break($2, $3, NULL, NULL, 0);}
    | tBREAK tSTRING tNUM tSTRING {if (doit()) set_break($2, $3, $4, NULL, 0);}
    | tBREAK tSTRING tNUM tSTRING tSTRING tNUM {if (doit()) set_break($2, $3, $4, $5, $6);}
    | tCHECK_DISPLAY tNUM {if (doit()) test_ok(dbg.num_display == $2, "Wrong number of displays (%d)", $2);}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tNUM {if (doit()) check_display($2, $3, $4, $5, NULL);}
    | tCHECK_DISPLAY tNUM tSTRING tEVAL_STATUS tSTRING {if (doit()) check_display($2, $3, $4, 0, $5);}
    | tCHECK_FRAME tNUM tSTRING tSTRING tNUM tSTRING {if (doit()) check_frame($2, $3, $4, $5, $6);}
    | tCHECK_LOCATION tSTRING tNUM {if (doit()) check_location(&dbg.loc, NULL, $2, $3);}
    | tCHECK_LOCATION tSTRING tSTRING tNUM {if (doit()) check_location(&dbg.loc, $2, $3, $4);}
    | tCOMMAND tSTRING {if (doit()) command($2, NULL);}
    | tCOMMAND tSTRING tSTRING {if (doit()) command($2, $3);}
    | tCOMMAND tSTRING tEXEC_STATUS {if (doit()) command_run($2, $3, -1);}
    | tCOMMAND tSTRING tEXEC_STATUS tNUM {if (doit()) command_run($2, $3, $4);}
    | tEVAL tSTRING tEVAL_STATUS tNUM {if (doit()) test_eval($2, $3, $4, NULL);}
    | tEVAL tSTRING tEVAL_STATUS tSTRING {if (doit()) test_eval($2, $3, 0, $4);}
    | tEVAL tSTRING tID {if (doit()) set_eval($2, $3);}
;

cond_command: 
      command
    | tCONDITION {set_condition($1);} command {do_command = TRUE;}
;

list_commands: cond_command list_commands | ;

start_test:     
      tSTART tSTRING {start_test($2, "");}
    | tSTART tSTRING tSTRING {start_test($2, $3);}
;
end_test:       tEND {test_ok(wdt_stop(&dbg) == 0, dbg.err_msg); free_ids();};

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

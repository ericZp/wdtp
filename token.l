/*
 * Lexical scanner for wdtp
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

%option nounput interactive 8bit prefix="parse_"

%{
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "parse.tab.h"
#include "wdbgtest.h"

int parse_line;
static char*    ptr;
static int      size;

static void add_char(char** start, char ch)
{
    if (ptr - *start >= size)
    {
        char* new = realloc(*start, size *= 2);
        if (!new) return;
        ptr = new + (ptr - *start);
        *start = new;
    }
    *ptr++ = ch;
}

%}

DIGIT	   [0-9]
HEXDIGIT   [0-9a-fA-F]

%x astring

%%

<<EOF>>                         { return tEOF; }
\"                              { ptr = parse_lval.string = malloc(size = 32); BEGIN(astring); }
<astring>\"                     { BEGIN(INITIAL); add_char(&parse_lval.string, '\0'); return tSTRING; }
<astring>\\.                    { add_char(&parse_lval.string, yytext[1]); }
<astring>[^\\\n\"]              { add_char(&parse_lval.string, yytext[0]); }
"#".*\n                         { parse_line++; } /* skip comments */
"0x"{HEXDIGIT}+                 { sscanf(yytext, "%x", &parse_lval.integer); return tNUM; }
"'"."'"                         { parse_lval.integer = yytext[1]; return tNUM; }
[+-]?{DIGIT}+             	{ sscanf(yytext, "%d", &parse_lval.integer); return tNUM; }
"$"[A-Za-z_]+"$"                { parse_lval.id = fetch_id(yytext); return tID; }
"["[A-Za-z_]+"]"                { char* ptr = parse_lval.string = strdup(yytext + 1); ptr[strlen(ptr) - 1] = '\0'; return tCONDITION; }
DEBUGGER                        { return tDEBUGGER; }
LAUNCH                          { return tLAUNCH; }
START                      	{ return tSTART; }
BACKTRACE                       { return tBACKTRACE; }
BREAK                           { return tBREAK; }
CHECK_DISPLAY                   { return tCHECK_DISPLAY; }
CHECK_FRAME                     { return tCHECK_FRAME; }
CHECK_LOCATION                  { return tCHECK_LOCATION; }
COMMAND                         { return tCOMMAND; }
EVAL                            { return tEVAL; }
END                      	{ return tEND; }
mv_null                         { parse_lval.integer = mv_null; return tEVAL_STATUS; }
mv_integer                      { parse_lval.integer = mv_integer; return tEVAL_STATUS; }
mv_hexa                         { parse_lval.integer = mv_hexa; return tEVAL_STATUS; }
mv_string                       { parse_lval.integer = mv_string; return tEVAL_STATUS; }
mv_char                         { parse_lval.integer = mv_char; return tEVAL_STATUS; }
mv_struct                       { parse_lval.integer = mv_struct; return tEVAL_STATUS; }
mv_func                         { parse_lval.integer = mv_func; return tEVAL_STATUS; }
mv_error                        { parse_lval.integer = mv_error; return tEVAL_STATUS; }
ss_none                         { parse_lval.integer = ss_none; return tEXEC_STATUS; }
ss_started                      { parse_lval.integer = ss_started; return tEXEC_STATUS; }
ss_xpoint                       { parse_lval.integer = ss_xpoint; return tEXEC_STATUS; }
ss_exception                    { parse_lval.integer = ss_exception; return tEXEC_STATUS; }
ss_step                         { parse_lval.integer = ss_step; return tEXEC_STATUS; }
[ \t\r]+                        /* Eat up whitespace and DOS LF */
\n                              { parse_line++; }
.                               {printf("unexpected char %s\n", yytext);}
%%

#ifndef parse_wrap
int parse_wrap(void) { return 1; }
#endif

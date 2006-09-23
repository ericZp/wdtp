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
%}

DIGIT	   [0-9]
HEXDIGIT   [0-9a-fA-F]
STRING     \"[^\n"]+\"

%%

<<EOF>>                         { return tEOF; }
"0x"{HEXDIGIT}+                 { sscanf(yytext, "%x", &parse_lval.integer); return tNUM; }
{DIGIT}+             		{ sscanf(yytext, "%d", &parse_lval.integer); return tNUM; }
{STRING} 			{ parse_lval.string = strdup(yytext + 1); parse_lval.string[strlen(parse_lval.string) - 1] = '\0'; return tSTRING; }
START                      	{ return tSTART; }
END                      	{ return tEND; }
<*>[ \t\r]+                     /* Eat up whitespace and DOS LF */

%%

#ifndef parse_wrap
int parse_wrap(void) { return 1; }
#endif

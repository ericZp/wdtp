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

%}

%union
{
    char*               string;
    int                 integer;
}

%token tEOF tSTART tEND tSTRING tCOMMAND tNUM

%%

input:
      test input
    | tEOF;

command: tCOMMAND;

list_commands: command | ;

start_test:     tSTART tSTRING;
end_test:       tEND;

test: start_test list_commands end_test;

%%

int parse_error(const char* s)
{
    printf("Got error '%s' while parsing\n", s);
    return 0;
}

extern FILE* parse_in;
void parse_file(const char* name)
{
    parse_in = fopen(name, "r+");
    if (!parse_in)
    {
        printf("Couldn't open %s\n", name);
        return;
    }
    parse_parse();
    fclose(parse_in);
    parse_in = NULL;
}

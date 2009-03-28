#include <stdio.h>
#include <string.h>
#include "wdtp.h"

int wdtp_dummy_counter = 0;
int main(int argc, const char* argv[])
{
    if (argc < 2) return -1;
    if (!strcmp(argv[1], "display")) return test_display(argc - 2, argv + 2);
    if (!strcmp(argv[1], "execute")) return test_execute(argc - 2, argv + 2);
    if (!strcmp(argv[1], "expr")) return test_expr(argc - 2, argv + 2);
    if (!strcmp(argv[1], "stack")) return test_stack(argc - 2, argv + 2);
    if (!strcmp(argv[1], "start")) return test_start(argc - 2, argv + 2);
    if (!strcmp(argv[1], "type")) return test_type(argc - 2, argv + 2);
    if (!strcmp(argv[1], "xpoint")) return test_xpoint(argc - 2, argv + 2);
    printf("--< Unsupported test '%s' >--\n", argv[1]);
    return -1;
}

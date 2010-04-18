dnl Process this file with autoconf to produce a configure script.
dnl Original author: Michael Patra
dnl See ChangeLog file for detailed change history.

AC_PREREQ(2.53b)
AC_INIT([Wdtp],"Wdtp-0.01",[eric.pouech@wanadoo.fr])

dnl **** Command-line arguments ****

AC_ARG_WITH(wine,AS_HELP_STRING([--with-wine=<dir>],[set Wine directory as <dir> (~/wine if none)]))
AC_ARG_WITH(wine_output,AS_HELP_STRING([--with-wine-output=<dir>],[set Wine output directory as <dir> (same as --with-wine if none)]))
AC_ARG_WITH(mingw32,AS_HELP_STRING([--with-mingw32=<dir>],[tells where to find MingW32 cross-compilation]))
AC_ARG_WITH(msvc,AS_HELP_STRING([--with-msvc=<dir>],[tells where to find MS Visual C compiler]))

dnl **** Checking the provided CL arguments ****

if test -z "$with_wine"; then
	with_wine="~/wine";
fi

if test ! -f "$with_wine/configure.ac"; then
	AC_MSG_ERROR([Couldn't find a Wine source tree. Use --with-wine=<dir>]);
fi

if test -z "$with_wine_output"; then
	with_wine_output=$with_wine;
fi

if test ! -f "$with_wine_output/programs/Makeprog.rules"; then
	AC_MSG_ERROR([Couldn't find a Wine output tree. Use --with-wine-output=<dir>]);
fi

dnl

AC_SUBST(WINE_SRC_DIR,$with_wine)
AC_SUBST(WINE_DST_DIR,$with_wine_output)
AC_SUBST(MINGW32,${with_mingw32:-false})
AC_SUBST(MSVC,${with_msvc:-false})

WDTP_ADD_COMPILER(gcc, true, [\$(WDTP_SRCS)], [\$(WINEGCC) \$(WDTPCFLAGS)],
	[-mconsole -o \$@ \$(WDTP_SRCS) -lkernel32])
WDTP_DEFINE_FLAVOR(gcc, stabspO0, stabs, [-gstabs+ -O0])
WDTP_DEFINE_FLAVOR(gcc, dwarfO0, dwarf, [-gdwarf-2 -O0])
WDTP_DEFINE_FLAVOR(gcc, dwarfO2, dwarf, [-gdwarf-2 -O2])

WDTP_ADD_COMPILER(msvc, [${with_msvc}], [\$(WDTP_SRCS)], [\$(WINE) \"\$(MSVC_DIR)\"/bin/cl.exe \$(MSVC_CFLAGS)],
	[/Fe\$@ \$(WDTP_SRCS) \$(MSVC_LINK)
	-rm -f \$(WDTP_SRCS:%.c=%.obj) \$(@:%.exe=%.ilk)])
WDTP_DEFINE_FLAVOR(msvc, pdbOd, pdb, [/Od], true)

WDTP_ADD_COMPILER(mingw32, [${with_msvc}], [\$(WDTP_SRCS)], [\$(MINGW32) \$(WDTPCFLAGS)],
	 [-B\$(TOOLSDIR)/tools/winebuild -mconsole -o \$@ \$(WDTP_SRCS) -lkernel32])
WDTP_DEFINE_FLAVOR(mingw32, stabspO0, stabs, [-gstabs+ -O0], true)
WDTP_DEFINE_FLAVOR(mingw32, dwarfO0, dwarf, [-gdwarf-2 -O0], true)
WDTP_DEFINE_FLAVOR(mingw32, dwarfO2, dwarf, [-gdwarf-2 -O2], true)

WDTP_FINISH

dnl

MAKE_RULES="$with_wine_output/Make.rules"
AC_SUBST_FILE(MAKE_RULES)

MAKE_DLL_RULES="$with_wine_output/dlls/Makedll.rules"
AC_SUBST_FILE(MAKE_DLL_RULES)

MAKE_IMPLIB_RULES="$with_wine_output/dlls/Makeimplib.rules"
AC_SUBST_FILE(MAKE_IMPLIB_RULES)

MAKE_TEST_RULES="$with_wine_output/dlls/Maketest.rules"
AC_SUBST_FILE(MAKE_TEST_RULES)

MAKE_PROG_RULES="$with_wine_output/programs/Makeprog.rules"
AC_SUBST_FILE(MAKE_PROG_RULES)

dnl *** Now output the various files ***
AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([wdbgtest.run],[chmod +x wdbgtest.run])
AC_OUTPUT

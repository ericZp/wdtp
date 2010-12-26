dnl Process this file with autoconf to produce a configure script.
dnl Original author: Michael Patra
dnl See ChangeLog file for detailed change history.

AC_PREREQ(2.53b)
AC_INIT([Wdtp],[Wdtp-0.01],[eric.pouech@wanadoo.fr])

dnl **** Command-line arguments ****

AC_ARG_WITH(wine,AS_HELP_STRING([--with-wine=<dir>],[set Wine directory as <dir> (~/wine if none)]))
AC_ARG_WITH(wine_output,AS_HELP_STRING([--with-wine-output=<dir>],[set Wine output directory as <dir> (same as --with-wine if none)]))
AC_ARG_WITH(mingw32,AS_HELP_STRING([--with-mingw32=<dir>],[tells where to find MingW32 cross-compilation]))
AC_ARG_WITH(msvc,AS_HELP_STRING([--with-msvc=<dir>],[tells where to find MS Visual C compiler]))
AC_ARG_ENABLE(win64,AS_HELP_STRING([--enable-win64],[build a 64bit target]))

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

dnl **** some basic configuration ****

AC_CONFIG_AUX_DIR([$with_wine/tools])

AC_CANONICAL_HOST

AC_PROG_CC
AC_CHECK_PROGS(BISON,bison,none)
AC_CHECK_PROGS(FLEX,flex,none)

dnl check whether we build a 32 vs 64 bit target
dnl should check that the wine directory contains the right bitness
dnl FIXME: could also infer wine/wine64/winewow from there

if test "x$enable_win64" = "xyes"
then
	case $host in
	*-darwin*) CC="$CC -m64"; AC_SUBST(TARGETFLAGS,"-m64");;
	esac
else
	case $host in
	x86_64*) CC="$CC -m32"; AC_SUBST(TARGETFLAGS,"-m32");;
	esac
fi
dnl FIXME should test whether Wall is supported
CC="$CC -Wall"

dnl the various compilers & flavors

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

dnl *** Now output the various files ***

AC_CONFIG_FILES([Makefile])
AC_OUTPUT

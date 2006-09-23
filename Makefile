TOPSRCDIR = /home/eric/wine-git
TOPOBJDIR = /home/eric/output-wine/wine-git
SRCDIR    = /home/eric/wdtp
VPATH     = /home/eric/wdtp
MODULE    = winedbg.exe
APPMODE   = -mconsole
IMPORTS   = psapi dbghelp advapi32 kernel32 ntdll
DELAYIMPORTS = user32
EXTRALIBS = 

C_SRCS = \
	wdbgtest.c

LEX_SRCS   = token.l
BISON_SRCS = parse.y

# Global rules for building a Winelib program     -*-Makefile-*-
#
# Each individual makefile should define the following variables:
# MODULE       : name of the main module being built
# APPMODE      : program mode (-mwindows,-mconsole)
# EXTRALIBS    : extra libraries to link in (optional)
# EXTRADEFS    : extra symbol definitions, like -DWINELIB (optional)
#
# plus all variables required by the global Make.rules.in
#

DLLFLAGS    = -D_REENTRANT -fPIC
DEFS        = $(EXTRADEFS)
ALL_LIBS    = $(DELAYIMPORTS:%=-l%) $(IMPORTS:%=-l%) $(EXTRALIBS) $(LIBPORT) $(LDFLAGS) $(LIBS)
BASEMODULE  = $(MODULE:.exe=)
RUNTESTFLAGS= -q -P wine -T $(TOPOBJDIR)
INSTALLDIRS = $(DESTDIR)$(bindir) $(DESTDIR)$(dlldir) $(DESTDIR)$(mandir)/man$(prog_manext)

# Global rules shared by all makefiles     -*-Makefile-*-
#
# Each individual makefile must define the following variables:
# TOPSRCDIR    : top-level source directory
# TOPOBJDIR    : top-level object directory
# SRCDIR       : source directory for this module
# MODULE       : name of the module being built
#
# Each individual makefile may define the following additional variables:
# C_SRCS       : C sources for the module
# C_SRCS16     : 16-bit C sources for the module
# RC_SRCS      : resource source files
# EXTRA_SRCS   : extra source files for make depend
# EXTRA_OBJS   : extra object files
# IMPORTS      : dlls to import
# DELAYIMPORTS : dlls to import in delayed mode
# SUBDIRS      : subdirectories that contain a Makefile
# EXTRASUBDIRS : subdirectories that do not contain a Makefile
# INSTALLSUBDIRS : subdirectories to run make install/uninstall into
# MODCFLAGS    : extra CFLAGS for this module

# First some useful definitions

SHELL     = /bin/sh
CC        = gcc
CFLAGS    =  -gdwarf-2
CPPFLAGS  = 
LIBS      = 
BISON     = bison
LEX       = flex
LEXLIB    = -lfl
EXEEXT    = 
OBJEXT    = o
LIBEXT    = so
DLLEXT    = .so
IMPLIBEXT = def
LDSHARED  = $(CC) -shared $(SONAME:%=-Wl,-soname,%) $(VERSCRIPT:%=-Wl,--version-script=%)
DLLTOOL   = false
DLLWRAP   = 
AR        = ar rc
RANLIB    = ranlib
STRIP     = strip
WINDRES   = false
LN        = ln
LN_S      = ln -s
TOOLSDIR  = $(TOPOBJDIR)
AS        = as
LD        = ld
LDFLAGS   = 
PRELINK   = false
RM        = rm -f
MV        = mv
LINT      = 
LINTFLAGS = 
FONTFORGE = fontforge
INCLUDES     = -I$(SRCDIR) -I. -I$(TOPSRCDIR)/include -I$(TOPOBJDIR)/include $(EXTRAINCL)
EXTRACFLAGS  = -Wall -pipe -fno-strict-aliasing -Wdeclaration-after-statement -Wwrite-strings -Wpointer-arith
ALLCFLAGS    = $(INCLUDES) $(DEFS) $(DLLFLAGS) $(EXTRACFLAGS) $(CPPFLAGS) $(CFLAGS) $(MODCFLAGS)
ALLLINTFLAGS = $(INCLUDES) $(DEFS) $(LINTFLAGS)
IDLFLAGS     = $(INCLUDES) $(DEFS) $(EXTRAIDLFLAGS)
WINEBUILDFLAGS = $(DLLFLAGS) --as-cmd "$(AS)"
MKINSTALLDIRS= $(TOPSRCDIR)/tools/mkinstalldirs -m 755
WINAPI_CHECK = $(TOPSRCDIR)/tools/winapi/winapi_check
WINEWRAPPER  = $(TOPSRCDIR)/tools/winewrapper
C2MAN        = $(TOPSRCDIR)/tools/c2man.pl
RUNTEST      = $(TOPSRCDIR)/tools/runtest
WINEBUILD    = $(TOOLSDIR)/tools/winebuild/winebuild
MAKEDEP      = $(TOOLSDIR)/tools/makedep
MAKECTESTS   = $(TOOLSDIR)/tools/make_ctests
WRC          = $(TOOLSDIR)/tools/wrc/wrc
BIN2RES      = $(TOOLSDIR)/tools/bin2res
WMC          = $(TOOLSDIR)/tools/wmc/wmc
WIDL         = $(TOOLSDIR)/tools/widl/widl
WINEGCC      = $(TOOLSDIR)/tools/winegcc/winegcc
RELPATH      = $(TOOLSDIR)/tools/relpath
SFNT2FNT     = $(TOOLSDIR)/tools/sfnt2fnt
FNT2FON      = $(TOOLSDIR)/tools/fnt2fon
RC           = $(WRC)
RC16         = $(WRC)
RCFLAGS      = --nostdinc $(INCLUDES) $(DEFS) $(EXTRARCFLAGS)
RC16FLAGS    = -O res16 $(RCFLAGS)
LDPATH       = LD_LIBRARY_PATH="$(TOOLSDIR)/libs/wine:$$LD_LIBRARY_PATH"
DLLDIR       = $(TOPOBJDIR)/dlls
LIBPORT      = $(TOPOBJDIR)/libs/port/libwine_port.a
LIBWPP       = $(TOPOBJDIR)/libs/wpp/libwpp.a
LIBWINE      = -L$(TOPOBJDIR)/libs/wine -lwine
LIBWINE_LDFLAGS = -Wl,--rpath,\$$ORIGIN/`$(RELPATH) $(bindir) $(libdir)` $(LIBWINE)



# Installation infos

INSTALL         = /usr/bin/install -c $(INSTALL_FLAGS)
INSTALL_PROGRAM = ${INSTALL} $(INSTALL_PROGRAM_FLAGS)
INSTALL_SCRIPT  = ${INSTALL} $(INSTALL_SCRIPT_FLAGS)
INSTALL_DATA    = ${INSTALL} -m 644 $(INSTALL_DATA_FLAGS)
prefix          = /usr/local
exec_prefix     = ${prefix}
bindir          = ${exec_prefix}/bin
libdir          = ${exec_prefix}/lib
datarootdir     = ${prefix}/share
datadir         = ${datarootdir}
infodir         = ${datarootdir}/info
mandir          = ${datarootdir}/man
sysconfdir      = ${prefix}/etc
includedir      = ${prefix}/include/wine
dlldir          = ${exec_prefix}/lib/wine
prog_manext     = 1
api_manext      = 3w
conf_manext     = 5
CLEAN_FILES     = *.o *.a *.so *.ln *.$(LIBEXT) \\\#*\\\# *~ *% .\\\#* *.bak *.orig *.rej \
                  *.flc *.res *.mc.rc *.tab.[ch] *.yy.c core

OBJS = $(C_SRCS:.c=.o) $(BISON_SRCS:.y=.tab.o) $(LEX_SRCS:.l=.yy.o) $(EXTRA_OBJS)

RCOBJS = $(RC_SRCS:.rc=.res.o)
LINTS  = $(C_SRCS:.c=.ln)

# Implicit rules

.SUFFIXES: .mc .rc .mc.rc .res .res.o .spec .spec.o .idl .tlb .h .y .l .tab.c .tab.h .yy.c .ok .sfd .ttf .man.in .man _c.c _i.c _p.c _s.c

.c.o:
	$(CC) -c $(ALLCFLAGS) -o $@ $<

.s.o:
	$(AS) -o $@ $<

.y.tab.c:
	$(BISON) $(BISONFLAGS) -p $*_ -o $@ $<

.y.tab.h:
	$(BISON) $(BISONFLAGS) -p $*_ -o $*.tab.c -d $<

.l.yy.c:
	$(LEX) $(LEXFLAGS) -t $< >$@ || ($(RM) $@ && exit 1)

.mc.mc.rc:
	$(LDPATH) $(WMC) -i -U -H /dev/null -o $@ $<

.rc.res:
	$(LDPATH) $(RC) $(RCFLAGS) -fo$@ $<

.res.res.o:
	$(WINDRES) -i $< -o $@

.spec.spec.o:
	$(WINEBUILD) $(WINEBUILDFLAGS) --dll -o $@ --main-module $(MODULE) --export $<

.idl.h:
	$(WIDL) $(IDLFLAGS) -h -H $@ $<

.idl_c.c:
	$(WIDL) $(IDLFLAGS) -c -C $@ $<

.idl_i.c:
	$(WIDL) $(IDLFLAGS) -u -U $@ $<

.idl_p.c:
	$(WIDL) $(IDLFLAGS) -p -P $@ $<

.idl_s.c:
	$(WIDL) $(IDLFLAGS) -s -S $@ $<

.idl.tlb:
	$(WIDL) $(IDLFLAGS) -t -T $@ $<

.c.ln:
	$(LINT) -c $(ALLLINTFLAGS) $< || ( $(RM) $@ && exit 1 )

.c.ok:
	$(RUNTEST) $(RUNTESTFLAGS) $< && touch $@

.sfd.ttf:
	$(FONTFORGE) -script $(TOPSRCDIR)/fonts/genttf.ff $< $@

.man.in.man:
	sed -e 's,@bindir\@,$(bindir),g' -e 's,@dlldir\@,$(dlldir),g' -e 's,@PACKAGE_STRING\@,Wine 0.9.21,g' $< >$@ || ($(RM) $@ && false)

# 'all' target first in case the enclosing Makefile didn't define any target

all:

filter: dummy
	@$(TOPSRCDIR)/tools/winapi/make_filter --make $(MAKE) all

.PHONY: all filter

# Rules for resources

$(RC_BINARIES): $(BIN2RES) $(RC_BINSRC)
	$(BIN2RES) -f -o $@ $(SRCDIR)/$(RC_BINSRC)

$(RC_SRCS:.rc=.res) $(RC_SRCS16:.rc=.res): $(WRC) $(RC_BINARIES) $(IDL_TLB_SRCS:.idl=.tlb)

# Rule for linting

$(MODULE).ln : $(LINTS)
	if test "$(LINTS)" ; \
	then \
		$(LINT) $(ALLLINTFLAGS) -o$(MODULE) $(LINTS) ; \
	        $(MV) llib-l$(MODULE).ln $(MODULE).ln ; \
	else \
		$(LINT) $(ALLLINTFLAGS) -C$(MODULE) /dev/null ; \
	fi

lint:: $(MODULE).ln

# Rules for Windows API checking

winapi_check:: dummy
	$(WINAPI_CHECK) $(WINAPI_CHECK_FLAGS) $(WINAPI_CHECK_EXTRA_FLAGS) .

.PHONY: winapi_check

# Rules for dependencies

DEPEND_SRCS = $(C_SRCS) $(C_SRCS16) $(RC_SRCS) $(RC_SRCS16) $(MC_SRCS) $(IDL_SRCS) $(BISON_SRCS) $(LEX_SRCS) $(EXTRA_SRCS)

$(SUBDIRS:%=%/__depend__): dummy
	@cd `dirname $@` && $(MAKE) depend

depend: $(SUBDIRS:%=%/__depend__) dummy
	$(MAKEDEP) -C$(SRCDIR) -S$(TOPSRCDIR) -T$(TOPOBJDIR) $(EXTRAINCL) $(DEPEND_SRCS)

.PHONY: depend $(SUBDIRS:%=%/__depend__)

# Rules for cleaning

$(SUBDIRS:%=%/__clean__): dummy
	@cd `dirname $@` && $(MAKE) clean

$(EXTRASUBDIRS:%=%/__clean__): dummy
	-cd `dirname $@` && $(RM) $(CLEAN_FILES)

clean:: $(SUBDIRS:%=%/__clean__) $(EXTRASUBDIRS:%=%/__clean__)
	$(RM) $(CLEAN_FILES) $(IDL_SRCS:.idl=.h) $(IDL_SRCS:.idl=_c.c) $(IDL_SRCS:.idl=_i.c) $(IDL_SRCS:.idl=_p.c) $(IDL_SRCS:.idl=_s.c) $(IDL_TLB_SRCS:.idl=.tlb) $(PROGRAMS) $(RC_BINARIES) $(MANPAGES)

.PHONY: clean $(SUBDIRS:%=%/__clean__) $(EXTRASUBDIRS:%=%/__clean__)

# Rules for installing

$(SUBDIRS:%=%/__install__): dummy
	@cd `dirname $@` && $(MAKE) install

$(SUBDIRS:%=%/__install-lib__): dummy
	@cd `dirname $@` && $(MAKE) install-lib

$(SUBDIRS:%=%/__install-dev__): dummy
	@cd `dirname $@` && $(MAKE) install-dev

$(SUBDIRS:%=%/__uninstall__): dummy
	@cd `dirname $@` && $(MAKE) uninstall

install:: $(INSTALLSUBDIRS:%=%/__install__)

uninstall:: $(INSTALLSUBDIRS:%=%/__uninstall__)

$(INSTALLDIRS):
	$(MKINSTALLDIRS) $@

.PHONY: install install-lib install-dev uninstall \
	$(SUBDIRS:%=%/__install__) $(SUBDIRS:%=%/__uninstall__) \
	$(SUBDIRS:%=%/__install-lib__) $(SUBDIRS:%=%/__install-dev__)

# Rules for testing

$(TESTSUBDIRS:%=%/__test__): dummy
	@cd `dirname $@` && $(MAKE) test

$(TESTSUBDIRS:%=%/__crosstest__): dummy
	@cd `dirname $@` && $(MAKE) crosstest

$(TESTSUBDIRS:%=%/__testclean__): dummy
	@cd `dirname $@` && $(MAKE) testclean

check test:: $(TESTSUBDIRS:%=%/__test__)

crosstest:: $(TESTSUBDIRS:%=%/__crosstest__)

testclean:: $(TESTSUBDIRS:%=%/__testclean__)

.PHONY: check test testclean crosstest $(TESTSUBDIRS:%=%/__test__) $(TESTSUBDIRS:%=%/__crosstest__) $(TESTSUBDIRS:%=%/__testclean__) 

# Rules for auto documentation

$(DOCSUBDIRS:%=%/__man__): dummy
	@cd `dirname $@` && $(MAKE) man

$(DOCSUBDIRS:%=%/__doc_html__): dummy
	@cd `dirname $@` && $(MAKE) doc-html

$(DOCSUBDIRS:%=%/__doc_sgml__): dummy
	@cd `dirname $@` && $(MAKE) doc-sgml

man: $(DOCSUBDIRS:%=%/__man__)
doc-html: $(DOCSUBDIRS:%=%/__doc_html__)
doc-sgml: $(DOCSUBDIRS:%=%/__doc_sgml__)

.PHONY: man doc-html doc-sgml $(DOCSUBDIRS:%=%/__man__) $(DOCSUBDIRS:%=%/__doc_html__) $(DOCSUBDIRS:%=%/__doc_sgml__)

# Misc. rules

$(MC_SRCS:.mc=.mc.rc): $(WMC)

$(IDL_SRCS:.idl=.h): $(WIDL)

$(IDL_SRCS:.idl=_c.c): $(WIDL)
$(IDL_SRCS:.idl=_i.c): $(WIDL)
$(IDL_SRCS:.idl=_p.c): $(WIDL)
$(IDL_SRCS:.idl=_s.c): $(WIDL)

$(IDL_TLB_SRCS:.idl=.tlb): $(WIDL)

$(SUBDIRS): dummy
	@cd $@ && $(MAKE)

dummy:

.PHONY: dummy $(SUBDIRS)

# End of global rules

all: $(MODULE)$(DLLEXT) $(BASEMODULE)$(EXEEXT)

# Rules for .so main module

$(MODULE).so: $(OBJS) $(RC_SRCS:.rc=.res)
	$(WINEGCC) -B$(TOOLSDIR)/tools/winebuild $(APPMODE) $(OBJS) $(RC_SRCS:.rc=.res) -o $@ $(ALL_LIBS) $(DELAYIMPORTS:%=-Wb,-d%)

$(BASEMODULE): $(WINEWRAPPER)
	$(RM) $@ && $(LN_S) $(WINEWRAPPER) $@

# Rules for .exe main module

$(MODULE): $(OBJS) $(RCOBJS)
	$(CC) $(APPMODE) $(OBJS) $(RCOBJS) -o $@ $(LIBWINE) $(ALL_LIBS)

# Rules for testing

check test:: $(SUBDIRS:%=%/__test__)

$(TESTRESULTS): $(MODULE)$(DLLEXT)

# Rules for installation

.PHONY: install_prog install_prog.so uninstall_prog uninstall_prog.so

install_prog.so: $(MODULE).so $(DESTDIR)$(dlldir) dummy
	$(INSTALL_PROGRAM) $(MODULE).so $(DESTDIR)$(dlldir)/$(MODULE).so

install_prog: $(MODULE) $(DESTDIR)$(bindir) dummy
	$(INSTALL_PROGRAM) $(MODULE) $(DESTDIR)$(bindir)/$(MODULE)

uninstall_prog.so: dummy
	$(RM) $(DESTDIR)$(dlldir)/$(MODULE).so

uninstall_prog: dummy
	$(RM) $(DESTDIR)$(bindir)/$(MODULE)

install:: install_prog$(DLLEXT)

uninstall:: uninstall_prog$(DLLEXT)

clean::
	$(RM) $(BASEMODULE) $(MODULE)

all: $(MANPAGES)

install:: $(MANPAGES) $(DESTDIR)$(mandir)/man$(prog_manext)
	$(INSTALL_DATA) winedbg.man $(DESTDIR)$(mandir)/man$(prog_manext)/winedbg.$(prog_manext)

uninstall::
	$(RM) $(DESTDIR)$(mandir)/man$(prog_manext)/winedbg.$(prog_manext)

parse.tab.c: parse.tab.h   # for parallel makes

### Dependencies:
wdbgtest.o: wdbgtest.c
parse.tab.o: parse.tab.c wdbgtest.h test_cl.h \
 /home/eric/wine-git/include/windef.h \
 /home/eric/wine-git/include/winnt.h \
 /home/eric/wine-git/include/basetsd.h \
 /home/eric/wine-git/include/pshpack2.h \
 /home/eric/wine-git/include/poppack.h \
 /home/eric/wine-git/include/pshpack4.h \
 /home/eric/wine-git/include/guiddef.h \
 /home/eric/wine-git/include/pshpack8.h \
 /home/eric/wine-git/include/winbase.h \
 /home/eric/wine-git/include/winerror.h \
 /home/eric/wine-git/include/winuser.h \
 /home/eric/wine-git/include/wine/test.h
token.yy.o: token.yy.c parse.tab.h

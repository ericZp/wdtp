dnl Macros used to build the WDTP tool
dnl
dnl Copyright 2009 Eric Pouech
dnl
dnl This library is free software; you can redistribute it and/or
dnl modify it under the terms of the GNU Lesser General Public
dnl License as published by the Free Software Foundation; either
dnl version 2.1 of the License, or (at your option) any later version.
dnl
dnl This library is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl Lesser General Public License for more details.
dnl
dnl You should have received a copy of the GNU Lesser General Public
dnl License along with this library; if not, write to the Free Software
dnl Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
dnl
dnl As a special exception to the GNU Lesser General Public License,
dnl if you distribute this file as part of a program that contains a
dnl configuration script generated by Autoconf, you may include it
dnl under the same distribution terms that you use for the rest of
dnl that program.

dnl **** Add a new compiler to the known set ****
dnl
dnl Usage: WDTP_ADD_COMPILER(compiler-name, path-to-compiler, deps, cmd1, cmd2)
dnl
AC_DEFUN([WDTP_ADD_COMPILER],[
AS_IF([test "x$2" != "x"],[
	wdtp_compilers="$wdtp_compilers $1"
	AS_VAR_SET(wdtp_deps_$1, "$3")
	AS_VAR_SET(wdtp_cmd1_$1, "$4")
	AS_VAR_SET(wdtp_cmd2_$1, "$5")
	full_test="$full_test test_$1"
	AC_SUBST(WDTP_LIST_TESTS, $full_test)
	])dnl
])

dnl **** Define a flavor for a known compiler ****
dnl
dnl Usage: WDTP_DEFINE_FLAVOR(compiler-name, flavor-name, flavor-condition, flavor-options, native)
dnl
AC_DEFUN([WDTP_DEFINE_FLAVOR],[
tmp=AS_VAR_GET(wdtp_cmd1_$1)
AS_IF([test "x${tmp}" != "x"],[
	AS_VAR_SET(wdtp_flavors_$1, "AS_VAR_GET(wdtp_flavors_$1) $2")
	AS_VAR_SET(wdtp_condition_$1_$2, "$3")
	AS_IF([test "x$5" = "xtrue"],[dllext=""],[dllext="\$(DLLEXT)"])
	AS_VAR_SET(wdtp_target_$1_$2, "wdtp_$1_$2.exe${dllext}")
	target=AS_VAR_GET(wdtp_target_$1_$2)
	full_target="$full_target ${target}"
	AC_SUBST(WDTP_LIST_TARGETS, $full_target)
	deps=AS_VAR_GET(wdtp_deps_$1)
	cmd1=AS_VAR_GET(wdtp_cmd1_$1)
	cmd2=AS_VAR_GET(wdtp_cmd2_$1)
	full_cmds="$full_cmds
${target}: ${deps}
	${cmd1} $4 ${cmd2}
"
	])dnl
])

dnl **** Finish generation of WDTP information ****
dnl
dnl Usage: WDTP_FINISH
dnl
AC_DEFUN([WDTP_FINISH],[
for compiler in $wdtp_compilers; do
	test_flavors="test_${compiler}:"
	for flavor in AS_VAR_GET(wdtp_flavors_${compiler}); do
		test_flavors="$test_flavors test_${compiler}_${flavor}"
		condition=AS_VAR_GET(wdtp_condition_${compiler}_${flavor})
		target=AS_VAR_GET(wdtp_target_${compiler}_${flavor})
		full_string="$full_string
test_${compiler}_${flavor}: all ${target}
	for i in \$(WDTPS); do ./wdbgtest.run --condition ${condition} --flavor ${target} \$\$i; done
"
	done
full_string="$full_string
$test_flavors
"
done
full_string="$full_cmds
$full_string
"
AC_SUBST(WDTP_INCLUDE_TESTS, $full_string)
])

dnl Local Variables:
dnl compile-command: "autoreconf --warnings=all"
dnl End:

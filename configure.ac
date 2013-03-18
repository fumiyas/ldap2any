## ldap2any configure.in
## ======================================================================

AC_PREREQ(2.50)

AC_INIT(ldap2any, 0.1.0)

AC_PREFIX_DEFAULT(/usr/local/ldap2any)

#AC_PROG_INSTALL

package_subdir="$PACKAGE_NAME"
PERL_VERSION=5.008000

AC_CONFIG_FILES(
    Makefile
    build/Makefile.common
    build/Makefile.package
    build/Makefile.top
    build/subst.pl
    build/subst.vars
)

## Installation directories
## ======================================================================

AC_SUBST(package_subdir)

AC_ARG_WITH(
  subdir,
  [AC_HELP_STRING(--with-subdir=DIR,
    [change default subdirectory used for installs])],
  [package_subdir="$withval"],
)

case "$package_subdir" in
yes|no|"")
    package_subdir=""
    ;;
*)
    AC_MSG_RESULT([using $package_subdir for install subdir])
    package_subdir="/$package_subdir"
    ;;
esac

## Perl
## ======================================================================

AC_SUBST(PERL_COMMAND)

AC_ARG_WITH(
    perl,
    [AC_HELP_STRING(--with-perl=PATH, [Use specific perl command])],
    [PERL_COMMAND="$withval"],
)

case "$PERL_COMMAND" in
/*)
    ;;
*)
    AC_PATH_PROG(PERL_COMMAND, perl)
    ;;
esac

AC_MSG_RESULT([using $PERL_COMMAND for perl command])

## ----------------------------------------------------------------------

AC_MSG_CHECKING(for Perl version)

if test x`"$PERL_COMMAND" -e "use $PERL_VERSION; print 'ok'"` = x"ok"; then
    AC_MSG_RESULT($PERL_VERSION or later)
else
    AC_MSG_ERROR(Perl $PERL_VERSION or later required.)
fi

## Output
## ======================================================================

AC_OUTPUT


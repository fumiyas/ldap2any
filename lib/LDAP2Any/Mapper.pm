##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Mapper;

use strict;
use warnings;

my $MAPPER_BY_NAME = {};

sub Register
{
  my ($class, $name, $mapper) = @_;

  $MAPPER_BY_NAME->{$name} = $mapper;
}

sub Names
{
  return keys %$MAPPER_BY_NAME;
}

sub create
{
  my $class = shift(@_);
  my $name = shift(@_);

  return $MAPPER_BY_NAME->{$name}->new(@_);
}

return 1;


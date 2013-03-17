##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Entry;

use strict;
use warnings;

use base qw(Net::LDAP::Entry);

our $UUIDAttribute = 'X-UUID';

sub new
{
  my $class = shift(@_);
  my $dn_or_lentry = shift(@_);

  my $self = (ref($dn_or_lentry) eq "Net::LDAP::Entry")
    ? bless $dn_or_lentry, $class
    : $class->SUPER::new($dn_or_lentry, @_);

  return $self;
}

sub uuid
{
  my ($self, $uuid) = @_;

  if ($uuid) {
    $self->add($UUIDAttribute => $uuid);
    return $self;
  }

  $uuid = $self->value($UUIDAttribute);

  return $uuid;
}

sub value
{
    my ($self, $name) = @_;

    return $self->get_value($name);
}

return 1;


##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Mapper::group;

use base qw(LDAP2Any::Mapper::TextFile);

use strict;
use warnings;
use constant true => 1;
use constant false => 0;

my $NAME = 'group';

sub new
{
  my ($class, %opts_in) = @_;

  my %opts = (
    'objectclass' =>		delete($opts_in{'objectclass'}) || 'posixGroup',
    ## Attribute mapping
    'mappings' => {
      'name' => {
        'index' =>		0,
        'attribute' =>		delete($opts_in{'name_attribute'}) || 'cn',
      },
      'password' => {
        'index' =>		1,
        'attribute' =>		delete($opts_in{'password_attribute'}) || 'userPassword',
        'default_value' =>	delete($opts_in{'password_default_value'}) || '*',
        'transform_value' =>	sub {
          $_[0] = ($_[0] =~ /^\{CRYPT\}(.*)$/i) ? $1 : undef;
        },
      },
      'gid' => {
        'index' =>		2,
        'attribute' =>		delete($opts_in{'gid_attribute'}) || 'gidNumber',
        'min_value' =>		delete($opts_in{'gid_min'}) || undef,
        'max_value' =>		delete($opts_in{'gid_max'}) || undef,
      },
      'members' => {
        'index' =>		3,
        'attribute' =>		delete($opts_in{'members_attribute'}) || 'memberUid',
        'default_value' =>	[],
        'has_many' =>	        true,
      },
    },
  );

  my $self = $class->SUPER::new($NAME, %opts_in, %opts);

  return $self;
}

LDAP2Any::Mapper->Register($NAME, __PACKAGE__);

return 1;


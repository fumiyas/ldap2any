##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Mapper::passwd;

use base qw(LDAP2Any::Mapper::TextFile);

use strict;
use warnings;
use constant true => 1;
use constant false => 0;

our $NAME = 'passwd';

sub new
{
    my ($class, %opts_in) = @_;

    my %opts = (
      'objectclass' =>			'posixAccount',
      ## Attributes
      'mappings' => {
	'name' => {
	  'index' =>		0,
	  'attribute' =>	delete($opts_in{'name_attribute'}) || 'cn',
	},
	'password' => {
	  'index' =>		1,
	  'attribute' =>	delete($opts_in{'password_attribute'}) || 'userPassword',
	  'default_value' =>	delete($opts_in{'password_default_value'}) || '*',
	  'transform_value' => sub {
	    $_[0] = ($_[0] =~ /^\{CRYPT\}(.*)$/i) ? $1 : undef;
	  },
	},
	'uid' => {
	  'index' =>		2,
	  'attribute' =>	delete($opts_in{'uid_attribute'}) || 'uidNumber',
	  'min_value' =>	delete($opts_in{'uid_min'}) || undef,
	  'max_value' =>	delete($opts_in{'uid_max'}) || undef,
	},
	'gid' => {
	  'index' =>		3,
	  'attribute' =>	delete($opts_in{'gid_attribute'}) || 'gidNumber',
	  'min_value' =>	delete($opts_in{'gid_min'}) || undef,
	  'max_value' =>	delete($opts_in{'gid_max'}) || undef,
	},
	'gecos' => {
	  'index' =>		4,
	  'attribute' =>	delete($opts_in{'gecos_attribute'}) || 'gecos',
	  'default_value' =>	delete($opts_in{'gecos_default_value'}) || ''
	},
	'home_directory' => {
	  'index' =>		5,
	  'attribute' =>	delete($opts_in{'home_directory_attribute'}) || 'homeDirectory',
	  'default_value' =>	delete($opts_in{'home_directory_default_value'}) || ''
	},
	'login_shell' => {
	  'index' =>		6,
	  'attribute' =>	delete($opts_in{'login_shell_attribute'}) || 'loginShell',
	  'default_value' =>	delete($opts_in{'login_shell_default_value'}) || '/bin/false'
	},
      },
      ## Other options
      'password_locked_value' =>	'!',
      'password_locked_by_samba' =>	false,
    );

    my $self = $class->SUPER::new($NAME, %opts, %opts_in);

    return $self;
}

LDAP2Any::Mapper->Register($NAME, __PACKAGE__);

return 1;


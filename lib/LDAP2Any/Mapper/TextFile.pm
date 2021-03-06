##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Mapper::TextFile;

use base qw(LDAP2Any::Mapper::Base);

use strict;
use warnings;
use constant true => 1;
use constant false => 0;
use English qw(-no_match_vars);
use IO::File;

sub new
{
  my ($class, $name, %opts) = @_;

  my $self = $class->SUPER::new($name, %opts);

  $self->parse_known_option('output_file', $self->name);
  $self->parse_known_option('header', '');
  $self->parse_known_option('footer', '');
  $self->parse_known_option('entry_prefix', '');
  $self->parse_known_option('entry_suffix', "\n");
  $self->parse_known_option('value_separator', ':');

  for my $mapping (values %{$self->{'mappings'}}) {
    $mapping->{'value_separator'} = ',' unless defined($mapping->{'value_separator'});
  }

  return $self;
}

sub map
{
  my ($self, $entry_in) = @_;

  my $entry = $self->SUPER::map($entry_in);
  unless (defined($entry)) {
    return undef;
  }

  my @values = ();
  while (my ($name, $mapping) = each(%{$self->{'mappings'}})) {
    my @value = $entry->value($name);
    my $value = ($mapping->{'has_many'})
      ? join($mapping->{'value_separator'}, @value)
      : $value[0];

    if (defined(my $index = $mapping->{'index'})) {
      $values[$index] =  $value;
    }
    else {
      push(@values, $value);
    }
  }

  return join($self->{'value_separator'}, @values);
}

sub commit
{
  my ($self) = @_;

  my $file = $self->{'output_file'};
  my $file_tmp = "$file.$$.l2a.tmp";
  my $file_fh = IO::File->new($file_tmp, O_CREAT|O_WRONLY, 0600)
    || die "Cannot open file: $file_tmp: $!\n";

  eval {
    $file_fh->print($self->{'header'}) ||
      die "Cannot write to file: $file_tmp: $!\n";

    for my $dn (sort $self->entries_dn) {
      my $entry = $self->entry_by_dn($dn);
      $file_fh->print(
	$self->{'entry_prefix'},
	$entry,
	$self->{'entry_suffix'}
      ) || die "Cannot write to file: $file_tmp: $!\n";
    }

    $file_fh->print($self->{'footer'}) ||
      die "Cannot write to file: $file_tmp: $!\n";
    $file_fh->close;

    unless (rename($file_tmp, $file)) {
      die "Cannot rename file: $file_tmp: $!\n";
    }
  };

  if ($EVAL_ERROR) {
    unlink($file_tmp);
    die $EVAL_ERROR;
  }

  return true;
}

return 1;


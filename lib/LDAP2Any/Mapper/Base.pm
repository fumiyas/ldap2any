##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
##

package LDAP2Any::Mapper::Base;

use strict;
use warnings;
use constant true => 1;
use constant false => 0;

use LDAP2Any::Entry;

sub new
{
  my ($class, $name, %opts) = @_;

  my $self = bless {
    'name' =>		$name,
    'objectclass' =>	delete($opts{'objectclass'}),
    'mappings' =>	delete($opts{'mappings'}) || {},
    'entry_by_ndn' =>	{}, ## Entry by a normalized DN
    'ndn_by_uuid' =>	{}, ## Normalized DN by an UUID
    'unknown_opts' =>	{},
  }, $class;

  $self->unknown_options(%opts);

  for my $mapping (values %{$self->{'mappings'}}) {
    my $filters = $mapping->{'value_filters'} ||= [];
    if (defined(my $min = $mapping->{'min_value'})) {
      push(@$filters, sub { grep { $_ >= $min } @_; });
    }
    if (defined(my $max = $mapping->{'max_value'})) {
      push(@$filters, sub { grep { $_ <= $max } @_; });
    }
    if (defined(my $match = $mapping->{'match_value'})) {
      push(@$filters, sub { grep { $_ =~ $match } @_; });
    }
    if (defined(my $unmatch = $mapping->{'unmatch_value'})) {
      push(@$filters, sub { grep { $_ !~ $unmatch } @_; });
    }
    if (defined(my $transform = $mapping->{'transform_value'})) {
      push(@$filters, sub {
	for my $value (@_) {
	    $value = $transform->($value);
	};
	return @_;
      });
    }
  }

  return $self;
}

sub name
{
  my ($self) = @_;

  return $self->{'name'};
}

sub unknown_options
{
  my $self = shift(@_);

  if (@_ == 1) {
    return delete($self->{'unknown_opts'}->{$_[0]});
  }
  elsif (@_ >= 2) {
    $self->{'unknown_opts'} = { %{$self->{'unknown_opts'}}, @_ };
  }

  return %{$self->{'unknown_opts'}};
}

sub parse_known_option
{
  my ($self, $pname, $pvalue_default, $parser) = @_;

  my $pvalue_raw = $self->unknown_options($pname);
  if (!defined($pvalue_raw)) {
    $self->{$pname} = $pvalue_default;
    return;
  }

  $self->{$pname} = defined($parser) ? $parser->($pvalue_raw) : $pvalue_raw;
}

sub objectclass
{
  my ($self) = @_;

  return $self->{'objectclass'};
}

sub map
{
  my ($self, $entry_in) = @_;

  my $entry = LDAP2Any::Entry->new($entry_in->dn);

  while (my ($name, $mapping) = each(%{$self->{'mappings'}})) {
    my $attribute = $mapping->{'attribute'} || $name;
    my @value = $entry_in->value($attribute);

    for my $filter (@{$self->{'mappings'}->{$name}->{'value_filters'}}) {
      @value = grep { defined } $filter->(@value);
      last unless (@value);
    }

    unless (@value) {
      if (defined(my $default_value = $mapping->{'default_value'})) {
	@value = ref($default_value) ? @$default_value : ($default_value);
      }
      else {
	unless ($mapping->{'can_null'}) {
	  return undef;
	}
      }
    }

    if (@value) {
      $entry->add($name => $mapping->{'has_many'} ? \@value : $value[0]);
    }
  }

  return $entry;
}

sub entries_dn
{
  my ($self) = @_;

  return keys(%{$self->{'entry_by_ndn'}});
}

sub entry_by_dn
{
  my ($self, $dn) = @_;
  my $ndn = Unicode::Normalize::NFKC($dn);

  my $entry = $self->{'entry_by_ndn'}->{$ndn};

  if (@_ == 3) {
    my $entry_new = $_[2];
    if (defined($entry_new)) {
      $self->{'entry_by_ndn'}->{$ndn} = $entry_new;
    }
    else {
      delete($self->{'entry_by_ndn'}->{$ndn});
    }
  }

  return $entry;
}

sub dn_by_uuid
{
  my ($self, $uuid) = @_;

  my $ndn = $self->{'ndn_by_uuid'}->{$uuid};

  if (@_ == 3) {
    my $dn_new = $_[2];
    if (defined($dn_new)) {
      my $ndn_new = Unicode::Normalize::NFKC($dn_new);
      if (defined($ndn) && $ndn_new eq $ndn) {
	return undef;
      }
      $self->{'ndn_by_uuid'}->{$uuid} = $ndn_new;
    }
    else {
      delete($self->{'ndn_by_uuid'}->{$uuid});
    }
  }

  return $ndn;
}

sub clear_entries
{
  my ($self) = @_;

  $self->{'entry_by_ndn'} = {};
  $self->{'ndn_by_uuid'} = {};
}

sub add_entry
{
  my ($self, $entry_in) = @_;
  my $dn = $entry_in->dn;
  my $uuid = $entry_in->uuid;

  my $oc = lc($self->objectclass);
  unless (grep {lc($_) eq $oc} $entry_in->value('objectClass')) {
    return undef;
  }

  my $entry = $self->map($entry_in);

  unless (defined($entry)) {
    ## Filtered
    return undef;
  }

  $self->entry_by_dn($dn, $entry);
  $self->dn_by_uuid($uuid, $dn);

  return $entry;
}

sub modify_entry
{
  my ($self, $entry_in) = @_;
  my $dn = $entry_in->dn;
  my $uuid = $entry_in->uuid;

  my $oc = lc($self->objectclass);
  unless (grep {lc($_) eq $oc} $entry_in->value('objectClass')) {
    return $self->delete_entry($entry_in);
  }

  my $entry = $self->map($entry_in);

  unless (defined($entry)) {
    ## Filtered
    return $self->delete_entry($entry_in);
  }

  $self->entry_by_dn($dn, $entry);
  my $dn_old = $self->dn_by_uuid($uuid, $dn);
  if (defined($dn_old)) {
    $self->entry_by_dn($dn_old, undef);
  }

  return $entry;
}

sub delete_entry
{
  my ($self, $entry_in) = @_;
  my $dn = $entry_in->dn;
  my $uuid = $entry_in->uuid;

  $self->entry_by_dn($dn, undef);
  $self->dn_by_uuid($uuid, undef);
}

sub commit
{
  return true;
}

return 1;


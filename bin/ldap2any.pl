#!@PERL_COMMAND@
##
## LDAP to ANY gateway
## Copyright (c) 2009-2013 SATOH Fumiyasu @ OSS Technology Corp., Japan
##               <https://www.GitHub.com/fumiyas>
##               <http://www.OSSTech.co.jp/>
##
## License: GNU General Public License version 3
## Date: 2013-03-21, since 2009-08-21

use 5.008;
use strict;
use warnings;
use constant true => 1;
use constant false => 0;

use lib '@libmoduledir@/perl5';
use LDAP2Any::Mapper;

use English qw(-no_match_vars);
use Switch;
use Getopt::Long;
use IO::File;
use Unicode::Normalize;
use Net::LDAP;
use Net::LDAP::Control::SyncRequest;
use Net::LDAP::Constant qw(
  LDAP_SYNC_REFRESH_AND_PERSIST
  LDAP_SUCCESS
  LDAP_SYNC_ADD
  LDAP_SYNC_MODIFY
  LDAP_SYNC_DELETE
);

sub perr
{
  print STDOUT "$0: ERROR: $_[0]\n";
}

sub pdie
{
  perr($_[0]);
  exit(1);
}

## ======================================================================

my $config_file = undef;
my $mapper_dir = $ENV{'LDAP2ANY_MAPPER_DIR'} || '@libmoduledir@/mapper';
my %mapper_options = ();

my $ldap_debug_level = 0;
my $ldap_ver = 3;
my $ldap_attr_x_entryuuid = 'X-entryUUID';

my $ldap_uri = 'ldap://127.0.0.1';
my $connect_timeout = 60;
my $reconnect = true;
my $reconnect_interval = 10;
my $resync_on_reconnect = false;
my $bind_dn = undef;
my $bind_pass = undef;
my $search_base = '';
my $search_scope = 'sub';
my $search_filter = undef;
my @search_attrs = qw(*);

## ----------------------------------------------------------------------

{
  ## Trap warning messages from Getopt::Long
  local($SIG{'__WARN__'}) = sub {
    my ($msg) = shift(@_);
    chomp($msg);
    STDERR->print("$0: ERROR: \l$msg\n");
  };
  ## I don't like default behavior.
  Getopt::Long::Configure('bundling');
  Getopt::Long::Configure('no_ignore_case');
  Getopt::Long::Configure('no_auto_abbrev');
  GetOptions(
    'c|config-file=s' =>	\$config_file,
  ) || pdie "Invalid command-line option";
}

sub parse_bool
{
  return ($_[0] =~ /^(yes|true|enable|on)$/i) ? true : false;
}

if (defined($config_file)) {
  my $config_fh = IO::File->new($config_file)
    || pdie "Cannot open configuration file: $config_file: $!";

  while (!$config_fh->eof) {
    chomp(my $line = $config_fh->getline);
    next if ($line =~ /^(?:#.*$)?$/); ## Empty or comment line

    unless ($line =~ /^\s*([^=]+?)\s*=\s*(.*?)\s*$/) {
      pdie "Invalid configuration: $line";
    }
    my $pname = $1; my $pvalue = $2;
    $pname =~ s/[- ]/_/g;

    switch ($pname) {
      case 'ldap_debug_level'	{ $ldap_debug_level = $pvalue; }
      case 'ldap_connect_timeout'
				{ $connect_timeout = $pvalue; }
      case 'ldap_reconnect'	{ $reconnect = parse_bool($pvalue); }
      case 'ldap_reconnect_interval'
				{ $reconnect_interval = $pvalue; }
      case 'ldap_resync_on_reconnect'
				{ $resync_on_reconnect = parse_bool($pvalue); }
      case 'ldap_uri'		{ $ldap_uri = $pvalue; }
      case 'ldap_bind_dn'	{ $bind_dn = $pvalue; }
      case 'ldap_bind_password'	{ $bind_pass = $pvalue; }
      case 'ldap_search_base'	{ $search_base = $pvalue; }
      case 'ldap_search_scope'	{ $search_scope = $pvalue; }
      case 'ldap_search_filter'	{ $search_filter = $pvalue; }
      case /^\w+:/ {
	$pname =~ s/^(\w+?)_*:_*//;
	$mapper_options{$1}->{$pname} = $pvalue;
      }
      else {
	pdie "Unknown option in line ".$config_fh->input_line_number.": $pname";
      }
    }
  }
}

$ldap_uri = shift(@ARGV) if (@ARGV);
$search_base = shift(@ARGV) if (@ARGV);
$search_filter = shift(@ARGV) if (@ARGV);

## ======================================================================

for my $mapper_pm (glob("$mapper_dir/*.pm")) {
  eval { require $mapper_pm; };
  pdie "Cannot load mapper module: $EVAL_ERROR" if ($EVAL_ERROR);
}

my @mappers = ();
my @mapper_filters = ();
for my $mapper_name (LDAP2Any::Mapper->Names) {
  my $mapper_options = $mapper_options{$mapper_name} || {};
  my $mapper = LDAP2Any::Mapper->create($mapper_name, %$mapper_options);
  if (my %unknown_opts = $mapper->unknown_options) {
    for my $pname (keys %unknown_opts) {
      perr "Unknown option for mapper: $mapper_name: $pname";
    }
    exit(1);
  }

  push(@mappers, $mapper);
  push(@mapper_filters, "(objectClass=".$mapper->objectclass.")");
}

if (@mappers == 0) {
  pdie "No mapper module found";
}

my $mapper_filter = (@mapper_filters == 1)
  ?  $mapper_filters[0]
  : "(|" . join("", @mapper_filters) . ")";

$search_filter = defined($search_filter)
  ? "(&$search_filter$mapper_filter)"
  : $mapper_filter;

## ======================================================================

my $booting = true;

my $ldap_sync = Net::LDAP::Control::SyncRequest->new(
  mode => LDAP_SYNC_REFRESH_AND_PERSIST,
  critical => true,
  cookie => undef,
);

my $ldap_sync_callback = sub {
  my $msg = shift;
  my $obj = shift; ## Net::LDAP::Entry or Net::LDAP::Intermediate
  my @controls = $msg->control;

  my %mappers_updated = ();

  if (defined($obj) && $obj->isa('Net::LDAP::Entry')) {
    my $syncstate = undef;
    for my $control (@controls) {
      if ($control->isa('Net::LDAP::Control::SyncState')) {
	$syncstate = $control;
	last;
      }
    }

    unless (defined($syncstate)) {
      pdie "LDAP entry without Sync State control";
    }

    my $op_method = undef;
    my $op_name = 'UNKNOWN';
    switch ($syncstate->state) {
      case LDAP_SYNC_ADD {
	$op_method = 'add_entry';
	$op_name = 'Add';
      }
      case LDAP_SYNC_MODIFY {
	$op_method = 'modify_entry';
	$op_name = 'Modify';
      }
      case LDAP_SYNC_DELETE {
	$op_method = 'delete_entry';
	$op_name = 'Delete';
      }
      else {
	pdie "Unknown Sync State: " . $syncstate->state;
      }
    }

    my $entry_in = LDAP2Any::Entry->new($obj);
    $entry_in->uuid($syncstate->entryUUID);
    #my $uuid_str = unpack('H*', $syncstate->entryUUID);

    for my $mapper (@mappers) {
      if (defined($mapper->$op_method($entry_in))) {
	$mappers_updated{$mapper} = $mapper;
	print "Entry: $op_name: ", $mapper->name, ": ", $obj->dn, "\n";
      }
    }

    if ($syncstate->cookie) {
      $ldap_sync->cookie($syncstate->cookie);
    }
  }
  elsif (defined($obj) && $obj->isa('Net::LDAP::Intermediate')) {
    if ($booting) {
      $booting = false;
      for my $mapper (@mappers) {
	$mappers_updated{$mapper} = $mapper;
      }
      print "Entry: Booted\n";
    }
    $ldap_sync->cookie($obj->{'asn'}->{'refreshDelete'}->{'cookie'});
  }
  elsif (defined($obj) && $obj->isa('Net::LDAP::Reference')) {
    return;
  }
  else {
    return;
  }

  return unless (!$booting && %mappers_updated);

  for my $mapper (values %mappers_updated) {
    $mapper->commit;
  }
};

## ----------------------------------------------------------------------

while (true) {
  print "LDAP: Connecting: $ldap_uri\n";
  my $ldap = Net::LDAP->new(
    $ldap_uri,
    'debug' =>		$ldap_debug_level,
    'version' =>	$ldap_ver,
    'timeout' =>	$connect_timeout,
  );

  unless (defined($ldap)) {
    unless ($reconnect) {
      pdie "Cannot connect to LDAP server: $ldap_uri: $@";
    }
    print "LDAP: Connect: Failed: $@\n";
    next;
  }

  if (defined($bind_dn)) {
    print "LDAP: Binding: $bind_dn\n";
    my %bind_opts = ();
    $bind_opts{'password'} = $bind_pass if (defined($bind_pass));
    my $bind_msg = $ldap->bind($bind_dn, %bind_opts);
    if ($bind_msg->code) {
      unless ($reconnect) {
	pdie "Cannot bind to LDAP server: ". $bind_msg->error;
      }
      print "LDAP: Bind: Failed: ", $bind_msg->error, "\n";
      next;
    }
  }

  print "LDAP: Search: Base: $search_base\n";
  print "LDAP: Search: Scope: $search_scope\n";
  print "LDAP: Search: Filter: $search_filter\n";
  print "LDAP: Search: Attributes: @search_attrs\n";
  my $search_msg = $ldap->search(
    base =>	$search_base,
    scope =>	$search_scope,
    control =>	[$ldap_sync],
    callback =>	$ldap_sync_callback,
    filter =>	$search_filter,
    attrs =>	\@search_attrs,
  );

  unless ($reconnect) {
    pdie "LDAP search failed: ". $search_msg->error;
  }

  print "LDAP: Search: Failed: ", $search_msg->error, "\n";
  print "LDAP: Unbinding\n";
  $ldap->unbind;
  print "LDAP: Disconnecting: $ldap_uri\n";
  $ldap->disconnect;

  if ($resync_on_reconnect) {
    $booting = true;
    $ldap_sync->cookie(undef);
    for my $mapper (@mappers) {
      $mapper->clear_entries;
    }
  }
}
continue {
  if ($reconnect_interval > 0) {
    print "LDAP: Reconnect interval: $reconnect_interval\n";
    sleep($reconnect_interval);
  }
}


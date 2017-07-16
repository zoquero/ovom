package Ovom;
use strict;
use warnings;
use Exporter;
use Cwd 'abs_path';
use File::Basename;
use POSIX qw/strftime/;

our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( updateInventory updatePerformance collectorInit collectorStop readConfiguration log );

# Functions that are exported by default:
our @EXPORT = qw( updatePerformance );

our %configuration;
our %ovomGlobals;

sub updateInventory {
  Ovom::log(1, "Let's updateInventory");

  my $dcListCommand = $configuration{'command.dcList'} .
                        " --datacenter " . $configuration{'vDataCenterName'} .
                        " --server "     . $configuration{'vCenterName'};

  open CMD,'-|', $dcListCommand or die "Can't run $dcListCommand :" . $@;
  my $hosts = 0;
  my $host  = '';
  my $vms   = 0;
  my $vm    = '';
  my $line;
  while (defined($line=<CMD>)) {
    if ( $line =~ /^Hosts found:$/ ) {
      $hosts = 1;
      $vms   = 0;
    }
    elsif ( $line =~ /^VM's found:$/ ) {
      $hosts = 0;
      $vms   = 1;
    }
    else {
      next if $line =~ /^\s*$/;
      $line =~ /^\d+: (.+)$/;
      if($hosts) {
        $host = $1;
        print "host = $host\n";
      }
      elsif($vms) {
        $vm = $1;
        print "vm = $vm\n";
      }
    }
  }
  close CMD;
}


sub updatePerformance {
  Ovom::log(1, "Updating performance");
}


sub collectorInit {
  readConfiguration();

  my($clf) = $Ovom::configuration{'logFolder'} . "/collector.log";
  $Ovom::ovomGlobals{'collectorLogFile'} = $clf;

  open($Ovom::ovomGlobals{'collectorLogHandle'}, ">>", $clf)
    or die "Could not open collector log file '$clf': $!";

  Ovom::log(1, "Configuration read");
}


sub collectorStop {
  Ovom::log(1, "Stopping collector");

  my($clf) = $Ovom::ovomGlobals{'collectorLogFile'};

  close($Ovom::ovomGlobals{'collectorLogHandle'})
    or die "Could not open collector log file '$clf': $!";
}


sub readConfiguration {
  my $confFile = dirname(abs_path($0)) . '/ovom.conf';
  open(CONFIG, '<:encoding(UTF-8)', $confFile)
    or die "Can't read $confFile: $!";
  while (<CONFIG>) {
      chomp;              # no newline
      s/#.*//;            # no comments
      s/^\s+//;           # no leading white
      s/\s+$//;           # no trailing white
      next unless length; # anything left?
      my ($var, $value) = split(/\s*=\s*/, $_, 2);
      $configuration{$var} = $value;
  } 
  close(CONFIG) or die "Can't close $confFile: $!";
} 


sub log ($$) {
  my ($logLevel, $msg) = @_;
  return if($Ovom::configuration{'logLevel'} gt $logLevel);

  my $nowStr = strftime('%Y%m%d_%H%M%S', gmtime);
  # gmtime instead of localtime, we want ~UTC

  print {$Ovom::ovomGlobals{'collectorLogHandle'}} "${nowStr}Z: $msg\n";
}

1;

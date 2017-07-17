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
our %inventory;
our @counterTypes = ("cpu", "mem", "net", "disk", "sys");

sub updateInventory {
  Ovom::log(1, "Updatiing inventory");

  my $dcListCommand = $configuration{'command.dcList'} .
                        " --datacenter " . $configuration{'vDataCenterName'} .
                        " --server "     . $configuration{'vCenterName'};

  open CMD,'-|', $dcListCommand or die "Can't run $dcListCommand :" . $@;
  my @hosts = ();
  my $parsingHosts = 0;
  my $host  = '';
  my @vms   = ();
  my $parsingVMs   = 0;
  my $vm    = '';
  my $line;
  while (defined($line=<CMD>)) {
    if ( $line =~ /^Hosts found:$/ ) {
      $parsingHosts = 1;
      $parsingVMs   = 0;
    }
    elsif ( $line =~ /^VM's found:$/ ) {
      $parsingHosts = 0;
      $parsingVMs   = 1;
    }
    else {
      next if $line =~ /^\s*$/;
      $line =~ /^\d+: (.+)$/;
      if($parsingHosts) {
        $host = $1;
        Ovom::log(0, "updateInventory; host discovered = $host");
        push @hosts, $host;
      }
      elsif($parsingVMs) {
        $vm = $1;
        Ovom::log(0, "updateInventory; vm discovered = $vm");
        push @vms, $vm;
      }
    }
  }
  close CMD;
  $Ovom::inventory{'hosts'} = \@hosts;
  $Ovom::inventory{'vms'}   = \@vms;

  my($aHost, $aVM, $s);
  $s = "Discovered hosts: ";
  foreach $aHost (@{$Ovom::inventory{'hosts'}}) {
    $s .= "$aHost;";
  }
  Ovom::log(0, $s);
  
  $s = "Discovered VMs: ";
  foreach $aVM (@{$Ovom::inventory{'vms'}}) {
    $s .= "$aVM;";
  }
  Ovom::log(0, $s);

  my($ch, $cv);
  $ch = $#{$Ovom::inventory{'hosts'}} + 1;
  $cv = $#{$Ovom::inventory{'vms'}}   + 1;
  Ovom::log(1, "Discovered $ch hosts and $cv VMs");
}


sub updatePerformance {
  Ovom::log(1, "Updating performance");

  my($aHost, $aVM);
  foreach $aHost (@{$Ovom::inventory{'hosts'}}) {
    
  }

}

sub getHostPerfs {
  my ($host) = shift;
  my ($counterType);
  foreach $counterType (@Ovom::counterTypes) {
    my $getHostPerfCommand = $configuration{'command.getPerf'} .
                             " --server "      . $configuration{'vCenterName'} .
                             " --countertype " . $counterType .
                             " --host "        . $host;
  
print "==== Mirem comptador $counterType de host $host: ====\n";
    open CMD,'-|', $getHostPerfCommand or die "Can't run $getHostPerfCommand :" . $@;
    my $line;
    while (defined($line=<CMD>)) {
print "    $line\n";
    }
    close CMD;
  }

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

  my $crit;
  if ($logLevel      == 0) {
    $crit = "DEBUG";
  } elsif ($logLevel == 1) {
    $crit = "INFO";
  } elsif ($logLevel == 2) {
    $crit = "WARNING";
  } elsif ($logLevel == 3) {
    $crit = "ERROR";
  } else {
    $crit = "UNKNOWN";
  }

  print {$Ovom::ovomGlobals{'collectorLogHandle'}} "${nowStr}Z: [$crit] $msg\n";
}

1;

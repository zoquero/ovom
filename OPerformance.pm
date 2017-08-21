package OPerformance;
use strict;
use warnings;

use Exporter;
use POSIX qw/strftime/;
use Time::Piece;
use Time::HiRes; ## gettimeofday
use VMware::VIRuntime;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;

our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( getLatestPerformance );

# Functions that are exported by default:
our @EXPORT = qw( getLatestPerformance );

our $csvSep = ";";

#
# Gets last performance data from hosts and VMs
#
# @return 1 ok, 0 errors
#
sub getLatestPerformance {
  my ($timeBefore, $eTime);
  OInventory::log(1, "Updating performance");

  $timeBefore=Time::HiRes::time;
  foreach my $aVM (@{$OInventory::inventory{'VirtualMachine'}}) {
    my ($timeBefore, $eTime);
    $timeBefore=Time::HiRes::time;
    if(! getVmPerfs($aVM)) {
      OInventory::log(3, "Errors getting performance from $aVM, "
                          . "moving to next");
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Update performance for VM "
                     . "(name='" . $aVM->{name} . "', mo_ref='"
                     . $aVM->{mo_ref} . "') took "
                     . sprintf("%.3f", $eTime) . " s");
  }
  foreach my $aHost (@{$OInventory::inventory{'HostSystem'}}) {
    my ($timeBefore, $eTime);
    $timeBefore=Time::HiRes::time;
    if(! getHostPerfs($aHost)) {
      OInventory::log(3, "Errors getting performance from $aHost, "
                          . "moving to next");
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Update performance for Host "
                     . "(name='" . $aHost->{name} . "', mo_ref='"
                     . $aHost->{mo_ref} . "') took "
                     . sprintf("%.3f", $eTime) . " s");
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Update the whole data performance took "
                     . sprintf("%.3f", $eTime) . " s");

  return 0;
}


#
# Gets performance metrics for a VM
#
# @param OVirtualMachine object
# @return 1 ok, 0 errors
#
sub getVmPerfs {
  return 1;
}


#
# Gets performance metrics for a Host
#
# @param OHost object
# @return 1 ok, 0 errors
#
sub getHostPerfs {
  return 1;
}


sub saveVmPerf {
}


sub saveHostPerf {
}

1;

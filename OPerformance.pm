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

sub test() {
  die "fnciona";
}

#
# Gets last performance data from hosts and VMs
#
# @return 1 ok, 0 errors
#
sub getLatestPerformance {
  OInventory::log(1, "Updating performance");

  OInventory::log(3, "The new version of getLatestPerformance is still in development ");
  return 0;

  my($aHost, $aVM);
  foreach $aVM (@{$OInventory::inventory{'VirtualMachine'}}) {
    if(getVmPerfs($aVM)) {
      OInventory::log(3, "Errors getting performance from VM $aVM, "
                          . "moving to next");
      next;
    }
  }
  foreach $aHost (@{$OInventory::inventory{'HostSystem'}}) {
    if(getHostPerfs($aHost)) {
      OInventory::log(3, "Errors getting performance from Host $aHost, "
                          . "moving to next");
      next;
    }
  }
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

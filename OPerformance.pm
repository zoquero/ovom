package OPerformance;
use strict;
use warnings;

use Exporter;
use POSIX qw/strftime/;
use Time::Piece;
use Time::HiRes; ## gettimeofday
use VMware::VIRuntime;

use OInventory;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;
use OMockView::OMockPerfCounterInfo;
use OMockView::OMockPerformanceManager;

our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( getLatestPerformance );

# Functions that are exported by default:
our @EXPORT = qw( getLatestPerformance );

our $csvSep = ";";

our $perfManagerView = undef;
our %allCounters        = ();
our %allCountersByGIKey = ();

#
# Gets and caches perfManager
#
# Vim::get_view(mo_ref => Vim::get_service_content()->perfManager)
# returns a PerformanceManager object that contains these objects:
#   * mo_ref             : its mo_ref (PerfMgr)
#   * perfCounter        : array of PerfCounterInfo objects that describe
#                          the perf counters available for that entity
#   * description        : array of ElementDescription objects specifying
#                          what does mean 'maximum', 'summary', ...
#   * vim                : vim object describing the whole infrastructure
#   * historicalInterval : array of PerfInterval objects that describe
#                          the intervals of performance data
#
# @return 1 ok, 0 errors
#
sub getPerfManager {
  if(! defined($perfManagerView)) {

    if($OInventory::configuration{'debug.mock.enabled'}) {
      OInventory::log(0, "In mocking mode. Now we should be getting "
                       . "perfManager from VIM service content...");
      $perfManagerView = OMockView::OMockPerformanceManager->new();
      return 1;
    }

    eval {
      $perfManagerView = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
    };
    if($@) {
      OInventory::log(3, "Can't get perfManager from VIM service content: $@");
      return 0;
    }
    if(! defined($perfManagerView)) {
      OInventory::log(3, "Can't get perfManager from VIM service content.");
      return 0;
    }
  }
  return 1;
} 


#
# Initiate counter info
#
# As a sample, this is the list of the different groupInfo keys
# (perfCounterInfo->groupInfo->key) of the perfCounterInfo
# objects found on the $perfManagerView->perfCounter object on a vCenter 6.5:
# * clusterServices
# * cpu
# * datastore
# * disk
# * gpu
# * hbr
# * managementAgent
# * mem
# * net
# * pmem
# * power
# * rescpu
# * storageAdapter
# * storagePath
# * sys
# * vcDebugInfo
# * vcResources
# * vflashModule
# * virtualDisk
# * vmop
# * vsanDomObj
#
# @return 1 ok, 0 errors
#
sub initCounterInfo {

  my $perfCounterInfo;

  eval {
    $perfCounterInfo = $perfManagerView->perfCounter;
  };
  if($@) {
    OInventory::log(3, "Can't get perfCounter from perfManagerView: $@");
    return 0;
  }

  foreach my $pCI (@$perfCounterInfo) {
    my $key = $pCI->key;
    $allCounters{$key} = $pCI;
    $allCountersByGIKey{$pCI->groupInfo->key} = $pCI;
  }
  return 1;
}

#
# Gets last performance data from hosts and VMs
#
# @return 1 ok, 0 errors
#
sub getLatestPerformance {
  my ($timeBefore,  $eTime);
  my ($timeBeforeB, $eTimeB);
  my $maxErrs = $OInventory::configuration{'perfpicker.max_errs'};
  my $perfManager;

  OInventory::log(0, "Updating performance");

  OInventory::log(0, "Let's get perfManager");
  $timeBefore=Time::HiRes::time;
  $perfManager=getPerfManager();
  if(! $perfManager) {
    OInventory::log(3, "Errors getting getPerfManager");
    return 0;
  }
  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Getting perfManager took "
                     . sprintf("%.3f", $eTime) . " s");

  OInventory::log(0, "Let's init counter info");
  $timeBefore=Time::HiRes::time;
  if(! initCounterInfo()) {
    OInventory::log(3, "Errors initiating counter info");
    return 0;
  }
  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Initiating counter info took "
                     . sprintf("%.3f", $eTime) . " s");

# print "DEBUG: === keys for all counters: ===\n";
# foreach my $aK (keys %allCounters) {
#   print "DEBUG:   key = '$aK'\n";
# }
# print "DEBUG: === groupInfo keys for all counters: ===\n";
# foreach my $aK (keys %allCountersByGIKey) {
#   print "DEBUG:   groupInfo key = '$aK'\n";
# }

  $timeBeforeB=Time::HiRes::time;
  foreach my $aVM (@{$OInventory::inventory{'VirtualMachine'}}) {
    my ($timeBefore, $eTime);

    my $availablePerfMetricIds = $perfManagerView->QueryAvailablePerfMetric(entity => $aVM->{view});

    $timeBefore=Time::HiRes::time;
    if(! getVmPerfs($aVM)) {
      OInventory::log(3, "Errors getting performance from $aVM");
      if(! --$maxErrs) {
        OInventory::log(3, "Too many errors when getting performance from "
                         . "vCenter. We'll try again on next picker's loop");
        return 0;
      }
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Updating performance for VM "
                     . "(name='" . $aVM->{name} . "', mo_ref='"
                     . $aVM->{mo_ref} . "') took "
                     . sprintf("%.3f", $eTime) . " s");
  }
  foreach my $aHost (@{$OInventory::inventory{'HostSystem'}}) {
    my ($timeBefore, $eTime);
    $timeBefore=Time::HiRes::time;
    if(! getHostPerfs($aHost)) {
      OInventory::log(3, "Errors getting performance from $aHost");
      if(! --$maxErrs) {
        OInventory::log(3, "Max number of errors reached when getting "
                         . "performance from vCenter. We will try again "
                         . "on next picker's loop");
        return 0;
      }
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Updating performance for Host "
                     . "(name='" . $aHost->{name} . "', mo_ref='"
                     . $aHost->{mo_ref} . "') took "
                     . sprintf("%.3f", $eTime) . " s");
  }

  $eTimeB=Time::HiRes::time - $timeBeforeB;
  OInventory::log(1, "Profiling: Getting the whole data performance took "
                     . sprintf("%.3f", $eTime) . " s");

  return 1;
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

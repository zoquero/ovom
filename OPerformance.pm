package OPerformance;
use strict;
use warnings;

use Exporter;
use POSIX qw/strftime/;
use Time::Piece;
use Time::HiRes; ## gettimeofday
use VMware::VIRuntime;
use Data::Dumper;

use OInventory;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;
use OMockView::OMockPerfCounterInfo;
use OMockView::OMockPerformanceManager;
use OMockView::OMockPerfQuerySpec;

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
	    push @{$allCountersByGIKey{$pCI->groupInfo->key}}, $pCI;
	  }
	  return 1;
}

#
# Return just the desired perfMetricIds
#
# @arg ref to the array of groupInfo key strings
#        (ex.: "["cpu", "mem", "network"])
# @arg ref to and array of perfMetricIds objects
#        (fields: counterId, instance)
#        Typically they are the available ones for a entity.
# @param
	#
	sub filterPerfMetricIds {
  my ($groupInfoArray, $perfMetricIds) = @_;
  my @r;

#print "DEBUG.filterPerfMetricIds: print groupInfoArray:\n";
#foreach my $z (@$groupInfoArray) {
#print "DEBUG.filterPerfMetricIds:   [] = $z:\n";
#}
#
#print "DEBUG.filterPerfMetricIds: print perfMetricIds:\n";
#foreach my $z (@$perfMetricIds) {
#print "DEBUG.filterPerfMetricIds:   [] = $z:\n";
#}
#die "die on first loop";

  #
  # First let's verify that allCountersByGIKey
  # hash has all the groupInfoArray elements as keys
  #
  foreach my $aGroupInfo (@$groupInfoArray) {
    if(!defined($allCountersByGIKey{$aGroupInfo})) {
      my $keys = join ", ", keys(%allCountersByGIKey);
      OInventory::log(2, "Looking for perfCounters of groupInfo '$aGroupInfo' "
                       . "but this group is not found in the perfCounterInfo "
                       . "array got from perfManagerView->perfCounter ($keys). "
                       . "It's probably a typo in configuration");
      next;
    }

    foreach my $aPMI (@$perfMetricIds) {

       foreach my $aC (@{$allCountersByGIKey{$aGroupInfo}}) {
         if($aC->key eq $aPMI->counterId) {
#
# TO_DO: Here we could save the whole counter
#        instead of just the small counterId object
#
           push @r, $aPMI;
           last;
         }
       }
    }
  }

  return \@r;
}

#
# Gets the desired groupInfo perfCounters for a entity
#
# @arg The entity
# @return a reference to an array with the groupInfo list ("cpu", "mem", ...)
#
#
sub getDesiredGroupInfoForEntity {
  my ($entity) = @_;
  my @groupInfo;
  if (!defined($entity)) {
    OInventory::log(3, "Missing parameters at getDesiredGroupInfoForEntity");
    return undef;
  }


  if(ref($entity) eq 'HostSystem' || ref($entity) eq "OHost") {
   @groupInfo = split /;/,
                  $OInventory::configuration{'perfpicker.groupInfo.host'};
  } 
  elsif(ref($entity) eq 'VirtualMachine' || ref($entity) eq "OVirtualMachine") {
   @groupInfo = split /;/,
                  $OInventory::configuration{'perfpicker.groupInfo.vm'};
  }
  else {
    OInventory::log(3, "Unexpected entity type (". ref($entity) . ") "
                     . "trying to getDesiredGroupInfoForEntity");
    return undef;
  }
  return \@groupInfo;
}


sub getRefreshRate {
  my ($entity) = @_;

  die "getRefreshRate: deprecated";

  #
  # "Deprecated. It looks like that it will keep on being 20 seconds.
  # If it changes in a future then we'll have to use API:
  #

#  my $historicalIntervals = $perfmgr_view->historicalInterval;

#  my $providerSummary = $perfManagerView->QueryPerfProviderSummary(entity => $entity);
#  This providerSummary is a PerfProviderSummary object like this:
# 
#  $VAR1 = bless( {
#                   'entity' => bless( {
#                                        'value' => 'vm-12xxx',
#                                        'type' => 'VirtualMachine'
#                                      }, 'ManagedObjectReference' ),
#                   'currentSupported' => '1',
#                   'refreshRate' => '20',
#                   'summarySupported' => '1'
#                 }, 'PerfProviderSummary' );
}


#
# Gets PerfQuerySpec object
#
# @arg the entity view
# @arg ref to array of metricIds
# @arg format (ex.: 'csv')
# @arg intervalId (typically '20' for realtime)
# @return the object if ok, else undef
#
sub getPerfQuerySpec {
  my $r;
  my ($entity, $metricId, $format, $intervalId) = @_;

  if(! defined($entity) || ! defined($metricId)
  || ! defined($format) || ! defined($intervalId)) {
    OInventory::log(3, "Missing arguments at getPerfQuerySpec");
    return undef;
  }
  if($OInventory::configuration{'debug.mock.enabled'}) {
    $r = OMockView::OMockPerfQuerySpec->new(entity     => $entity,
                                            metricId   => $metricId,
                                            format     => $format,
                                            intervalId => $intervalId);
  }
  else {
    $r = PerfQuerySpec->new(entity     => $entity,
                            metricId   => $metricId,
                            format     => $format,
                            intervalId => $intervalId);
  }
  if (! defined($r)) {
    OInventory::log(3, "Could not get PerfQuerySpec for entity with mo_ref '" 
                     . $entity->{name} . "', " . $#${$metricId} 
                     . " metricIds, $format format and $intervalId intervalId");
  }
  return $r;
}

#
# Gets PerfQuerySpec object
#
# @arg the entity view
# @arg ref to array of metricIds
# @arg format (ex.: 'csv')
# @arg intervalId (typically '20' for realtime)
# @return the object if ok, else undef
#
sub getPerfData {
  my $r;
  my ($perfQuerySpec) = @_;

  if (! defined ($perfQuerySpec)) {
    OInventory::log(3, "Missing arguments at getPerfData");
    return undef;
  }

  my $perfManager=getPerfManager();
  return $perfManager->QueryPerf(querySpec => $perfQuerySpec);
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
    my $availablePerfMetricIds;
    my $filteredPerfMetricIds;
    my $desiredGroupInfo;

    # TO_DO : move it to a getAvailablePerfMetric function
    $availablePerfMetricIds = $perfManagerView->QueryAvailablePerfMetric(entity => $aVM->{view});

    OInventory::log(0, "Available PerfMetricIds for $aVM:");
    foreach my $pMI (@$availablePerfMetricIds) {
      OInventory::log(0, " * PerfMetricId: {"
                       . "counterId='" . $pMI->counterId . "', "
                       . "instance='"  . $pMI->instance  . "'}");
    }

    $desiredGroupInfo = getDesiredGroupInfoForEntity($aVM);
    if(!defined($desiredGroupInfo) || $#$desiredGroupInfo == -1) {
      OInventory::log(2, "There are not desired groupInfo of perfCounters "
                       . "configured for this entity. Review configuration.");
      next;
    }
    my $txt = join ", ", @$desiredGroupInfo;
    OInventory::log(0, "There are " . ($#$desiredGroupInfo + 1) . " desired "
                     . "groupInfo of perfCounters configured "
                     . "for this entity: $txt");

    $filteredPerfMetricIds = filterPerfMetricIds($desiredGroupInfo,
                                                 $availablePerfMetricIds);
    if(!defined($filteredPerfMetricIds) || $#$filteredPerfMetricIds == -1) {
      OInventory::log(2, "Once filtered, none of the " 
                       . ($#$availablePerfMetricIds + 1) . " available perf "
                       . "metrics was configured to be gathered. "
                       . "Review configuration.");
      next;
    }
    if($OInventory::configuration{'log.level'} == 0) {
      $txt = '';
      foreach my $aFPMI (@$filteredPerfMetricIds) {
        $txt .= "{counterId='" .  $aFPMI->counterId . "',";
        $txt .= "instance='"   .  $aFPMI->instance  . "'} ";
      }
      OInventory::log(0, "Once filtered, " . ($#$filteredPerfMetricIds + 1) 
                         . " of the " . ($#$availablePerfMetricIds + 1)
                         . " available perf metrics were configured "
                         . "to be gathered: $txt");
    }

    #
    # Let's get the perf query spec to later retrieve perf data:
    #
    my $perfQuerySpec = getPerfQuerySpec(entity     => $aVM->{view},
                                         metricId   => $filteredPerfMetricIds,
                                         format     => 'csv',
                                         intervalId => 20); # 20s hardcoded
    if(! defined($perfQuerySpec)) {
      OInventory::log(3, "Could not get QuerySpec for entity");
      next;
    }

    my $perfData = getPerfData($perfQuerySpec);
    if(! defined($perfData)) {
      OInventory::log(3, "Could not get perfData for entity");
      next;
    }













    $timeBefore=Time::HiRes::time;
    if(! getVmPerfs($aVM)) {
      OInventory::log(3, "Errors getting performance from VM with mo_ref '"
                       . $aVM->{mo_ref} . "'");
      if(! --$maxErrs) {
        OInventory::log(3, "Too many errors when getting performance from "
                         . "vCenter. We'll try again on next picker's loop");
        return 0;
      }
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Updating performance for VM: "
                     . "{name='" . $aVM->{name} . "',mo_ref='"
                     . $aVM->{mo_ref} . "'} took "
                     . sprintf("%.3f", $eTime) . " s");
  }
  foreach my $aHost (@{$OInventory::inventory{'HostSystem'}}) {
    my ($timeBefore, $eTime);
    $timeBefore=Time::HiRes::time;
    if(! getHostPerfs($aHost)) {
      OInventory::log(3, "Errors getting performance from host with mo_ref '"
                       . $aHost->{mo_ref} . "'");
      if(! --$maxErrs) {
        OInventory::log(3, "Max number of errors reached when getting "
                         . "performance from vCenter. We will try again "
                         . "on next picker's loop");
        return 0;
      }
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Updating performance for Host: "
                     . "{name='" . $aHost->{name} . "',mo_ref='"
                     . $aHost->{mo_ref} . "'} took "
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

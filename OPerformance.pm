package OPerformance;
use strict;
use warnings;

use Exporter;
use POSIX qw/strftime/;
use Time::Piece;
use Time::HiRes;         ## gettimeofday
use VMware::VIRuntime;
use Data::Dumper;
use POSIX;               ## floor
use Scalar::Util qw(looks_like_number);
use Math::Spline;        ## for RRDB interpolation
use File::Copy qw(move); ## move perfData file
use Chart::Gnuplot;
use Cwd 'abs_path';
use File::Basename;


use OInventory;
use OvomDao;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;
use OPerfCounterInfo;
use OMockView::OMockPerformanceManager;
use OMockView::OMockPerfQuerySpec;
use OStage;
use OStageDescriptor;
use OAlarm;

our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( getLatestPerformance );

# Functions that are exported by default:
our @EXPORT = qw( getLatestPerformance );

our $csvSep = ";";

#
# Cubic splines need at least 4 points
#
our $minPoints = 4;
our $perfManagerView = undef;
our %allCounters            = ();
our %allCountersByGIKey     = ();
our %allPerfMetricIds       = (); # ${moref}{perfCounterId}{instance}
our $stageDescriptors       = undef;
our $perfMetricIdThresholds = undef;

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
# @return ref to perfManagerView if ok, undef if error
#
sub getPerfManager {
  if(! defined($perfManagerView)) {

    if($OInventory::configuration{'debug.mock.enabled'}) {
      OInventory::log(0, "In mocking mode. Now we should be getting "
                       . "perfManager from VIM service content...");
      $perfManagerView = OMockView::OMockPerformanceManager->new();
      return $perfManagerView;
    }

    eval {
      local $SIG{ALRM} = sub { die "Timeout getting perfManager" };
      my $maxSecs = $OInventory::configuration{'api.timeout'};
      OInventory::log(0, "Getting perfManager with ${maxSecs}s timeout");
      alarm $maxSecs;
      $perfManagerView = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
      alarm 0;
    };
    if($@) {
      alarm 0;
      if ($@ =~ /Timeout getting perfManager/) {
        OInventory::log(3, "Timeout! could not get perfManager from "
                         . "VIM service in a timely fashion: $@");
        $perfManagerView = undef;
        return undef;
      }
      else {
        OInventory::log(3, "Can't get perfManager from VIM service: $@");
        $perfManagerView = undef;
        return undef;
      }
    }
    if(! defined($perfManagerView)) {
      OInventory::log(3, "Can't get perfManager from VIM service.");
      return undef;
    }
  }
  OInventory::log(0, "Returning cached perfManager");
  return $perfManagerView;
}

#
# Update a perfCounterInfo if needed
#
# @arg the object to be inserted of updated
# @arg the object previously loaded
#
# @return  2 (if updated),
#          1 (if inserted),
#          0 (if it doesn't need to be update),
#         -1 (if errors)
#
sub updatePciIfNeeded {
  my $pCI       = shift;
  my $loadedPci = shift;
  my $ret = -2;

  # Pre-conditions
  if (! defined($pCI)) {
    OInventory::log(3, "updatePciIfNeeded needs a ref to a perfCounterInfo");
    return -1;
  }
  if (    ref($pCI) ne 'OPerfCounterInfo'
       && ref($pCI) ne 'PerfCounterInfo') {
    OInventory::log(3, "updatePciIfNeeded needs a ref to a perfCounterInfo "
                     . "and got a " . ref($pCI));
    return -1;
  }

  OInventory::log(0, "updatePciIfNeeded: got perfCounterInfo: "
                   . "statsType='"        . $pCI->statsType->val     . "',"
                   . "perDeviceLevel='"   . $pCI->perDeviceLevel     . "',"
                   . "nameInfoKey='"      . $pCI->nameInfo->key      . "',"
                   . "nameInfoLabel='"    . $pCI->nameInfo->label    . "',"
                   . "nameInfoSummary'"   . $pCI->nameInfo->summary  . "',"
                   . "groupInfoKey='"     . $pCI->groupInfo->key     . "',"
                   . "groupInfoLabel='"   . $pCI->groupInfo->label   . "',"
                   . "groupInfoSummary='" . $pCI->groupInfo->summary . "',"
                   . "key='"              . $pCI->key                . "',"
                   . "level='"            . $pCI->level              . "',"
                   . "rollupType='"       . $pCI->rollupType->val    . "',"
                   . "unitInfoKey='"      . $pCI->unitInfo->key      . "',"
                   . "unitInfoLabel='"    . $pCI->unitInfo->label    . "',"
                   . "unitInfoSummary='"  . $pCI->unitInfo->summary  . "'");

  if( ! defined($loadedPci)) {
    OInventory::log(0, "Couldn't find any perfCounterInfo with key="
                     . $pCI->key . " on DB. Let's insert it");
    if( ! OvomDao::insert($pCI) ) {
      OInventory::log(3, "Can't insert the PerfCounterInfo "
                  . " with key '" . $pCI->key . "'" );
      return -1;
    }
    $ret = 1;
  }
  else {
    my $comp = $loadedPci->compare($pCI);
    if ($comp == 1) {
      # Equal, Nop.
      # It hasn't to change in DB
    }
    elsif ($comp == 0) {
      # Changed (same mo_ref but some other attribute differs).
      # It has to be UPDATED into DB.
      OInventory::log(3, "Bug: the PerfCounterInfo with key '"
                       . $pCI->key . "' has changed and this software has been "
                       . "developed asserting that it would never change. "
                       . "Have you changed the DB charset? "
                       . "We are not going to update the row on DB, "
                       . "let's troubleshoot it before.");
      # OvomDao::update($pCI);
    }
    else {
      # Errors
      OInventory::log(3, "Bug! Can't compare the PerfCounterInfo "
                  . " with key='" . $pCI->key . "' with the one "
                  . " with with key='" . $loadedPci->key . "'");
      return -1;
    }
  }

  return 0;
}

#
# Initiate counter info
#
# As a sample, this is the list of the different groupInfo keys
# (perfCounterInfo->groupInfo->key) of the perfCounterInfo
# objects found on the $perfManagerView->perfCounter object
# on a regular vCenter 6.5:
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
    my $perfManager = getPerfManager();
    if ( ! defined($perfManager) ) {
      OInventory::log(3, "Can't get perfManager");
      return 0;
    }
    $perfCounterInfo = $perfManager->perfCounter;
  };
  if($@) {
    OInventory::log(3, "Can't get perfCounter from perfManagerView: $@");
    return 0;
  }

  #
  # Let's save the csv file with PerfCounterInfo objects
  #
  my($inventoryBaseFolder) = $OInventory::configuration{'inventory.export.root'}
                             . "/" . $OInventory::configuration{'vCenter.fqdn'};
  my $pciCsv = "$inventoryBaseFolder/PerfCounterInfo.csv";
  OInventory::log(1, "Let's write PerfCounterInfo objects into the CSV file "
                        . $pciCsv);
  my $csvHandler;
  if( ! open($csvHandler, ">:utf8", $pciCsv) ) {
    OInventory::log(3, "Could not open CSV file '$pciCsv': $!");
    return 0;
  }

  my $l = "#statsType${csvSep}perDeviceLevel${csvSep}nameInfoKey${csvSep}"
        . "nameInfoLabel${csvSep}nameInfoSummary${csvSep}groupInfoKey${csvSep}"
        . "groupInfoLabel${csvSep}groupInfoSummary${csvSep}key${csvSep}level"
        . "${csvSep}rollupTypeVal${csvSep}unitInfoKey${csvSep}unitInfoLabel"
        . "${csvSep}unitInfoSummary";
  print $csvHandler "$l\n";

  #
  # Let's iterate foreach PerfCounterInfo to update DB
  #
  foreach my $pCI (@$perfCounterInfo) {
    #
    # Reference it from allCounters and allCountersByGIKey vars
    #

    my $oPCI = OPerfCounterInfo->newFromPerfCounterInfo($pCI);
    my $key = $oPCI->key;

    #
    # Let's load the PCI from database ... if it was already saved
    #
    my $loadedPci = OvomDao::loadEntity($key, 'PerfCounterInfo');
#print "DEBUG: key=$key\n";

    #
    # We'll load from CSV files the thresholds when they appear
    # for the first time (on first run and probably
    # after installing new features in vSphere)
    #
    if(! defined($loadedPci)) {
      OInventory::log(0,
        "Let's get its specific threshold from the configuration files");
  
      my ($pcCritThresholdFromCsv,  $pcWarnThresholdFromCsv);
      $pcWarnThresholdFromCsv = getPerfMetricIdThreshold(undef, $key, undef, 'warn');
      $pcCritThresholdFromCsv = getPerfMetricIdThreshold(undef, $key, undef, 'crit');

# print "DEBUG: newPCI for key=$key it's set oPCI->{_critThreshold} = ";
# if(defined($pcCritThresholdFromCsv)) {
# print "$pcCritThresholdFromCsv\n";
# }
# else {
# print "undef\n";
# }
  
      if(! defined($loadedPci) || !defined($oPCI->{_critThreshold})) {
        $oPCI->{_critThreshold} = $pcCritThresholdFromCsv;
      }
      if(! defined($loadedPci) || !defined($oPCI->{_warnThreshold})) {
        $oPCI->{_warnThreshold} = $pcWarnThresholdFromCsv;
      }
    }
    else {
      #
      # We save the thresholds with the other attributes of PerfCounterInfo.
      # So, if the object exists in DB we must load the thresholds for oPCI.
      #
      $oPCI->{_critThreshold} = $loadedPci->{_critThreshold};
      $oPCI->{_warnThreshold} = $loadedPci->{_warnThreshold};
    }
#     else {
# 
# print "DEBUG: oldPCI for key=$key it's set loadedPci->critThreshold = ";
# if(defined($loadedPci->{_critThreshold})) {
# print $loadedPci->{_critThreshold} . "\n";
# }
# else {
# print "undef\n";
# print "DEBUG: Dumper: " . Dumper($loadedPci) . "\n";
# }
#   
#     }

# 
# print "DEBUG: oldPCI for key=$key it's set loadedPci->{_critThreshold} = ";
# if(defined($oPCI->{_critThreshold})) {
# print $oPCI->{_critThreshold} . "\n";
# }
# else {
# print "undef\n";
# print "DEBUG: Dumper de oPCI       : " . Dumper($oPCI) . "\n";
# print "DEBUG: Dumper de loadedPci  : " . Dumper($loadedPci) . "\n";
# }
# print "DEBUG:\n";
# 


    #
    # Let's cache all PerfCounterInfo to accelerate posterior access:
    #
    $allCounters{$key} = $oPCI;

    #
    # Bug! We were always pushing the PerfCounter,
    # a small memory leak that affected in performance
    #
    # push @{$allCountersByGIKey{$oPCI->groupInfo->key}}, $oPCI;
    my $perfCounterWasAlreadyPushed = 0;
    foreach my $aPCI ( @{$allCountersByGIKey{$oPCI->groupInfo->key}} ) {
      if ( $aPCI->key eq $oPCI->key ) {
        $perfCounterWasAlreadyPushed = 1;
      }
    }
    if(! $perfCounterWasAlreadyPushed ) {
      OInventory::log(0, "Let's push the perfCounter with key=" . $oPCI->key);
      push @{$allCountersByGIKey{$oPCI->groupInfo->key}}, $oPCI;
    }
    else {
      OInventory::log(0, "The perfCounter with key=" . $oPCI->key 
                       . " was already pushed");
    }

    #
    # Store it on DataBase
    #
    my $r = updatePciIfNeeded($oPCI, $loadedPci);
    if( $r == 2 ) {
      OInventory::log(2, "The perfCounter key=" . $oPCI->key . " changed on DB");
    }
    elsif( $r == 1 ) {
      OInventory::log(2, "New perfCounter key=" . $oPCI->key . " inserted on DB");
    }
    elsif( $r == 0 ) {
      OInventory::log(0, "The perfCounter key=" . $oPCI->key
                       . " was already on DB with same values");
    }
    else {
      OInventory::log(3, "Could not update the perfCounter key="
                       . $oPCI->key . " on DB");
    }

    #
    # Save perfCounterInfo objects in CSV files
    #
    my $s = $oPCI->statsType->val     . $csvSep
          . $oPCI->perDeviceLevel     . $csvSep
          . $oPCI->nameInfo->key      . $csvSep
          . $oPCI->nameInfo->label    . $csvSep
          . $oPCI->nameInfo->summary  . $csvSep
          . $oPCI->groupInfo->key     . $csvSep
          . $oPCI->groupInfo->label   . $csvSep
          . $oPCI->groupInfo->summary . $csvSep
          . $oPCI->key                . $csvSep
          . $oPCI->level              . $csvSep
          . $oPCI->rollupType->val    . $csvSep
          . $oPCI->unitInfo->key      . $csvSep
          . $oPCI->unitInfo->label    . $csvSep
          . $oPCI->unitInfo->summary;
    print $csvHandler "$s\n";
  }

  #
  # Let's close the CSV file for PerfCounterInfo objects
  #
  if( ! close($csvHandler) ) {
    OInventory::log(3, "Could not close the CSV file '$pciCsv': $!");
    return 0;
  }

  return 1;
}

#
# Return just the desired perfMetricIds
#
# @arg entity's moref
# @arg ref to the array of groupInfo key strings
#        with the desired groupInfo for this entity
#        (ex.: "["cpu", "mem", "network"])
# @arg ref to the array of perfMetricIds availables for this entity
#        (fields: counterId, instance)
#        Typically they are the available ones for a entity.
# @param
#
sub filterPerfMetricIds {
  my ($moref, $groupInfoArray, $perfMetricIds) = @_;
  my @r;


  #
  # We'll cache it in %allPerfMetricIds, so let's empty it to refill it later:
  # %allPerfMetricIds : ${moref}{perfCounterId}{instance}
  #
  $allPerfMetricIds{$moref} = ();

  OUTER: foreach my $aPMI (@$perfMetricIds) {
    MIDDLE: foreach my $aGroupInfo (@$groupInfoArray) {
      #
      # Sanity check
      #
      if(!defined($allCountersByGIKey{$aGroupInfo})) {
        my $keys = join ", ", keys(%allCountersByGIKey);
        OInventory::log(2, "Looking for perfCounters of groupInfo '$aGroupInfo' "
                         . "but this group is not found in the perfCounterInfo "
                         . "array got from perfManagerView->perfCounter ($keys). "
                         . "It's probably a typo in configuration");
        next;
      }

      INNER: foreach my $aC (@{$allCountersByGIKey{$aGroupInfo}}) {
        if($aC->key eq $aPMI->counterId) {
#
# TO_DO: Here we could save the whole counter
#        instead of just the small counterId object
#
          push @r, $aPMI;

          #
          # Let's cache it in %allPerfMetricIds !
          # %allPerfMetricIds : ${moref}{perfCounterId}{instance}
          #
          $allPerfMetricIds{$moref}{$aPMI->counterId}{$aPMI->instance}
            = $aPMI;
          last MIDDLE;
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
# @arg hash with:
#       {entity}:     the entity view
#       {metricId}:   ref to array of metricIds
#       {format} :    format (ex.: 'csv')
#       {intervalId}: intervalId (typically '20' for realtime)
# @return the object if ok, else undef
#
sub getPerfQuerySpec {
  my $r;
  my (%args) = @_;

  if(! defined ($args{'entity'}) || ! defined ($args{'metricId'})
  || ! defined ($args{'format'}) || ! defined ($args{'intervalId'})) {
    OInventory::log(3, "getPerfQuerySpec constructor needs a hash of args");
    return undef;
  }

  if($OInventory::configuration{'debug.mock.enabled'}) {
    $r = OMockView::OMockPerfQuerySpec->new(entity     => $args{entity},
                                            metricId   => $args{metricId},
                                            format     => $args{format},
                                            intervalId => $args{intervalId});
  }
  else {
    $r = PerfQuerySpec->new(entity     => $args{entity},
                            metricId   => $args{metricId},
                            format     => $args{format},
                            intervalId => $args{intervalId});
  }
  if (! defined($r)) {
    OInventory::log(3, "Could not get PerfQuerySpec for entity with mo_ref '" 
                     . $args{entity}->{name} . "', " . $#${$args{metricId}} 
                     . " metricIds, $args{format} format and $args{intervalId} intervalId");
  }
  return $r;
}

#
# Get PerfData object
#
# @arg the querySpec
# @return the return value of perfManager->QueryPerf
#                    (an array of PerfEntityMetricCSV objects) if ok,
#                    else undef
#
sub getPerfData {
  my $r;
  my ($perfQuerySpec) = @_;

  if (! defined ($perfQuerySpec)) {
    OInventory::log(3, "Missing arguments at getPerfData");
    return undef;
  }
  if ( ref($perfQuerySpec) ne 'PerfQuerySpec'
    && ref($perfQuerySpec) ne 'OMockView::OMockPerfQuerySpec' ) {
    OInventory::log(3, "getPerfData argument must be a PerfQuerySpec");
    return undef;
  }
  if ( $#{$perfQuerySpec->metricId} == -1 ) {
    OInventory::log(2, "getPerfData: perfQuerySpec got no metricIds");
    return undef;
  }

  my $perfManager=getPerfManager();
  if(! $perfManager) {
    OInventory::log(3, "Errors getting getPerfManager");
    return undef;
  }

  eval {
    local $SIG{ALRM} = sub { die "Timeout calling QueryPerf" };
    my $maxSecs = $OInventory::configuration{'api.timeout'};
    OInventory::log(0, "Calling QueryPerf, with a timeout of $maxSecs seconds");
    alarm $maxSecs;
    $r = $perfManager->QueryPerf(querySpec => $perfQuerySpec);
    alarm 0;
  };
  if ($@) {
    alarm 0;
    if ($@ =~ /Timeout calling QueryPerf/) {
      OInventory::log(3, "Timeout! perfManager->QueryPerf did not respond "
                       . "in a timely fashion: $@");
      return undef;
    } else {
      OInventory::log(3, "perfManager->QueryPerf failed: $@");
      return undef;
    }
  }

## print "==============================================\n";
## print "perfQuerySpec = " . Dumper($perfQuerySpec ) . "\n";
## print "queryPerf     = " . Dumper($r) . "\n";

  if (! defined ($r)) {
    OInventory::log(3, "perfManager->QueryPerf returned undef");
    return undef;
  }

  if ($#$r == -1) {
    my $d = Dumper($r);
    chomp($d);
    OInventory::log(3, "perfManager->QueryPerf returned "
                     . "an empty array of PerfEntityMetricCSV for "
                     . "entity {name=" . $perfQuerySpec->{entity}->{name}
                     . ",mo_ref=" . $perfQuerySpec->{entity}->{mo_ref}->{value}
                     . "}: " . $d);
    return undef;
  }

  return $r;
}

#
# Get the perfMetricIdThreshold
#
# @arg a ManagedObjectReference
#      (with 'value' (mo-ref) and 'type' (VirtualMachine ...) fields)
# @arg counterId
# @arg instance
# @arg crit | warn
# @return The critical or warning thresholds
#           for that PerfCounterInfo or concrete PerfMetricId
#           or undef if errors
#
sub getPerfMetricIdThreshold {
  my $entity     = shift;
  my $counterId  = shift;
  my $instance   = shift;
  my $thresType  = shift;

  my $allPerfMetricIdThresholds = getAllPerfMetricIdThresholds();
  if(! defined($allPerfMetricIdThresholds) ) {
    OInventory::log(3, "Can't get all PerfMetricId thesholds");
    return undef;
  }
  if($thresType ne 'crit' && $thresType ne 'warn') {
    OInventory::log(3,
      "3rd arg for getPerfMetricIdThreshold just can be (alert|warn)");
    return undef;
  }

  # print "DEBUG: all thresholds = " . Dumper($allPerfMetricIdThresholds) ."\n";
  if(defined($entity)) {
    if($thresType eq 'crit') {
      return $$allPerfMetricIdThresholds{$entity->value}{$counterId}{$instance}[1];
    }
    else {

## print "\n\n=======\ncounterId=$counterId\ninstance=$instance\nentity=" . Dumper($entity) . "\n\nthresholds=\n" . Dumper($allPerfMetricIdThresholds) . "\n=====\n";
## #     return $$allPerfMetricIdThresholds{$entity->{value}}{$counterId}{$instance}[0];
##       my %c = $$allPerfMetricIdThresholds{$entity->value};
##       return $c{$counterId}{$instance}[0];

      return $$allPerfMetricIdThresholds{$entity->value}{$counterId}{$instance}[0];
    }
  }
  else {
    if($thresType eq 'crit') {
      return $$allPerfMetricIdThresholds{''}{$counterId}{''}[1];
    }
    else {
      return $$allPerfMetricIdThresholds{''}{$counterId}{''}[0];
    }
  }
}

#
# Get all configured PerfMetricId thresholds.
# It will be aggressively cached.
#
# If moref is empty then it's a threshold for PerfCounter,
# that's for all the instances on all the ManagedEntities.
#
# @return reference to hash{moref}{counterid}{instance} = ref to array [crit, warn]
#         or undef if errors
#
sub getAllPerfMetricIdThresholds {
 
  my $handler;
  my $filename = dirname(abs_path(__FILE__)) . "/thresholds/PerfMetricId.thresholds.csv";

  if(!defined($perfMetricIdThresholds)) {
    %$perfMetricIdThresholds = ();
    OInventory::log(1, "Opening PerfMetricId thresholds file '$filename'");
    if( ! open($handler, "<encoding(UTF-8)", $filename) ) {
      OInventory::log(3, "Can't open PerfMetricId thresholds file '$filename': $!");
      return undef;
    }
  
    while (my $line = <$handler>) {
      chomp $line;
      next if $line =~ /^\s*$/;
      next if $line =~ /^#/;
      my @parts = split /$csvSep/, $line;
      if ($#parts < 4) {
        OInventory::log(3, "Can't parse this line '$line' on file '$filename': $!");
        if( ! close($handler) ) {
          OInventory::log(3, "Could not close file '$filename': $!");
        }
        return undef;
      }
      #moref;counterId;instance;critThreshold;warnThreshold
      $$perfMetricIdThresholds{$parts[0]}{$parts[1]}{$parts[2]}
        = [$parts[3], $parts[4]];
    }
  
    if(!close($handler)) {
      OInventory::log(3, "Can't close PerfMetricId thresholds file '$filename': $!");
      return 0;
    }
  }
  return $perfMetricIdThresholds;
}

#
# Register on DataBase that a perfData for an entity has been saved on a file
#
# Sample of parameters got:
#
# perfData:
# $VAR1 = bless( {
#                  'id' => bless( {
#                                   'instance' => '',
#                                   'counterId' => '2'
#                                 }, 'PerfMetricId' ),
#                  'value' => '920,912,653,819,737,661,957,774,675,1147,...'
#                }, 'PerfMetricSeriesCSV' );
# entity:
# $VAR1 = bless( {
#                  'type' => 'VirtualMachine',
#                  'value' => 'vm-10068'
#                }, 'ManagedObjectReference' );
#
# @arg perfData
# @arg entityView
# @arg ref to timetamps. The caller asserted that has equal size than @$values
# @arg ref to values   . The caller asserted that has equal size than @$timestamps
# @return 1 ok, 0 errors
#
sub registerPerfDataSaved {
  # Take a look at the subroutine comments to find a sample of received objects
  my $perfData   = shift;
  my $entity     = shift;
  my $timestamps = shift;
  my $values     = shift;
  my $pmi        = undef;

  OInventory::log(0, "Registering that counterId=" . $perfData->id->counterId
                   . ",instance=" . $perfData->id->instance
                   . " has been saved for the " . $entity->type
                   . " with mo_ref=" . $entity->value);

  #
  # Let's look for the latest value non-empty
  #
  my $lastValue     = undef;
  my $lastTimestamp = undef;
  for (my $i = $#$values; $i >= 0; $i--) {
    if(defined($$values[$i]) && $$values[$i] ne '') {
      $lastValue     = $$values[$i];
      $lastTimestamp = $$timestamps[$i];
      last;
    }
  }
  if(! defined($lastValue)) {
    OInventory::log(2,
      "Could not find any valid value in the latest perfdata of the counterId="
      . $perfData->id->counterId . ",instance=" . $perfData->id->instance
      . " of the " . $entity->type . " with mo_ref=" . $entity->value);
  }

  #
  # Let's look for the PerfMetric in DB to insert/update it
  # Remember that %allPerfMetricIds is just a cache
  # in memory before inserting/updating the PMI in DB.
  #
  $pmi = OvomDao::loadEntity($perfData->id->counterId, 'PerfMetric',
                             $perfData->id->instance,  $entity);

  my $previousLastCollection = 0;

  #
  # Let's insert or update its entry in table for PerfMetric ('perf_metric')
  #
  if( ! defined($pmi)) {
    #
    # It just should happen in first run of OVOM and in its first run after
    # adding new features to vSphere that publish new PerfCounters
    #
    # After that you will have to set/modify the thresholds in DB via WebUI
    #
    OInventory::log(0, "Before inserting the new PerfMetricId, let's get the "
                     . "specific threshold for it PerfMetricId from the "
                     . "configuration files");

    my ($pmiCritThresholdFromCsv, $pmiWarnThresholdFromCsv);
    $pmiWarnThresholdFromCsv = getPerfMetricIdThreshold($entity, $perfData->id->counterId, $perfData->id->instance, 'warn');
    $pmiCritThresholdFromCsv = getPerfMetricIdThreshold($entity, $perfData->id->counterId, $perfData->id->instance, 'crit');
  
# die "entity = " . Dumper($entity) . "\nconter = " . $perfData->id->counterId . ",instance=" . $perfData->id->instance . " , that's: pmiC=$pmiCritThresholdFromCsv , pmiW=$pmiWarnThresholdFromCsv";

    $pmi = OMockView::OMockPerfMetricId->new(
                          [ undef, $entity->value, $perfData->id->counterId, $perfData->id->instance, $pmiCritThresholdFromCsv, $pmiWarnThresholdFromCsv ]
                        );

    #
    # update the cached %allPerfMetricIds : {moref}{perfCounterId}{instance}
    #
    $allPerfMetricIds{$entity->value}{$perfData->id->counterId}{$perfData->id->instance} = $pmi ;

    OInventory::log(0, "Now let's insert the PerfMetricId");
    if( ! OvomDao::insert($pmi, $entity) ) {
# * the PerfMetricId object (regular 1st parameter)
# * managedObjectReference ($managedObjectReference->type (VirtualMachine, ...),
#                           $managedObjectReference->value (it's mo_ref))
      OInventory::log(3, "Can't insert the PerfMetricId "
                  . " counterId='" . $perfData->id->counterId
                  . "',instance='" . $perfData->id->instance
                  . "' for entity with mo_ref='" . $entity->value . "'");
      return 0;
    }
  }
  else {

    #
    # Let's keep track of when was the last collection before this loop.
    # We'll need it to update alarms just after the last execution.
    #
    $previousLastCollection = $pmi->lastCollection;

    #
    # update
    #
    OInventory::log(0, "Let's update previous PerfMetricId:");
    # my $aPerfMetricId = OMockView::OMockPerfMetricId->new(
    #                       [ undef, $entity->value, $perfData->id->counterId, $perfData->id->instance ]
    #                     );

    #
    # update the cached %allPerfMetricIds : {moref}{perfCounterId}{instance}
    #
    $allPerfMetricIds{$entity->value}{$perfData->id->counterId}{$perfData->id->instance} = $pmi ;

    # TO_DO : update unimplemented for PerfMetric , 2nd extra argument
    if( ! OvomDao::update($pmi, $entity) ) {
# * the PerfMetricId object (regular 1st parameter)
# * managedObjectReference ($managedObjectReference->type (VirtualMachine, ...),
#                           $managedObjectReference->value (it's mo_ref))
      OInventory::log(3, "Can't update the PerfMetricId "
                  . " counterId='" . $perfData->id->counterId
                  . "',instance='" . $perfData->id->instance
                  . "' for entity with mo_ref='" . $entity->value . "'");
      return 0;
    }

  }

  #
  # If PerfMetricId has thresholds
  #   then we're use them
  # else If PerfCounterInfo has thresholds
  #   then we're use them
  #      else If PerfCounterInfo has thresholds
  #        then we're use them
  #
  my $pci = $allCounters{$perfData->id->counterId};
  my $critThreshold = undef;
  my $warnThreshold = undef;

  # Crit threshold
  my $critThresholdOrigin = '';
  my $warnThresholdOrigin = '';
  if(defined($pmi->{_critThreshold})) {
    $critThreshold = $pmi->{_critThreshold};
    $critThresholdOrigin .= 'pmi';
  }
  else {
    if(defined($pci->{_critThreshold})) {
      $critThreshold = $pci->{_critThreshold};
      $critThresholdOrigin .= 'pci';
    }
  }
  # Warn threshold
  if(defined($pmi->{_warnThreshold})) {
    $warnThreshold = $pmi->{_warnThreshold};
    $warnThresholdOrigin .= 'pmi';
  }
  else {
    if(defined($pci->{_warnThreshold})) {
      $warnThreshold = $pci->{_warnThreshold};
      $warnThresholdOrigin .= 'pci';
    }
  }

  my $pds = "moref=" . $entity->value . ",counterId=" . $perfData->id->counterId . ",instance=" . $perfData->id->instance . ",lastValue=$lastValue";
  if(defined($critThreshold)) {
    $pds .= ", critThreshold=$critThreshold ($critThresholdOrigin)";
  }
  else {
    $pds .= ", no critThreshold";
  }
  if(defined($warnThreshold)) {
    $pds .= ", warnThreshold=$warnThreshold ($warnThresholdOrigin)";
  }
  else {
    $pds .= ", no warnThreshold";
  }

  if(! setAlarmState($entity, $pmi, $perfData, $critThreshold, $warnThreshold, $timestamps, $values, $previousLastCollection)) {
    OInventory::log(3, "Can't setAlarmState for "
                . " counterId='"               . $perfData->id->counterId
                . "',instance='"               . $perfData->id->instance
                . "' for entity with mo_ref='" . $entity->value . "'");
    return 0;

  }

  if(defined($critThreshold) && defined($lastValue) && $lastValue >= $critThreshold) {
    # Let's trigger a critical alarm
warn "DEBUG: Let's trigger a critical alarm for moref=" . $entity->value . ",counterId=" . $perfData->id->counterId . ",instance=" . $perfData->id->instance . ". Effective crit=$critThreshold, warn=$warnThreshold\n";
    $pds .= ", crit alarm triggered ";
  }
  elsif(defined($warnThreshold) && defined($lastValue) && $lastValue >= $warnThreshold) {
    # Let's trigger a warning alarm
warn "DEBUG: Let's trigger a warning alarm for moref=" . $entity->value . ",counterId=" . $perfData->id->counterId . ",instance=" . $perfData->id->instance . ". Effective crit=$critThreshold, warn=$warnThreshold\n";
    $pds .= ", warn alarm triggered ";
  }

# We still must model 'Alarm' and we'll have to load previous state for this PerfMetricId because we'll have to add a hook for 'recovery'

  OInventory::log(0, "Saved perf data: $pds");

  return 1;
}

# 
# Set alarm state for this PMI based on the thresholds.
# 
# States:
# * undef : Ok
# * 0     : Ok
# * 1     : Warn
# * 2     : Crit
# 
# Transitions (hooks):
# * uprise2Warn   (Ok|undef      => Warn)
# * uprise2Crit   (Ok|Warn|undef => Crit)
# * decrease2Warn (Crit          => Warn)
# * recover       (Crit|Warn     => Ok)
# 
# @arg entity   : ManagedObjectReference
#               : $entity->value (it's mo_ref)
#                 $entity->type ('VirtualMachine', ...)
# @arg pmi      : MockView::OMockPerfMetricId object
# @arg perfData : PerfMetricSeriesCSV
#               : $perfData->id->counterId
#                 $perfData->id->instance
# @arg critThreshold, can be undef for pmi or pci without threshold
# @arg warnThreshold, can be undef for pmi or pci without threshold
# @arg timestamps : ref to array of timestamps
# @arg values     : ref to array of timestamps
# @arg previousLastCollection : timestamp of the previous collection for this PMI
#                               Can be undef, for new PMIs (first execution)
# @return 1 ok, 0 error
# 
sub setAlarmState {
  my $entity                 = shift; # ManagedObjectReference :
                                      # $entity->value (it's mo_ref) ,
                                      # $entity->type ('VirtualMachine', ...)
  my $pmi                    = shift; # MockView::OMockPerfMetricId object
  my $perfData               = shift; # PerfMetricSeriesCSV :
                                      # $perfData->id->counterId ,
                                      # $perfData->id->instance
  my $critThreshold          = shift; # can be undef, pmi|pci without threshold
  my $warnThreshold          = shift; # can be undef, pmi|pci without threshold
  my $timestamps             = shift;
  my $values                 = shift;
  my $previousLastCollection = shift;

  if(!defined($entity)) {
    OInventory::log(3, "setAlarmState: got undefined entity");
    return 0;
  }
  if(!defined($pmi)) {
    OInventory::log(3, "setAlarmState: got undefined PerfMetricId");
    return 0;
  }
  if(ref($pmi) ne 'OMockView::OMockPerfMetricId') {
    OInventory::log(3, "setAlarmState: expected a MockView::OMockPerfMetricId "
                     . "as 2nd parameter and got a " . ref($pmi));
    return 0;
  }
  if(!defined($perfData)) {
    OInventory::log(3, "setAlarmState: got undefined perfData");
    return 0;
  }
  # thresholds can be undef (pmi or pci without thresholds) 
  if(!defined($timestamps) || ref($timestamps) ne 'ARRAY') {
    OInventory::log(3, "setAlarmState: timestamps must be an array of tstamps");
    return 0;
  }
  if(!defined($values) || ref($values) ne 'ARRAY') {
    OInventory::log(3, "setAlarmState: values must be an array of tstamps");
    return 0;
  }

  my $prevState    = undef;
  my $prevAlarm    = undef;
  my $r            = undef;
  my $newState     = 0;
  my $newStateTime = $$timestamps[$#$timestamps];
  my $firstPosAfterValue = 0;

  ($r, $prevAlarm) = OvomDao::loadEntity($entity->value, 'OAlarm', $pmi->id);
  if( ! defined($r) || $r != 1 ) {
    OInventory::log(3, "Can't look for previous alarms");
    return 0;
  }

# if(defined($prevAlarm)) {
#   warn "DEBUG: Alarm found: ". Dumper($prevAlarm) . "\n";
# }
# else {
#   warn "DEBUG: NO previous alarm found\n";
# }

  if(defined($prevAlarm)) {
    if($prevAlarm->is_critical) {
      $prevState = 2;
    }
    else {
      $prevState = 1;
    }
  }

  if(defined($critThreshold) || defined($warnThreshold)) {
    if(! defined($critThreshold)) {
      OInventory::log(3, "Warn threshold without Crit thr. is not supported");
      return 0;
    }

    if(defined($previousLastCollection)) {
      $firstPosAfterValue = 
        getFirstPosAfterValue($timestamps, $previousLastCollection);
    }
  
    if(!defined($firstPosAfterValue)) {
      OInventory::log(3, "Errors getting the first pos after the timestamp "
        . $previousLastCollection . ", so we can't check for alarms");
      return 0;
    }
  
# print "critThreshold=$critThreshold , warnThreshold=$warnThreshold\n";
    for (my $i = $firstPosAfterValue; $i <= $#$values; $i++) {
      my $v = $$values[$i];
# print "checking value $v\n";
      if(defined($critThreshold) && defined($v)) {
        if($v >= $critThreshold) {
          $newState = 2;
          last;
        }
        if(    defined($warnThreshold)
            && $newState == 0
            && $v >= $warnThreshold) {
          $newState = 1;
        }
      }
    }

  }

  #
  # Note:
  #
  # You can remove thresholds after having an alarm launched and you 
  # can change thresholds after , so you always must check for previous 
  # and new alarm states to trigger transitions, independently of 
  # whether are there or are there not thresholds.
  #

  #
  # Set alarm state and trigger transition hooks, if applies
  #

# 
# States:
# * undef : Ok
# * 0     : Ok
# * 1     : Warn
# * 2     : Crit
# 
# Transitions (hooks):
# * uprise2Warn   (Ok|undef      => Warn)
# * uprise2Crit   (Ok|Warn|undef => Crit)
# * decrease2Warn (Crit          => Warn)
# * recover       (Crit|Warn     => Ok)
# 

  if(!defined($prevState) && $newState == 2) {
    #
    # * uprise2Crit   (Ok     |undef => Crit)
    #
    my $entityId = OInventory::entityType2entityId($entity->type);
    if(!defined($entityId)) {
      OInventory::log(3, "Can't get the entity id for " . $entity->type);
      return 0;
    }

    my $a = { 'id'               => undef,
              'entity_type'      => $entityId,
              'mo_ref'           => $entity->value,
              'is_critical'      => 1, # crit == 1 , warn = 0
              'perf_metric_id'   => $pmi->id,
              'is_acknowledged'  => 0,
              'is_active'        => 1,
              'alarm_time'       => $newStateTime,
              'last_change'      => undef     # It will be set on db
            };

    my $alarm = OAlarm->newWithArgsHash($a);
# warn "alarm = " . Dumper($alarm);

    if( ! OvomDao::insert($alarm) ) {
      OInventory::log(3, "Can't insert the Alarm $alarm");
      return -1;
    }
    OInventory::log(1, "Alarm uprise2Crit from Ok "
                     . " for entity=" . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }
  elsif(defined($prevState) && $prevState == 1 && $newState == 2) {
    #
    # * uprise2Crit   (   Warn       => Crit)
    #
    $prevAlarm->setIsCritical(1);
    if( ! OvomDao::update($prevAlarm) ) {
      OInventory::log(3, "Can't update the Alarm $prevAlarm to Crit");
      return -1;
    }
    OInventory::log(1, "Alarm uprise2Crit from Warn "
                     . "for entity="    . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }
  elsif((!defined($prevState) || $prevState == 0) && $newState == 1) {
    #
    # * uprise2Warn   (Ok|undef      => Warn)
    #
    my $entityId = OInventory::entityType2entityId($entity->type);
    if(!defined($entityId)) {
      OInventory::log(3, "Can't get the entity id for " . $entity->type);
      return 0;
    }

    my $a = { 'id'               => undef,
              'entity_type'      => $entityId,
              'mo_ref'           => $entity->value,
              'is_critical'      => 0, # crit == 1 , warn = 0
              'perf_metric_id'   => $pmi->id,
              'is_acknowledged'  => 0,
              'is_active'        => 1,
              'alarm_time'       => $newStateTime,
              'last_change'      => undef     # It will be set on db
            };

    my $alarm = OAlarm->newWithArgsHash($a);
# warn "alarm = " . Dumper($alarm);

    if( ! OvomDao::insert($alarm) ) {
      OInventory::log(3, "Can't insert the Alarm $alarm");
      return -1;
    }
    OInventory::log(1, "Alarm uprise2Warn from Ok "
                     . " for entity="   . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }
  elsif((defined($prevState) && $prevState == 2) && $newState == 1) {
    #
    # * decrease2Warn (Crit          => Warn)
    #
    $prevAlarm->setIsCritical(0);
    if( ! OvomDao::update($prevAlarm) ) {
      OInventory::log(3, "Can't update the Alarm $prevAlarm");
      return -1;
    }
    OInventory::log(1, "Alarm decrease2Warn from Crit "
                     . " for entity="   . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }
  elsif((defined($prevState) && $prevState != 0) && $newState == 0) {
    #
    # * recover       (Crit|Warn     => Ok)
    #
    $prevAlarm->setIsActive(0);
    if( ! OvomDao::update($prevAlarm) ) {
      OInventory::log(3, "Can't update the Alarm $prevAlarm");
      return -1;
    }
    OInventory::log(1, "Alarm recover from $prevState (Crit==1,Warn==2) "
                     . " for entity="   . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }
  else {
    OInventory::log(0, "No Alarm change"
                     . " for entity="   . $entity->value
                     . ",pmi_key="      . $pmi->counterId
                     . ",pmi_instance=" . $pmi->instance);
  }

  return 1;
}

#
# Get the first position after a value
# in an array that always increases with a constant delta
#
# Simply iterating from the first component is computationally very inefficient
#
# @arg ref to array of equidistant values that are increasing
#      (valid for array of timestamps or sorted data ascending)
# @arg the value
# @return first position in the array (0..N-1)
#         that contains a value greater than the value,
#         or undef if errors.
#
sub getFirstPosAfterValue {
  my $values   = shift;
  my $theValue = shift;

  #
  # Preconditions, errors:
  #
  if(!defined($values) || ref($values) ne 'ARRAY') {
    OInventory::log(3,
      "getFirstPosAfterValue: values must be an array of tstamps");
    return 0;
  }
  if($#$values == -1) {
    OInventory::log(3,
      "getFirstPosAfterValue: values can't be an empty array");
    return 0;
  }
  if(!defined($theValue)) {
    OInventory::log(3,
      "getFirstPosAfterValue: the value is undef");
    return 0;
  }

  #
  # Easy cases
  #
  if($$values[0] > $theValue) {
    # First is already greater
    return 0;
  }
  if($$values[$#$values] <= $theValue) {
    # Last is lower or equal: No way
    OInventory::log(3,
      "getFirstPosAfterValue: Last is lower or equal: No way");
    return undef;
  }

  #
  # The value is greater than the first one in the array,
  #           is lower or equal than the last one in the array
  # and there's at least two points in the array
  #
  my $first  = $$values[0];
  my $last   = $$values[$#$values];
  my $diff   = $last-$first;
  my $delta  = $diff/($#$values);
  my $pos    = int(($theValue-$first)/$delta)+1;

  #
  # Some sanity checks:
  #
  if ($$values[$pos] <= $theValue) {
    OInventory::log(3, "getFirstPosAfterValue: BUG! We calculated that "
      . "the first position greater than $theValue in the array ("
      . (join ", ", @$values) . ") should be the number $pos (0..N-1), "
      . "but its value (" . $$values[$pos] . ") is not greater than $theValue");
    return undef;
  }
  if (defined($$values[$pos-1]) && defined($$values[$pos-1]) > $theValue) {
    OInventory::log(3, "getFirstPosAfterValue: BUG! We calculated that "
      . "the first position greater than $theValue in the array ("
      . (join ", ", @$values) . ") should be the number $pos (0..N-1), "
      . "but the previous value in the array (" . $$values[$pos-1] . ") "
      . "is also greater than $theValue");
    return undef;
  }

  return $pos;
}

#
# Save perf data to disk
#
# @arg array of PerfEntityMetricCSV || OMockView::OMockPerfEntityMetricCSV
# @return 1 ok, 0 errors
#
sub savePerfData {
  my $perfDataArray = shift;

  if( ! defined($perfDataArray) ) {
    OInventory::log(3, "savePerfData: expects a PerfEntityMetricCSV");
    return 0;
  }

  if( ref($perfDataArray) ne 'ARRAY') {
    OInventory::log(3, "savePerfData: Got unexpected '" . ref($perfDataArray)
                     . "' instead of ARRAY of PerfEntityMetricCSV");
    return 0;
  }

  if($#$perfDataArray == -1) {
    OInventory::log(1, "savePerfData: No PerfEntityMetricCSV received.");
    return 1;
  }


  OInventory::log(0, "Saving perf data for " . ($#$perfDataArray + 1)
                   . " PerfEntityMetricCSVs");

  foreach my $perfData (@$perfDataArray) {

    if( ref($perfData) ne 'PerfEntityMetricCSV'
     && ref($perfData) ne 'OMockView::OMockPerfEntityMetricCSV') {
      OInventory::log(3, "savePerfData: Got unexpected '" . ref($perfData)
                       . "' in the array instead of PerfEntityMetricCSV");
      return 0;
    }

    my ($folder, $vCenterFolder, $csvFolder, $basenameSeparator);
    my $sampleInfoCSV = $perfData->sampleInfoCSV;
    #  Array of OMockPerfMetricSeriesCSV objects:
    my $entityView    = $perfData->entity;
  
    #
    # Path strings for performance data were already tested
    # and folders were created at OInventory::createFoldersIfNeeded()
    #
    $folder = $OInventory::configuration{'perfdata.root'};
    $vCenterFolder     = "$folder/" . $OInventory::configuration{'vCenter.fqdn'};
    $basenameSeparator = $OInventory::configuration{'perfpicker.basenameSep'};

    #
    # TO_DO: When mocking, here we should get also a OMockManagedObjectReference
    # instead of a OMockHostView or OMockVirtualMachineView, for simplicity
    #
    my $mo_ref;
    if(ref($entityView) eq 'ManagedObjectReference'
       && $entityView->{type} eq 'HostSystem') {
      $mo_ref = $entityView->{value};
      $csvFolder = $vCenterFolder . "/HostSystem/" . $mo_ref;
    }
    elsif(ref($entityView) eq 'ManagedObjectReference'
          && $entityView->{type} eq 'VirtualMachine') {
      $mo_ref = $entityView->{value};
      $csvFolder = $vCenterFolder . "/VirtualMachine/" . $mo_ref;
    }
    elsif(ref($entityView) eq 'OMockView::OMockHostView') {
      $mo_ref = $entityView->{mo_ref}->{value};
      $csvFolder = $vCenterFolder . "/HostSystem/" . $mo_ref;
    }
    elsif(ref($entityView) eq 'OMockView::OMockVirtualMachineView') {
      $mo_ref = $entityView->{mo_ref}->{value};
      $csvFolder = $vCenterFolder . "/VirtualMachine/" . $mo_ref;
    }
    else {
      OInventory::log(3, "savePerfData: Got unexpected '" . ref($entityView)
                       . "' instead of HostSystem or VirtualMachine");
      return 0;
    }

    # Create folder if needed
    if(! -d $csvFolder) {
      OInventory::log(0, "Creating perfdata folder '$csvFolder' for "
                       . ref($entityView) . " with mo_ref $mo_ref");
      if(! mkdir $csvFolder) {
        OInventory::log(3, "Failed to create '$csvFolder': $!");
        return 0;
      }
    }

    OInventory::log(0, "Saving perf data for the " . ref($entityView)
                     . " with mo_ref='" . $mo_ref . "'");
  
    foreach my $p (@{$perfData->value}) {
      my $instance  = $p->id->instance;
      my $counterId = $p->id->counterId;
      my $value     = $p->value;
      my $csvPath   = join($basenameSeparator,
                        ($csvFolder . "/" . $mo_ref, $counterId, $instance));
      my $csvPathLatest = $csvPath . ".latest.csv";
      OInventory::log(0, "Saving in $csvPathLatest");

# print "DEBUG: ** path=$csvPath : instance='" . $instance . "',counterId='"
# . $counterId . "',value='" . substr($value, 0, 15) . "...'\n";
  
      my $timestamps = getSampleInfoArrayRefFromString($sampleInfoCSV);
      my @values = split /,/, $value;
      if($#$timestamps < 3) {
        OInventory::log(3, "Too few perf data values for mo_ref=$mo_ref"
                         . ",counterId=$counterId,instance=$instance");
        return 0;
      }
      if($#$timestamps != $#values) {
        OInventory::log(3, "Got different # of timestamps (" . ($#$timestamps + 1) 
                         . ") than values  (" . ($#values + 1) . ") for mo_ref=" 
                         . $mo_ref 
                         . ",counterId=$counterId,instance=$instance");
        return 0;
      }

      #
      # Print perf data
      #
      my $pDHandle;
      if(!open($pDHandle, ">:utf8", $csvPathLatest)) {
        OInventory::log(3, "Could not open perf data file $csvPathLatest: $!");
        return 0;
      }
  
      for(my $i = 0; $i <=$#$timestamps; $i++) {
        #
        # Oh! We realized that beause of downtimes there can be gaps and shifts,
        # we can not suppose that all there will exist all the samples
        # nor that all the samples will be exactly separated by sampleTime
        #
#       print $pDHandle                              $values[$i] . "\n";
        print $pDHandle $$timestamps[$i] . $csvSep . $values[$i] . "\n";
      }
  
      if(!close($pDHandle)) {
        OInventory::log(3, "Could not close perf data file $csvPathLatest: $!");
        return 0;
      }
      OInventory::log(0, "Perf data saved in $csvPathLatest");

      #
      # RRDB:
      #
      # * count new points
      # * If there are enough new points in 'latest' (3?):
      #   * Get the oldest points (as many as the new points)
      #   * Create a new 'hour'
      #   * Interpolate the resulting new points for the new 'day' file
      #   * Get the oldest points of the previous 'day' (as many as the new points)
      #   * Print the newest points of the previous 'day' in the new 'day' file
      #   * Print the interpolated points at the end of the new 'day file'
      # * Repeat changing 'hour'   by 'day'
      # * Repeat changing 'day'    by 'week'
      # * Repeat changing 'week'   by 'month'
      # * Repeat changing 'month'  by 'year'
      # * If all ok:
      #   * Substitute the old 'hour'  file by the new 'hour'  file
      #   * Substitute the old 'day'   file by the new 'day'   file
      #   * Substitute the old 'week'  file by the new 'week'  file
      #   * Substitute the old 'month' file by the new 'month' file
      #   * Substitute the old 'year'  file by the new 'year'  file
      #

      #
      # RRDB this file
      #
      my ($timeBefore,  $eTime);
      $timeBefore=Time::HiRes::time;
      if(! doRrdb($csvPath)) {
        OInventory::log(3, "Could not run rrdb on perf data file $csvPathLatest");
        return 0;
      }
      $eTime=Time::HiRes::time - $timeBefore;
      OInventory::log(0, "Profiling: Doing RRDB for a PerfData "
                         . "took " . sprintf("%.3f", $eTime) . " s");

      #
      # Let's register on Database that this perfData has been saved
      #
      if(! registerPerfDataSaved($p, $entityView, $timestamps, \@values)) {
        OInventory::log(3, "Errors registering that perfData was taken from " . ref($entityView)
                         . " with mo_ref '" . $entityView->value . "'");
        return 0;
      }

#     #
#     # Let's compare last value with tresholds to trigger alarms:
#     #

#     #
#     # Let's use the 2 caches:
#     #
#     # cached %allPerfMetricIds : {moref}{perfCounterId}{instance}
#     # $entityView->value $p->id->counterId $p->id->instance
#     #
#     # cached %allCounters: {$perfCounterId}
#     # $p->id->counterId
#     #

#     my $perfCounter      = $allCounters{$p->id->counterId};
#     my $pcCritThreshold  = $perfCounter->{_critThreshold};
#     my $pcWarnThreshold  = $perfCounter->{_warnThreshold};

#     my $pmi = $allPerfMetricIds{$entityView->value}{perfCounterId}{instance};
#     my $pmiCritThreshold = $pmi->{_critThreshold};
#     my $pmiWarnThreshold = $pmi->{_warnThreshold};

# my $t = "entity: " . $entityView->value . " counter " .  $p->id->counterId . " and instance " . $p->id->instance;
# # print "perfCounter = \n" . Dumper($perfCounter) . "\npmi = " . Dumper($pmi) . "\n";
# 
# if(defined($pcCritThreshold)) {
#   $t .= " pcCritThreshold = $pcCritThreshold";
# }
# if(defined($pcWarnThreshold)) {
#   $t .= " pcWarnThreshold = $pcWarnThreshold";
# }
# if(defined($pmiCritThreshold)) {
#   $t .= " pmiCritThreshold = $pmiCritThreshold";
# }
# if(defined($pmiWarnThreshold)) {
#   $t .= " pmiWarnThreshold = $pmiWarnThreshold";
# }
# # print "$t\n";
    }
  }

  return 1;
}

#
# Gets and caches global stage descriptors from configuration
#
# @return ref to array of OStageDescriptor (if ok), undef (if errors)
#
sub getStageDescriptors {
  if( ! defined ($OPerformance::stageDescriptors) ) {
    #   
    # Let's get configuration for stages first
    #
    my $namesStr        = $OInventory::configuration{'perf_stages.names'};
    my $durationsStr    = $OInventory::configuration{'perf_stages.durations'};
    my $samplePeriodstr = $OInventory::configuration{'perf_stages.sample_periods'};
  
    if ( ! defined($namesStr)        || $namesStr        eq ''
      || ! defined($durationsStr)    || $durationsStr    eq ''
      || ! defined($samplePeriodstr) || $samplePeriodstr eq '') {
      OInventory::log(3, "Bad configuration. Missing perf_stages.names, "
                       . "perf_stages.durations or perf_stages.sample_periods");
      return undef;
    }
  
    my @names         = split /;/, $namesStr;
    my @durations     = split /;/, $durationsStr;
    my @samplePeriods = split /;/, $samplePeriodstr;
  
    if($#names <= -1) {
      OInventory::log(3, "Bad configuration. "
                       . "Can't get the number of stage names");
      return undef;
    }
  
    if(   $#names != $#durations
       || $#names != $#samplePeriods) {
      OInventory::log(3, "Bad configuration. Different number of stages for "
                       . "perf_stages.names, perf_stages.durations "
                       . "or perf_stages.sample_periods");
      return undef;
    }
  
    #
    # Trick needed for running correctly just one loop for all stages
    # It's better to hardcode it instead of putting it in configuraiton
    #
    my %args = (
         name         => "latest",
         duration     => "3600",
         samplePeriod => "20",
      );
    my $stage = OStageDescriptor->new(\%args);
    push @$OPerformance::stageDescriptors, $stage;
    OInventory::log(0, "Loaded global stage descriptor          : $stage");
  
    for (my $iStage = 0; $iStage <= $#names; $iStage++) {
      %args = (
         name         => $names[$iStage],
         duration     => $durations[$iStage],
         samplePeriod => $samplePeriods[$iStage],
      );
      $stage = OStageDescriptor->new(\%args);
      push @$OPerformance::stageDescriptors, $stage;
      OInventory::log(0, "Loaded global stage descriptor from conf: $stage");
    }
  }
  return $OPerformance::stageDescriptors;
}


#
# Gets stage values and descriptors for a metric, by prefix
#
# @arg prefix
#        (ex.: /var/lib/.../host-45256/host-45256___240___DISKFILE )
# @return ref to array of OStage (if ok), undef (if errors)
#
sub getConcreteStages {
  my $prefix = shift;
  my @r;

  if( ! defined ($prefix) ) {
    OInventory::log(3, "Bug: Missing prefix argument at getConcreteStages");
    return undef;
  }
  if( $prefix eq '' ) {
    OInventory::log(3, "Bug: Empty prefix argument at getConcreteStages");
    return undef;
  }

  my $stageDescriptors = OPerformance::getStageDescriptors();
  if( ! defined($stageDescriptors) ) {
    OInventory::log(3, "Can't get global stage descriptors from configuration");
    return undef;
  }

  for (my $iStage = 0; $iStage <= $#$stageDescriptors; $iStage++) {
    my $filename       = $prefix . "."
                       . $$stageDescriptors[$iStage]->{name} . ".csv";
    #
    # Default values meaning 'stage without data perf file' (beginning)
    #
    my $values         = [];
    my $timestamps     = [];
    my $timestamp      = -1;
    my $lastTimestamp  = -1;

    if(! -e $filename) {
      OInventory::log(1, "RRDB: stage file '" . $filename . " doesn't exist. "
                       . "Probably it's a recent installation "
                       . "with just a few points. Isn't?");
    }
    else {
      #
      # Let's read perf data on a file of a stage of a metric
      #
      ($timestamps, $values) = getPerfDataFromFile($filename);

      #
      # Post-conditions, sanity checks
      #
      if ( ! defined($timestamps) || ! defined($values) ) {
        OInventory::log(3, "Undefined perf data $$stageDescriptors[$iStage] "
                         . "from perf data stage file '$filename'");
        return undef;
      }
      if ( ref($timestamps) ne 'ARRAY' ) {
        OInventory::log(3, "BUG: Getting perf data $$stageDescriptors[$iStage] "
                         . "from perf data stage file '$filename': "
                         . "timestamps is not an array");
        return undef;
      }
      if ( ref($values) ne 'ARRAY' ) {
        OInventory::log(3, "BUG: Getting perf data $$stageDescriptors[$iStage] "
                         . "from perf data stage file '$filename': "
                         . "values is not an array");
        return undef;
      }
      if ( $#$timestamps == -1 ) {
        #
        # We'll not trigger error, just move next
        #
        OInventory::log(2, "Empty $$stageDescriptors[$iStage] "
                         . "from perf data stage file '$filename'");
        next;
      }

      #
      # Let's save the handy short cuts
      #
      $timestamp     = $$timestamps[0];
      $lastTimestamp = $$timestamps[$#$timestamps];
    }

    my %args = (
         descriptor    => $$stageDescriptors[$iStage],
         numPoints     => $#$timestamps + 1,
         values        => $values,
         timestamps    => $timestamps,
         timestamp     => $timestamp,
         lastTimestamp => $lastTimestamp,
         filename      => $filename,
      );
    my $stage = OStage->new(\%args);
    if( ! defined($stage) ) {
      OInventory::log(3, "Can't create a new OStage for file '$filename' "
                       . "and descriptor $$stageDescriptors[$iStage]");
      return undef;
    }
    push @r, $stage;
    OInventory::log(0, "Loaded stage: $stage");
  }
  return \@r;
}
 

#
# Runs a RRDB algorythm for a perf data file.
#
# It allows to have a fixed size for the complete perf data files.
#
# @arg path to CSV file to be rrdb'ed
# @return 1 ok, 0 errors
#
sub doRrdb {
  my $prefix = shift;

  #
  # Now let's get the concrete stage descriptors for this metric
  #
  my $stages = getConcreteStages($prefix);
  if( ! defined ($stages) ) {
    OInventory::log(3, "Can't get the concrete stage descriptors from $prefix");
    return 0;
  }
  if( $#$stages == -1 ) {
    OInventory::log(3, "Can't get any concrete stage descriptor from $prefix");
    return 0;
  }

  #
  # Now let's run RRDB for each stage:
  #
  # Will not run for first component ('latest'),
  # this stage is just a feeder for 'hour'
  #

  #
  # We don't begin feeding at iStage=0 component
  # because it's for 'latest', got from vCenter, a 'virtual stage'
  #
  for (my $iStage = 1; $iStage <= $#$OPerformance::stageDescriptors; $iStage++) {

    OInventory::log(0, "Running RRDB for stage '"
                     . $$stages[$iStage]->{descriptor}->{name} . "'");

    my ($timeBefore,  $eTime);
    $timeBefore=Time::HiRes::time;
    my $r = shiftPointsToPerfDataStage($iStage, $stages);
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(0, "Profiling: Running RRDB on stage '"
                       . $$stages[$iStage]->{descriptor}->{name}
                       . "' took " . sprintf("%.3f", $eTime) . " s");

    if( $r ) {
      OInventory::log(0, "Pushed and popped $r points to stage '"
                       . $$stages[$iStage]->{descriptor}->{name} . "'");
    }
    else {
      #
      # It will not be usual for the early stages (hour=>day)
      # but it will be usual for the later stages (month=>year)
      #
      OInventory::log(0, "There are no points to push and pop to stage '"
                       . $$stages[$iStage]->{descriptor}->{name} . "'");
      next;
    }
  }

  return 1;
}


# #
# # Gets the new timestamps and values
# # but padding with one (curr)samplePeriod before the (curr)first
# # and after the (curr)last points from previous stages
# #
# # To calculate each point we need the points from upper stages between
# # the previous sample and the posterior sample in this stage.
# #
# # @arg the current stage number
# # @arg ref to the array of stages. The prev arg sets which is the current one
# # @return ref to the array of timestamps
# #
# sub getNewPoints {
#   my $currStagePos = shift;
#   my $stages       = shift;
#   my @newTimestamps;
#   my @newValues;
# 
#   my $currTimestamp     = $$stages[$currStagePos]->{timestamp};
#   my $currLastTimestamp = $$stages[$currStagePos]->{lastTimestamp};
#   my $currSamplePeriod  = $$stages[$currStagePos]->{descriptor}->{samplePeriod};
#   for (my $iStage = 0; $iStage < $currStagePos; $iStage++) {
# 
# #   DEBUG !! #
# print "DEBUG, be carefull !!!\n";
# $$stages[$iStage]->{timestamp}     = 1114099;
# $$stages[$iStage]->{lastTimestamp} = 1505114099;
# $$stages[$iStage]->{timestamps}    = [1114099, 1505114079, 1505114089, 1505114099];
# $$stages[$iStage]->{values}        = [3, 5, 7, 9];
# $$stages[$iStage]->{numPoints}     = 4;
# $currTimestamp     = 105100079;
# print "DEBUG !!!\n";
# # / DEBUG !! #
# 
# 
#     my $iTimestamp     = $$stages[$iStage]->{timestamp};
#     my $iLastTimestamp = $$stages[$iStage]->{lastTimestamp};
#     OInventory::log(0, "Looking for points for the stage $currStagePos "
#                      . "from the stage $iStage: currTimestamp=$currTimestamp,currSamplePeriod=$currSamplePeriod,iTimestamp=$iTimestamp,iLastTimestamp=$iLastTimestamp");
# print("DEBUG: Looking for points for the stage $currStagePos "
#                      . "from the stage $iStage: currTimestamp=$currTimestamp,currLastTimestamp=$currLastTimestamp,currSamplePeriod=$currSamplePeriod iTimestamp=$iTimestamp,iLastTimestamp=$iLastTimestamp\n");
#     #
#     # To interpolate accordingly, iStage should have points:
#     # * at least one currSamplePeriod before the currTimestamp
#     # * at least one currSamplePeriod after the currTimestamp
#     #
#     # Points from: iStage 
#     # * >= $currLastTimestamp
#     # * width at least 2 * currSamplePeriod
#     #
# 
#     # 'Are there at least iPoints for 3 new currPoints?' condition
#     if($iLastTimestamp >= $currTimestamp - $currSamplePeriod) {
#       my $iStageFstPos = getPositionOfFirstValueGreater(
#                            $currTimestamp - $currSamplePeriod,
#                            $$stages[$iStage]->{timestamps},
#                            1
#                          );
#       my $iStageLastPos = $$stages[$iStage]->{numPoints};
# 
#       #
#       # iPoints width:
#       # * >= 2 * currSamplePeriod
#       # * <= currMaxDuration
#       #
#       for(my $i = $iStageFstPos; $i < $iStageLastPos; $i++) {
#         push @newTimestamps, @{$$stages[$iStage]->{timestamps}}[$i];
#         push @newValues,     @{$$stages[$iStage]->{values}}[$i];
#       }
#       last; # enough!
#     }
#   }
#   return (undef, undef);
# }


#
# Returns the value for a timestamp if exists
#
# @arg ref to array of timestamps
# @arg ref to array of values
# @arg timestamp to look for
# @return the value (if ok), undef (if err or doesn't exist)
#
sub getValueForTimestamp {
  my $timestamps = shift;
  my $values     = shift;
  my $timestamp  = shift;
  if(ref($timestamps) ne 'ARRAY') {
    OInventory::log(3, "getValueForTimestamp: 1st arg must be an array "
                     . "and is a " . ref($timestamps));
    return undef;
  }
  if(ref($values) ne 'ARRAY') {
    OInventory::log(3, "getValueForTimestamp: 2nd arg must be an array "
                     . "and is a " . ref($values));
    return undef;
  }
  if(! defined ($timestamp) || ! looks_like_number($timestamp)) {
    OInventory::log(3, "getValueForTimestamp: 3rd arg must be an number");
    return undef;
  }
  for (my $i = 0; $i <= $#$timestamps; $i++) {
    if ($$timestamps[$i] == $timestamp) {
      # Bingo!
      return $$values[$i];
    }
  }
  return undef;
}


#
# Tells how many points are there (with defined values) in the interval
#
# It's a half-open interval ( [a, b) ) == left-closed and right-open
#
# If an abscise is contained in the interval, but it's corresponding ordinate
# is not defined (empty perfData is going to happen on downtimes),
# then it's not considered to be a contained point.
#
# @arg ref to array of x
# @arg ref to array of y
# @arg left  boundary
# @arg right boundary
# @return number of points contained in interval (if it contains)
#               (so, it will be 0 if doesn't contain points),
#               || undef (if errors)
#
sub numPointsInInterval {
  my $x = shift;
  my $y = shift;
  my $a = shift;
  my $b = shift;
  my $r = 0;

  if(! defined($x) || ! defined($y) || ! defined($a) || ! defined($b)) {
    OInventory::log(3, "numPointsInInterval: missing params");
    return -1;
  }
  if(ref($x) ne 'ARRAY') {
    OInventory::log(3, "numPointsInInterval 1st param must be a ref to x. "
                     . "Is a '" . ref($x) . "'");
    return undef;
  }
  if(ref($y) ne 'ARRAY') {
    OInventory::log(3, "numPointsInInterval 2nd param must be a ref to x. "
                     . "Is a '" . ref($y) . "'");
    return undef;
  }
  if( ! looks_like_number($a)) {
    OInventory::log(3, "numPointsInInterval 3rd param must be a number ($a)");
    return undef;
  }
  if( ! looks_like_number($b)) {
    OInventory::log(3, "numPointsInInterval 4th param must be a number ($b)");
    return undef;
  }

  my $firstPosAfterA =
    getPositionOfFirstAbscissaGreaterWithDefinedOrdinate(
      $a,
      $x,
      $y,
      1
    );
  if(! defined($firstPosAfterA)) {
    return undef;
  }
  if($firstPosAfterA == -1) {
    return 0;
  }
  if ( $$x[$firstPosAfterA] >= $b ) {
    return 0;
  }
  for(my $i = $firstPosAfterA; $i <= $#$x; $i++) {
    if ( defined($$x[$i]) ) {
      if ( $$x[$i] < $b ) {
        $r++;
      }
      else {
        # There's no sense to look further
        last;
      }
    }
  }

# print "DEBUG: numPointsInInterval returns: firstPosAfterA=$firstPosAfterA , "
#       . "r=$r points that are ($a <= point < $b)\n";
  return $r;
}



#
# Interpolate a value for a timestamp based on the values on previous stages.
# It uses the values in the first (fresher, from 'latest' upwards) stage
# with data all along its two surrounding (currStage)Samples:
# * one value before the previous (currStage)Sample
# * and one value after the posterior (currStage)Sample
#
# @arg the timestamp to interpolate
# @arg ref to the array of OStage objects (0 == 'latest')
# @arg position in the stage array of the one to which we are estimating
# @return the value (if ok), undef (if errors or there are not previous points)
#
sub interpolateFromPrevStages {
  my $timestamp      = shift;
  my $stages         = shift;
  my $currStagePos   = shift;
  my @cachedSplines;
  #
  # In a future we may accept partial stages...
  #
  # my @partialStages = ();

  if( ! looks_like_number($timestamp)) {
    OInventory::log(3, "interpolateFromPrevStages "
                     . "1st param must be a number ($timestamp)");
    return undef;
  }
  if(ref($stages) ne 'ARRAY') {
    OInventory::log(3, "interpolateFromPrevStages "
                     . "2nd param must be a ref to stages. "
                     . "Is a '" . ref($stages) . "'");
    return undef;
  }
  if( ! looks_like_number($currStagePos)) {
    OInventory::log(3, "interpolateFromPrevStages "
                     . "3rtd param must be a number ($currStagePos)");
    return undef;
  }

  my $currStageSampPeriod = $$stages[$currStagePos]->{descriptor}->{samplePeriod};

  for (my $iStage = 0; $iStage < $currStagePos; $iStage++) {
    #
    # In a future we may accept partial stages...
    #
    # $partialStages[$iStage] = 0; # Just an initiallization
    #

    #
    # By now we'll accept to interpolate from the first stage that has points in
    #  the three currSamplePeriods between -2*currSamplePeriod and 
    # +2*currSamplePeriod around the timestamp. This will allow us to ensure 
    # that that stage has points all along 
    # -1*currSamplePeriod and +1*currSamplePeriod
    #
    my $numPoints2SampsBefore
         = numPointsInInterval(
             $$stages[$iStage]->{timestamps},
             $$stages[$iStage]->{values},
             $timestamp - 2*$currStageSampPeriod,
             $timestamp -   $currStageSampPeriod);
    #
    # In a future we may accept partial stages...
    #
    # my $numPoints1SampBefore
    #      = numPointsInInterval(
    #          $$stages[$iStage]->{timestamps},
    #          $$stages[$iStage]->{values},
    #          $timestamp - $currStageSampPeriod,
    #          $timestamp                         );
    # my $numPoints1SampAfter
    #      = numPointsInInterval(
    #          $$stages[$iStage]->{timestamps},
    #          $$stages[$iStage]->{values},
    #          $timestamp                         ,
    #          $timestamp +   $currStageSampPeriod);
    my $numPoints2SampsAfter
         = numPointsInInterval(
             $$stages[$iStage]->{timestamps},
             $$stages[$iStage]->{values},
             $timestamp +   $currStageSampPeriod,
             $timestamp + 2*$currStageSampPeriod);

# print "DEBUG: numPoints2SampsBefore=$numPoints2SampsBefore, numPoints2SampsAfter=$numPoints2SampsAfter\n";

    if (    defined($numPoints2SampsBefore) && $numPoints2SampsBefore > 0
         && defined($numPoints2SampsAfter)  && $numPoints2SampsAfter  > 0 ) {
      #
      # We can assure that this is the correct stage to get points from
      # Still there may be gaps because of operational problems on vCenter,
      # but if you can find points just before the previous sample
      # and just after the posterior sample, then it's your stage.
      #
      if( ! defined ($cachedSplines[$iStage]) ) {
        #
        # If seems a good idea to cache splines
        #
        my ($cx, $cy) = getClearedFunction($$stages[$iStage]->{timestamps},
                                           $$stages[$iStage]->{values});
# print "DEBUG: there were " . ($#{$$stages[$iStage]->{timestamps}} + 1). " components and getClearedFunction returned " . ($#$cx + 1) . " components\n";
        my $spline = Math::Spline->new($cx,$cy);
        $cachedSplines[$iStage] = $spline;

# print "DEBUG: values = " . points2string($cx,$cy) . "\n";
      }
      my $y_interp=$cachedSplines[$iStage]->evaluate($timestamp);
# print "DEBUG: interpolation for $timestamp = $y_interp\n";
      return $y_interp;
    }
    #
    # In a future we may accept partial stages...
    #
    # elsif ( defined($numPoints1SampBefore) && $numPoints1SampBefore >= 0
    #         defined($numPoints1SampAfter)  && $numPoints1SampAfter  >= 0) {
    #   #
    #   # It's a partial stage
    #   #
    #   $partialStages[$iStage] = 1;
    # }

  }
  return undef;
}

#
# Print to a string an array of abscissa/ordinate points, for debugging purposes
#
# @arg ref to abscissa array
# @arg ref to ordinate array
# @return string with the points
#
sub points2string { 
  my $cx = shift;
  my $cy = shift;
  return if ( ! defined ($cx) );
  return if ( ! defined ($cy) );
  return if ( ref($cx) ne 'ARRAY');
  return if ( ref($cy) ne 'ARRAY');
  my $r = 'Array of ' . ($#$cx + 1) . " points:\n";
  for (my $i = 0 ; $i <= $#$cx ; $i++) {
    $r .= "(" . $$cx[$i] . "," .  $$cy[$i] . ")\n";
  }
  return $r;
}

#
# Gets abscissas and ordinates array and return them after dropping points
# with undefined corresponding ordinates
#
# @arg ref to abscissas array
# @arg ref to ordinates array
# @return array containing ref to new abscissas and ref to new ordinates (if ok), or undef (if error)
#
sub getClearedFunction {
  my $x = shift;
  my $y = shift;
  my @cx;
  my @cy;

  if(ref($x) ne 'ARRAY') {
    OInventory::log(3, "getClearedFunction "
                     . "1st param must be a ref to abscissas. "
                     . "Is a '" . ref($x) . "'");
    return undef;
  }
  if(ref($y) ne 'ARRAY') {
    OInventory::log(3, "getClearedFunction "
                     . "2nd param must be a ref to ordinates. "
                     . "Is a '" . ref($y) . "'");
    return undef;
  }
  if($#$x != $#$y) {
    OInventory::log(3, "getClearedFunction: "
                     . "x and y arrays must have equal length");
  }
  for(my $i = 0 ; $i <= $#$x; $i++) {
    if(defined($$y[$i])) {
      my $val = $$y[$i];
      if(looks_like_number($val)) {
        push @cx, $$x[$i];
        push @cy, $val;
      }
    }
  }
  return (\@cx, \@cy);
}

#
# Runs a RRDB algorythm for the perf data file of a stage
#
# It allows to have a fixed size for the complete perf data files on each stage.
#
# Grabs new points by interpolating the ones that find in previous stages.
#
# Writes the changes in a new file and once ended substitutes
# the old file with the new one.
# Next stages in the RRDB loop iteration will still be reading the old data,
# because that OStage array is created (reading from perfData files)
# just once for each Metric, at the beginning of the corresponding iteration.
#
# Let's show a diagram of the algorithm used for each point:
#
# time:        |------------------------------------------------------------------------->
#
# $stage[$i-2]->{timestamp}                          x
# $stage[$i-2]->{lastTimestamp}                                                          x
# $stage[$i-2]                                                (--|--|--|--|--|--|-...-|--)
#                                                                                        |
# $stage[$i-1]->{timestamp}      x                                                       |
# $stage[$i-1]->{lastTimestamp}                                      x                   |
# $stage[$i-1]                               (-----|----...----|-----)                   |
# $newPoints[..]                                                           |-----|-----|xxxxxX
#            
# $stage[$i]->{lastTimestamp}                             x
# $stage[$i]:                     (-------|-------|-------)
#
# $stage[$i-2] Points between previous and next samples                      |--|--|--|
# $newPoints[0]                                                                  |
#
# $stage[$i-2] Points between previous and next samples                |--|--|--|
# $newPoints[1]                                                            |
#
# @arg position of the stage to RRDB on the OStage array
# @arg ref to array of OStage objects
# @return number of points inserted (if ok), undef (if errors)
#
sub shiftPointsToPerfDataStage {

#
# time:        |------------------------------------------------------------------------->
#
# absolute last timestamp for these stages                                               x
# $stage[$i-2]->{timestamp}                                   x                          |
# $stage[$i-2]->{lastTimestamp}                               |                          x
# $stage[$i-2]                                                (--|--|--|--|--|--|-...-|--)
#                                                                                        |
# $stage[$i-1]->{timestamp}                  x                                           |
# $stage[$i-1]->{lastTimestamp}              |                       x                   |
# $stage[$i-1]                               (-----|----...----|-----)                   |
# $stage[$i-2] Points to calculate new points                          (--|--|--|-...-)
# $newPoints[$i-1]                                                         |-----|xxxxxXxxxxxX
# $newPoints[$i-1] last (will not be calculated)                                       x
# $newPoints[$i-1] penultimate (will be calculated)                              x
#            
# $stage[$i]->{timestamp}         x
# $stage[$i]->{lastTimestamp}     |                       x
# $stage[$i]:                     (-------|-------|-------)
# $stage[$i-2] Points to calculate new points                 (--|--|--|-...-)
# $newPoints[$i]                                                  |-------|xxxxxxxXxxxxxxxX
# $newPoints[$i] penultimate (will be calculated)                         x
# $newPoints[$i] last                                                             x
#
# If $stage[$i-2] would have no points to give
# we would have got them from the next stage with points.
# Calculus done sample per sample.
#

#
# This is the algorythm that we'll follow:
#
# * get the new timestamps that should be interpolated
# * foreach timestamp:
# ** foreach previous stage, from shorter to larger 
# *** get its points between the previous timestamp and the later timestamp
# *** move to next stage if there are no points
# *** interpolate the new point using these points from previous stage
# ** if couldn't interpolate trigger error
# ** push the point
# * build the new arrays of timestamps and values
# * save the points in a new temporary file
# * mv the temporary file onto the old perfData file

  my $currStagePos = shift;
  my $stages       = shift;

  my @finalTimestamps = ();
  my @finalValues     = ();

# print "DEBUG, setting dummy perfData on line " . __LINE__ . "\n";
# $$stages[$currStagePos]->{timestamp}     = 1505709689;
# $$stages[$currStagePos]->{lastTimestamp} = 1505710169;
# $$stages[$currStagePos]->{timestamps}    = [1505709689, 1505709849, 1505710009, 1505710169];
# $$stages[$currStagePos]->{values}        = [3, 5, 7, 9];
# $$stages[$currStagePos]->{numPoints}     = 4;
# print "/DEBUG !!!\n";
# print "DEBUG: Let's plot latest:    " . points2string($$stages[0]->{timestamps},             $$stages[0]->{values}) . "\n";
# print "DEBUG: Let's plot currStage: " . points2string($$stages[$currStagePos]->{timestamps}, $$stages[$currStagePos]->{values}) . "\n";

  #
  # How many points would fit in currStage
  #  ( from last timestamp on currStage
  #  ] to the last timestamp on 'latest' stage
  #
  my $currNumNewPointsThatWouldFit
       = floor(
                (   $$stages[0]->{lastTimestamp}
                  - $$stages[$currStagePos]->{lastTimestamp}
                )
                / $$stages[$currStagePos]->{descriptor}->{samplePeriod}
              );

  #
  # "-1" because for each new currPoint we need to interpolate with points
  # between previous currSamplePeriod and posterior currSamplePeriod
  #
  my $numNewPointsFromPrevStages = $currNumNewPointsThatWouldFit - 1;

  my $currNewLastTimestamp
     = $$stages[$currStagePos]->{lastTimestamp}
       + $$stages[$currStagePos]->{descriptor}->{samplePeriod} * $numNewPointsFromPrevStages;

  if( $currNumNewPointsThatWouldFit
      > $$stages[$currStagePos]->{descriptor}->{maxPoints}) {
    $numNewPointsFromPrevStages
      = $$stages[$currStagePos]->{descriptor}->{maxPoints};
  }

  my $numNewPointsFromCurrStage =
       $$stages[$currStagePos]->{descriptor}->{maxPoints}
       - $numNewPointsFromPrevStages;

  my $s = sprintf (
          "Trying to feed the stage #%d (%s): Between latest point in currStage"
        . " (%d) and latest point on 'latest stage' (%d) in this current stage "
        . "there would fit %d current stage sample periods of %d s and last new"
        . " point will be %d. We'll keep the last %d points from current stage "
        . "we'll get next %d points interpolling from prevStages (fresher) "
        , $currStagePos, $$stages[$currStagePos]->{descriptor}->{name}
        , $$stages[$currStagePos]->{lastTimestamp}, $$stages[0]->{lastTimestamp}
        , $currNumNewPointsThatWouldFit
        , $$stages[$currStagePos]->{descriptor}->{samplePeriod}
        , $currNewLastTimestamp, $numNewPointsFromCurrStage
        , $numNewPointsFromPrevStages);

  OInventory::log(0, "$s");

  # Sanity checks
  if(   $numNewPointsFromCurrStage + $numNewPointsFromPrevStages
     != $$stages[$currStagePos]->{descriptor}->{maxPoints}) {
    OInventory::log(3,
        "Bug! numNewPointsFromCurrStage + numNewPointsFromPrevStages "
      . "($numNewPointsFromCurrStage + $numNewPointsFromPrevStages) != "
      . $$stages[$currStagePos]->{descriptor}->{maxPoints});
    return undef;
  }

  #
  # We'll iterate for each new point.
  # First we'll get the points that are just shifting from currStage
  # Then we'll get new points interpolating for the first lower
  # (fresher) stage that has points for previous
  # and posterior currStageSamplePeriods
  #
  
  for(my $i = $numNewPointsFromCurrStage - 1; $i >= 0; $i--) {
    my $preservedTimestamp = $$stages[$currStagePos]->{lastTimestamp}
       - $i * $$stages[$currStagePos]->{descriptor}->{samplePeriod};
    my $preservedValue 
       = getValueForTimestamp(
           $$stages[$currStagePos]->{timestamps}, 
           $$stages[$currStagePos]->{values},
           $preservedTimestamp
         );
    if ( defined $preservedValue ) {
      push @finalTimestamps, $preservedTimestamp;
      push @finalValues,     $preservedValue;
# print "DEBUG: preserved: ($preservedTimestamp, $preservedValue)\n";
    }
    else {
      #
      # A gap in perfData is not an error itself.
      # It can happen because of downtimes in this software, in vCenter, ...
      #
      OInventory::log(1, "Gap in perfData at $preservedTimestamp");
      push @finalTimestamps, $preservedTimestamp;
      push @finalValues, '';
# print "DEBUG: preserved: ($preservedTimestamp, '')\n";
    }
  }
  for (my $i = $numNewPointsFromPrevStages - 1; $i >= 0 ; $i--) {
    my $newTimestamp = $currNewLastTimestamp - $i * $$stages[$currStagePos]->{descriptor}->{samplePeriod};;
    my $newValue = interpolateFromPrevStages($newTimestamp, $stages, $currStagePos);
    push @finalTimestamps, $newTimestamp;
    push @finalValues,     $newValue;
  }

  #
  # Now we have all the points to be saved on
  # current stage $$stages[$currStagePos] . Let's save them:
  #
  my $perfDataFilename = $$stages[$currStagePos]->{filename};
  my $tmpFile          = $perfDataFilename  . ".rrdb_running";
  OInventory::log(0, "Saving RRDB'ed perf data in temporary file $tmpFile");

  if($#finalTimestamps != $#finalValues) {
    OInventory::log(3, "Got different # of timestamps (" . ($#finalTimestamps + 1)
                     . ") than values  (" . ($#finalValues + 1) . ")");
    return undef;
  }

  #
  # Print perf data
  #
  my $pDHandle;
  if(!open($pDHandle, ">:utf8", $tmpFile)) {
    OInventory::log(3, "Could not open tmp perf data file $tmpFile: $!");
    return undef;
  }

  for(my $i = 0; $i <= $#finalTimestamps; $i++) {
#   print $pDHandle $finalTimestamps[$i] . $csvSep . $finalValues[$i] . "\n";
    my $val = defined($finalValues[$i]) ? $finalValues[$i] : '';
    print $pDHandle $finalTimestamps[$i] . $csvSep . $val . "\n";
  }

  if(!close($pDHandle)) {
    OInventory::log(3, "Could not close tmp perf data file $tmpFile: $!");
    return undef;
  }
  OInventory::log(0, "Perf data saved successfuly in tmp file $tmpFile");

  #
  # Let's substitute the file
  #
  if(! move($tmpFile, $perfDataFilename)) {
    OInventory::log(3, "Can't move the new perf data file $tmpFile "
                     . "into $perfDataFilename: $!");
    return undef;
  }
  return $#finalTimestamps + 1;

}

#
# Get the position of the first value of an array of values (abscissa) greater
# than a value and that has defined values in it's functions array (ordinate)
#
# @arg limit, the value to look for
# @arg reference to the array of abscissas
# @arg reference to the array of ordinates
# @arg (optional) 0 == just if greater (default), 1 == if greater or equal
# @return the position (if ok), -1 (if not found), undef (if error)
#
sub getPositionOfFirstAbscissaGreaterWithDefinedOrdinate {
  my $limit  = shift;
  my $x      = shift;
  my $y      = shift;
  my $ge     = shift;
  $ge        ||= 0;

  if( ! looks_like_number($limit)) {
    OInventory::log(3, "gpofagwdo: "
                     . "1st param must be a number ($limit)");
    return undef;
  }

  if(ref($x) ne 'ARRAY') {
    OInventory::log(3, "gpofagwdo: "
                     . "2nd param must be a ref to vals (x). "
                     . "Is a '" . ref($x) . "'");
    return undef;
  }

  if(ref($y) ne 'ARRAY') {
    OInventory::log(3, "gpofagwdo: "
                     . "3rd param must be a ref to vals (y). "
                     . "Is a '" . ref($y) . "'");
    return undef;
  }
  if($#$x != $#$y) {
    OInventory::log(3, "gpofagwdo: "
                     . "x and y arrays must have equal length");
  }

  for (my $i = 0; $i <= $#$x; $i++ ) {
    if($ge == 1) {
# print "gpofagwdo: [$i]=" . $$x[$i] . " (limit=$limit)\n";
      return $i if($$x[$i] >= $limit && defined($$y[$i]));
    }
    else {
# print "gpofagwdo: [$i]=" . $$x[$i] . " (limit=$limit)\n";
      return $i if($$x[$i] >  $limit && defined($$y[$i]));
    }
  }
  return -1;
}


#
# Get the position of the first value of an array greater than a value
#
# @arg limit, the value to look for
# @arg reference to the array of points
# @arg (optional) 0 == just if greater (default), 1 == if greater or equal
# @return the position (if ok), -1 (if not found), undef (if error)
#
sub getPositionOfFirstValueGreater {
  my $limit  = shift;
  my $points = shift;
  my $ge     = shift;
  $ge        ||= 0;

  if( ! looks_like_number($limit)) {
    OInventory::log(3, "getPositionOfFirstValueGreater "
                     . "1st param must be a number ($limit)");
    return undef;
  }

  if(ref($points) ne 'ARRAY') {
    OInventory::log(3, "getPositionOfFirstValueGreater "
                     . "2nd param must be a ref to points. "
                     . "Is a '" . ref($points) . "'");
    return undef;
  }

  for (my $i = 0; $i <= $#$points; $i++ ) {
    if($ge == 1) {
      return $i if($$points[$i] >= $limit);
    }
    else {
      return $i if($$points[$i] > $limit);
    }
  }
  return -1;
}


#
# Get the second half of an array, from the component that equals to certain value.
#
# @arg limit, the value to look for
# @arg reference to the array of points
# @return a ref to the array (if ok), undef (if error)
#
sub getValueAndGreater {
  my $limit  = shift;
  my $points = shift;
  my @r;

  if( ! looks_like_number($limit)) {
    OInventory::log(3, "getValueAndGreater 1st param must be a number ($limit)");
    return undef;
  }

  if(ref($points) ne 'ARRAY') {
    OInventory::log(3, "getValueAndGreater 2nd param must be a ref to points. "
                     . "Is a '" . ref($points) . "'");
    return undef;
  }

  my $found = 0;
  foreach my $point (@$points) {
    if($found != 1 && $point == $limit) {
      $found = 1;
    }
    if($found) {
      push @r, $point;
    }
  }
  return \@r;
}

#
# Get performance data from a perf data file
#
# @arg filename
# @return {\@timestamps,\@values} (if ok), undef errors (if errors)
#           where:
#             @timestamps : timestamps in epoch
#             @values     : values
#
sub getPerfDataFromFile {
  my $filename = shift;
  my @timestamps;
  my @values;

  OInventory::log(0, "Reading perfData from file '$filename'");
  if(! defined($filename)) {
    OInventory::log(3, "Missing filename argument to get PerfData from file");
    return undef;
  }

  #
  # Let's open the file
  #
  my $handler;
  if( ! open($handler, "<", $filename) ) {
    OInventory::log(3, "Can't open perf data file '$filename': $!");
    return undef;
  }

  #
  # Let's read the file
  #
  while (my $line = <$handler>) {
    chomp $line;
    next if $line =~ /^\s*$/; # empty
    next if $line =~ /^\s*#/; # comment, somehow

    my ($t, $v) = split(/$csvSep/, $line, 2);
    if (! defined($t) || ! defined($v)) {
      OInventory::log(3, "Can't parse the line '$line' from '$filename'");
      return undef;
    }
    if ( $t eq '') {
      OInventory::log(3, "Empty timestamp in line '$line' from '$filename'");
      return undef;
    }
#   if ( $v eq '') {
#     # We'll not stop parsing
#     OInventory::log(2, "Empty value in line '$line' from '$filename'");
#   }
    if( ! looks_like_number($t)) {
      OInventory::log(3, "Unknown timestamp in line '$line' from '$filename'");
      return undef;
    }
    if($v ne '' && ! looks_like_number($v)) {
      # We'll not stop parsing
      # Must we log Error or Warning ... ?
      OInventory::log(2, "Unknown value in line '$line' from '$filename'");
      next;
    }

    push @timestamps, $t;
    push @values,     $v;
  }

  #
  # Let's close the file
  #
  if( ! close($handler) ) {
    OInventory::log(3, "Can't close perf data file '$filename': $!");
    return undef;
  }

  #
  # Sanity check.
  # It should never happen, but...
  #
  if ($#timestamps != $#values) {
    OInventory::log(3, "Got different number of timestamps ($#timestamps) than "
                     . "values ($#values) from perf data file '$filename': $!");
    return undef;
  }

  return ( \@timestamps, \@values );
}
 

#
# Get array of timestamps from a "sampleInfoCSV" string
#
# Gets a string like '20,2017-08-20T07:52:00Z,20,2017-08-20T07:52:20Z,20,...'
# and returns a ref to an array like 'epoch0,epoch1,...',
# where each epoch is the timestamp converted to epoch
#
# @arg a string like '20,2017-08-20T07:52:00Z,20,2017-08-20T07:52:20Z,20,...'
# @return a ref to an array like 'epoch0,epoch1,...',
#         where each epoch is the timestamp converted to epoch
#
sub getSampleInfoArrayRefFromString {
  my $rawSampleInfoStrRef = shift;
  my @sampleInfoArray = ();
  my @tmpArray = split /,/, $rawSampleInfoStrRef;
  for my $i (0 .. $#tmpArray) {
    if ($i % 2) {
      # 2017-07-20T05:49:40Z
      $tmpArray[$i] =~ s/Z$/\+0000/;
      my $t = Time::Piece->strptime($tmpArray[$i], "%Y-%m-%dT%H:%M:%S%z");
      push @sampleInfoArray, $t->epoch;
    }
  }
  return \@sampleInfoArray;
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

  if(OvomDao::connected() != 1) {
    OInventory::log(3, "Must be previously correctly connected to Database");
    return 0;
  }

  #
  # Get perfManager
  #
  OInventory::log(0, "Let's get perfManager");
  $timeBefore=Time::HiRes::time;
  $perfManager=getPerfManager();
  if( ! defined($perfManager) ) {
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

  #
  # Let's generate an entity list to get their perf on a loop
  #
  my @entities;
  foreach my $aVM (@{$OInventory::inventory{'VirtualMachine'}}) {
    push @entities, $aVM;
  }
  foreach my $aHost (@{$OInventory::inventory{'HostSystem'}}) {
    push @entities, $aHost;
  }

  $timeBeforeB=Time::HiRes::time;
# foreach my $aVM (@{$OInventory::inventory{'VirtualMachine'}}) 
  foreach my $aEntity (@entities) {
    my ($timeBefore, $eTime);
    my $availablePerfMetricIds;
    my $filteredPerfMetricIds;
    my $desiredGroupInfo;

    #
    # Let's check if we are signaled to stop
    #
    if(OInventory::askedToStop()) {
      OInventory::log(2, "We must stop. Let's finish. ");
      #
      # Let's create the flag file again, for the main loop to realize about
      # this signal without having to change the return value of this function.
      #
      my $file = $OInventory::configuration{'signal.stop'};
      my $hndl;
      if(!open($hndl, ">:utf8", $file)) {
        OInventory::log(3, "Can't touch again the signal file $file: $!");
        return 0;
      }
      if(!close($hndl)) {
        OInventory::log(3, "Can't close the signal file $file: $!");
        return 0;
      }
      return 1;
    }



    # TO_DO : code cleanup: move it to a getAvailablePerfMetric function


    #
    # Query available PerfMetrics
    #
    OInventory::log(0, "Let's queryAvailablePerfMetric");
    eval {
      local $SIG{ALRM} = sub { die "Timeout calling QueryAvailablePerfMetric" };
      my $maxSecs = $OInventory::configuration{'api.timeout'};
      OInventory::log(0, "Calling QueryAvailablePerfMetric, "
                       . "with a timeout of $maxSecs seconds");
      alarm $maxSecs;
      $timeBefore=Time::HiRes::time;
      $availablePerfMetricIds =
        $perfManager->QueryAvailablePerfMetric(entity => $aEntity->{view});
      $eTime=Time::HiRes::time - $timeBefore;
      alarm 0;
      OInventory::log(1, "Profiling: Calling QueryAvailablePerfMetric took "
                         . sprintf("%.3f", $eTime) . " s");
    };
    if ($@) {
      alarm 0;
      if ($@ =~ /Timeout calling QueryAvailablePerfMetric/) {
        OInventory::log(3, "Timeout! perfManager->QueryAvailablePerfMetric "
                         . "did not respond in a timely fashion: $@");
        return 0;
      } else {
        OInventory::log(3, "perfManager->QueryAvailablePerfMetric failed: $@");
        return 0;
      }
      if(! --$maxErrs) {
        OInventory::log(3, "Too many errors when getting performance from "
                         . "vCenter. We'll try again on next picker's loop");
        return 0;
      }
      next;
    }

    OInventory::log(0, "Available PerfMetricIds for $aEntity:");
    foreach my $pMI (@$availablePerfMetricIds) {
      OInventory::log(0, " * PerfMetricId: {"
                       . "counterId='" . $pMI->counterId . "', "
                       . "instance='"  . $pMI->instance  . "'}");
    }

    #
    # Get the desired group info for that entity (groups of PerfMetrics)
    #
    $desiredGroupInfo = getDesiredGroupInfoForEntity($aEntity);
    if(!defined($desiredGroupInfo) || $#$desiredGroupInfo == -1) {
      OInventory::log(2, "There are not desired groupInfo of perfCounters "
                       . "configured for this entity. Review configuration.");
      next;
    }
    my $txt = join ", ", @$desiredGroupInfo;
    OInventory::log(0, "There are " . ($#$desiredGroupInfo + 1) . " desired "
                     . "groupInfo of perfCounters configured "
                     . "for this entity: $txt");

    #
    # Get the subset of available PerfMetrics that are configured as 'desired'
    #
    $timeBefore=Time::HiRes::time;
    $filteredPerfMetricIds = filterPerfMetricIds($aEntity->{mo_ref}, $desiredGroupInfo,
                                                 $availablePerfMetricIds);

    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(1, "Profiling: Filtering PerfMetricIds took "
                       . sprintf("%.3f", $eTime) . " s");

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
    OInventory::log(0, "Profiling: Let's call getPerfQuerySpec");
    $timeBefore=Time::HiRes::time;
    my $perfQuerySpec = getPerfQuerySpec(entity     => $aEntity->{view},
                                         metricId   => $filteredPerfMetricIds,
                                         format     => 'csv',
                                         intervalId => 20); # 20s hardcoded
    $eTime=Time::HiRes::time - $timeBefore;
    alarm 0;
    OInventory::log(1, "Profiling: Calling getPerfQuerySpec took "
                       . sprintf("%.3f", $eTime) . " s");

    if(! defined($perfQuerySpec)) {
      OInventory::log(3, "Could not get QuerySpec for entity");
      next;
    }
    if($#{$perfQuerySpec->metricId} == -1) {
      OInventory::log(2, "QuerySpec contains no metricIds for a non-empty "
                       . "array of filteredPerfMetricIds. Why?");
      next;
    }

    #
    # Finally let's get perfData
    #
    # PerfEntityMetricCSV || OMockView::OMockPerfEntityMetricCSV
    #
    $timeBefore=Time::HiRes::time;
    my $perfData = getPerfData($perfQuerySpec);
    $eTime=Time::HiRes::time - $timeBefore;

    if(! defined($perfData)) {
      OInventory::log(3, "Could not get perfData for entity");
      next;
    }
    if( ref($perfData) ne 'ARRAY') {
      OInventory::log(3, "Got unexpected " . ref($perfData)
                       . " instead of array of PerfEntityMetricCSV for entity");
      next;
    }

    if($#$perfData == -1) {
      OInventory::log(1, "No PerfEntityMetricCSV for " . ref($aEntity) . ": "
                       . "{name='" . $aEntity->{name} . "',mo_ref='"
                       . $aEntity->{mo_ref} . "'}. Moving to next entity.");
      next;
    }

    OInventory::log(1, "Profiling: Getting latest performance for "
                     . ref($aEntity) . ": "
                     . "{name='" . $aEntity->{name} . "',mo_ref='"
                     . $aEntity->{mo_ref} . "'} took "
                     . sprintf("%.3f", $eTime) . " s");

    $timeBefore=Time::HiRes::time;

    #
    # Let's save perfData (here comes RRDB)
    # and compare with thresholds to launch alarms
    #
    if(! savePerfData($perfData)) {
      OInventory::log(3, "Errors getting latest performance from "
                       . ref($aEntity) . " with mo_ref '"
                       . $aEntity->{mo_ref} . "'");
      if(! --$maxErrs) {
        OInventory::log(3, "Too many errors trying to get performance. "
                         . " Hopefully it's a transitory downtime in "
                         . "vCenter. We'll try again on next iteration");
        return 0;
      }
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(1, "Profiling: Saving performance for "
                     . ref($aEntity) . ": "
                     . "{name='" . $aEntity->{name} . "',mo_ref='"
                     . $aEntity->{mo_ref} . "'} took "
                     . sprintf("%.3f", $eTime) . " s");
  }

  $eTimeB=Time::HiRes::time - $timeBeforeB;
  OInventory::log(1, "Profiling: Getting the whole data performance took "
                     . sprintf("%.3f", $eTimeB) . " s");

  return 1;
}

#
# Gets last performance data from hosts and VMs.
#
# It creates a new PNG file with the graph and returns its full path.
# Deleting that file is responsibility of the caller.
#
# @return path (if ok), undef (if errors)
#
sub getPathToPerfGraphFiles {
  my $type             = shift;
  my $mo_ref           = shift;
  my $fromEpoch        = shift;
  my $toEpoch          = shift;
  my $perfMetricIds    = shift;
  my $perfCounterInfos = shift;
  my $entityName = OvomDao::oClassName2EntityName($type);
  my $basenameSeparator = $OInventory::configuration{'perfpicker.basenameSep'};
  my @filenames;

  #
  # Folder for performance data
  #
  my $folder = $OInventory::configuration{'perfdata.root'}
             . "/"
             . $OInventory::configuration{'vCenter.fqdn'}
             . "/"
             . $entityName
             . "/"
             . $mo_ref;

  #
  # Let's load stage descriptors
  #
  my $sd = getStageDescriptors();
  if( ! defined ($sd) ) {
    return undef;
  }

  my $r;
  foreach my $pmi (@$perfMetricIds) {
#   $r .= "pmi = " . $pmi . "<br/>";
    my $prefix = $mo_ref . $basenameSeparator . $pmi->counterId . $basenameSeparator . $pmi->instance;
    foreach my $aSD (@$sd) {
      my $filename = $folder . "/" . $prefix . "." . $aSD->{name} . ".csv";
#     $r .= "a sd = " . $aSD->{name} . ": $filename<br/>\n";
      push @filenames, $filename;
    }
    OInventory::log(0, "Calling getOneCsvFromAllStages to generate a graph "
                     . "from $fromEpoch to $toEpoch with prefix $prefix");
    my $resultingCsvFile = getOneCsvFromAllStages($fromEpoch, $toEpoch, $prefix, \@filenames);
    if (! defined($resultingCsvFile)) {
      OInventory::log(3, "getOneCsvFromAllStages ended with errors");
      return undef;
    }
    my $pCI = $perfCounterInfos->{$pmi->counterId};
    my $description = getGraphDescription($type, $entityName, $mo_ref, $pCI);
    my $g = csv2graph($fromEpoch, $toEpoch, $resultingCsvFile);

    if (! defined($g)) {
      OInventory::log(3, "Could not generate graphs");
      return undef;
    }

    my $gu = graphPath2uriPath($g);
    my $instanceStr;
    if($pmi->instance eq '') {
      $instanceStr = '';
    }
    else {
      $instanceStr = ", instance '" . $pmi->instance . "'";
    }
    $r .= "<h4>" . $pCI->getShortDescription() . "$instanceStr</h4>\n";
    $r .= "<p><img src=\"$gu\" alt=\"$description\" border='1'/></p><hr/>\n";
  }
  return $r;
}

# sub graphPath2uriPath {
#   my $p = shift;
#   return undef if (!defined($p));
# 
#   my $graphFolderUrl = $OInventory::configuration{'web.graphs.folder'};
#   my $uriPath = $OInventory::configuration{'web.graphs.uri_path'};
# 
#   substr($p, 0, length($graphFolderUrl), $uriPath);
#   return $p;
# }

# sub getGraphDescription {
#   my $type       = shift;
#   my $entityName = shift;
#   my $mo_ref     = shift;
#   my $pCI = shift;
# 
#   return undef if(!defined $type || $type eq '');
#   return undef if(!defined $entityName || $entityName eq '');
#   return undef if(!defined $mo_ref || $mo_ref eq '');
#   return undef if(!defined $pCI);
#   return undef if(ref($pCI) eq 'OPerfCounterInfo');
# 
#   return "$type $entityName ($mo_ref): $pCI";
# }

#
# Generate a PNG graph from a CSV file
#
# @arg min epoch
# @arg max epoch
# @arg path to csv file with data
# @return the generated png graph of undef if errors
#
sub csv2graph {
  my $fromEpoch        = shift;
  my $toEpoch          = shift;
  my $csv              = shift;
  my $chart;
  my $dataSet;

  return undef if(! defined($fromEpoch) || $fromEpoch eq '');
  return undef if(! defined($toEpoch)   || $toEpoch eq '');
  return undef if(! defined($csv));
  if(! -f $csv) {
    OInventory::log(3, "csv2graph: $csv doesn't exist");
    return undef;
  }

  my $output = "$csv.png";

# my $basenameSeparator = $OInventory::configuration{'perfpicker.basenameSep'};
# my $prefix = $mo_ref . $basenameSeparator . $counterId . $basenameSeparator . $instance;
# my $output = $OInventory::configuration{'web.graphs.folder'} . "/$prefix.$fromEpoch-$toEpoch.png";

  my ($timestamps, $values) = getPerfDataFromFile($csv);

  eval {
    # Create chart object and specify the properties of the chart
    $chart = Chart::Gnuplot->new(
        output => $output,
        title  => "Title pending",
        xlabel => "x-axis label pending",
        ylabel => "y-axis label pending",
    );
    # Create dataset object and specify the properties of the dataset
    $dataSet = Chart::Gnuplot::DataSet->new(
      xdata => $timestamps,
      ydata => $values,
      title => "Plot title pending",
      style => "linespoints",
    );
    # Plot the data set on the chart
    $chart->plot2d($dataSet);
  };
  if($@) {
    OInventory::log(3, "csv2graph: Errors generating graphs for $csv: $@");
    return undef;
  }
 
  return $output;
}

#
# Creates a new temporary file and prints on it all
# the points from the files between the two epoch instants
#
# @arg lower bound in epoch
# @arg upper bound in epoch
# @arg string to identify the object (ex.: mo_ref___PerfMetricId)
# @arg reference to the array of filenames (paths)
# @arg mo_ref of the object
# @return the path of the new CSV (if ok) or undef (if errors)
#
sub getOneCsvFromAllStages {
  my $fromEpoch    = shift;
  my $toEpoch      = shift;
  my $prefix       = shift;
  my $filenamesRef = shift;
  my $outputHandler;
  my $inputHandler;
  my $linesPrinted = 0;

  my @linesToSave;

  my $csv = $OInventory::configuration{'web.graphs.folder'} . "/$prefix.$fromEpoch-$toEpoch.csv";

  if( ! open($outputHandler, ">:utf8", $csv) ) {
    OInventory::log(3, "Could not open CSV output file '$csv': $!");
    return undef;
  }

  foreach my $aPath (@$filenamesRef) {
    if( ! open($inputHandler, "<:utf8", $aPath) ) {
      OInventory::log(3, "Could not open CSV input file '$aPath': $!");
      return undef;
    }

    #
    # Let's read the file
    #
    OInventory::log(0, "getOneCsvFromAllStages is reading $aPath");
    while (my $line = <$inputHandler>) {
      chomp $line;
      next if $line =~ /^\s*$/; # empty
      next if $line =~ /^\s*#/; # comment, somehow
  
      my ($t, $v) = split(/$csvSep/, $line, 2);
      if (! defined($t) || ! defined($v)) {
        OInventory::log(3, "Can't parse the line '$line' from '$aPath'");
        return undef;
      }
      if ( $t eq '') {
        OInventory::log(3, "Empty timestamp in line '$line' from '$aPath'");
        return undef;
      }
      if( ! looks_like_number($t)) {
        OInventory::log(3, "Unknown timestamp in line '$line' from '$aPath'");
        return undef;
      }
      if($v eq '' ) {
        # Timestamp without value (missing data, network problem vCenter<=>ESXi ...)
        next;
      }
      if(! looks_like_number($v)) {
        # We'll not stop parsing
        # Must we log Error or Warning ... ?
        OInventory::log(2, "Unknown value in line '$line' from '$aPath'");
        next;
      }

      if($t >= $fromEpoch && $t <= $toEpoch) {
        push @linesToSave, $line;
      }
    }

    #
    # Let's close this stage file
    #
    if( ! close($inputHandler) ) {
      OInventory::log(3, "Could not close CSV input file '$aPath': $!");
      return undef;
    }

  }

  #
  # Let's print the choosen lines in the output file
  #
  foreach my $aLine (sort @linesToSave) {
    print $outputHandler "$aLine\n";
    $linesPrinted++;
  }

  if( ! close($outputHandler) ) {
    OInventory::log(3, "Could not close CSV output file '$csv': $!");
    return undef;
  }

  if($linesPrinted == 0) {
    OInventory::log(3, "Could not find points in that interval to print to '$csv'");
    return undef;
  }
  return $csv;
}

#
# Push custom ovom perfData
#
# @return 1 (if ok) | 0 (if errors)
#
sub pushOvomPerfData {
  my $type  = shift;
  my $value = shift;
  my $filePrefix;
  my $file;

  if (!defined($type) || $type eq '' ) {
    OInventory::log(3, "pushOvomPerfData: Missing type");
    return 0;
  }
  if (!defined($value) || $value eq '' ) {
    OInventory::log(3, "pushOvomPerfData: Missing value");
    return 0;
  }

  $filePrefix = $OInventory::configuration{'perfdata.root'} . "/ovom/$type";
  $file       = $filePrefix . ".latest.csv";

  #
  # First lets print the text at the end of the file
  #
  if( ! open(HANDLER, ">>:utf8", $file) ) {
    OInventory::log(3, "Could not open CSV file '$file': $!");
    return 0;
  }
  my $text = time() . "$csvSep$value";
  print HANDLER "$text\n";
  if( ! close(HANDLER) ) {
    OInventory::log(3, "Could not close the CSV file '$file': $!");
    return 0;
  }

  #
  # Now let's read the whole file and keep just its tail lines
  #
  if( ! open(HANDLER, "<:utf8", $file) ) {
    OInventory::log(3, "Could not open CSV file '$file': $!");
    return 0;
  }
  my @lines = <HANDLER>;
  if( ! close(HANDLER) ) {
    OInventory::log(3, "Could not close the CSV file '$file': $!");
    return 0;
  }
  my $firstLine; # from 0
  my $maxNumLines = $OInventory::configuration{'perfdata.custom.maxLines'};
  if($#lines >= $maxNumLines - 1) {
    $firstLine = $#lines + 1 - $maxNumLines;
  }
  else {
    $firstLine = 0;
  }

  #
  # Now let's read save just its last lines
  #
  if( ! open(HANDLER, ">:utf8", $file) ) {
    OInventory::log(3, "Could not open CSV file '$file': $!");
    return 0;
  }
  for(my $i = $firstLine; $i <= $#lines; $i++) {
    print HANDLER $lines[$i];
  }
  if( ! close(HANDLER) ) {
    OInventory::log(3, "Could not close the CSV file '$file': $!");
    return 0;
  }
 
  #
  # RRDB this file
  #
  if(! doRrdb($filePrefix)) {
    OInventory::log(3, "Could not run rrdb on custom perf data file $file");
    return 0;
  }
  return 1;
}

1;

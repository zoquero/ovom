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
      alarm $maxSecs;
      OInventory::log(0, "Getting perfManager with ${maxSecs}s timeout");
      $perfManagerView = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
      alarm 0;
    };
    if($@) {
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
# @return  2 (if updated),
#          1 (if inserted),
#          0 (if it doesn't need to be update),
#         -1 (if errors)
#
sub updatePciIfNeeded {
  my $pCI = shift;
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
                   . "rollupType='"       . $pCI->rollupType         . "',"
                   . "unitInfoKey='"      . $pCI->unitInfo->key      . "',"
                   . "unitInfoLabel='"    . $pCI->unitInfo->label    . "',"
                   . "unitInfoSummary='"  . $pCI->unitInfo->summary  . "'");

  my $loadedPci = OvomDao::loadEntity($pCI->key, 'PerfCounterInfo');
  if( ! defined($loadedPci)) {
    OInventory::log(0, "Can't find any perfCounterInfo with key="
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

  foreach my $pCI (@$perfCounterInfo) {
    #
    # Reference it from allCounters and allCountersByGIKey vars
    #
    my $key = $pCI->key;
    $allCounters{$key} = $pCI;
    push @{$allCountersByGIKey{$pCI->groupInfo->key}}, $pCI;

    #
    # Store it on DataBase
    #
    my $r = updatePciIfNeeded($pCI);
    if( $r == 2 ) {
      OInventory::log(2, "The perfCounter key=" . $pCI->key . " changed on DB");
    }
    elsif( $r == 1 ) {
      OInventory::log(2, "New perfCounter key=" . $pCI->key . " inserted on DB");
    }
    elsif( $r == 0 ) {
      OInventory::log(0, "The perfCounter key=" . $pCI->key
                       . " was already on DB with same values");
    }
    else {
      OInventory::log(3, "Could not update the perfCounter key="
                       . $pCI->key . " on DB");
    }
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

  my $perfManager=getPerfManager();
  if(! $perfManager) {
    OInventory::log(3, "Errors getting getPerfManager");
    return undef;
  }

  eval {
    local $SIG{ALRM} = sub { die "Timeout calling QueryPerf" };
    my $maxSecs = $OInventory::configuration{'api.timeout'};
    alarm $maxSecs;
    OInventory::log(0, "Calling QueryPerf, with a timeout of $maxSecs seconds");
    $r = $perfManager->QueryPerf(querySpec => $perfQuerySpec);
    alarm 0;
  };
  if ($@) {
    if ($@ =~ /Timeout calling QueryPerf/) {
      OInventory::log(3, "Timeout! perfManager->QueryPerf did not respond "
                       . "in a timely fashion: $@");
      return undef;
    } else {
      OInventory::log(3, "perfManager->QueryPerf failed: $@");
      return undef;
    }
  }

  return $r;
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
# @return 1 ok, 0 errors
#
sub registerPerfDataSaved {
  # Take a look at the subroutine comments to find a sample of received objects
  my $perfData = shift;
  my $entity   = shift;

  OInventory::log(0, "Registering that counterId=" . $perfData->id->counterId
                   . ",instance=" . $perfData->id->instance
                   . " has been saved for the " . $entity->type
                   . " with mo_ref=" . $entity->value);

  # 
  my $lastRegister = OvomDao::loadEntity($perfData->id->counterId, 'PerfMetric',
                                         $perfData->id->instance, $entity);
# * counterId of PerfMetricId object ($pMI->->counterId)
# * className (regular 2nd parameter)
# * instance of PerfMetricId object ($pMI->instance)
# * managedObjectReference ($managedObjectReference->type (VirtualMachine, ...),
#                           $managedObjectReference->value (it's mo_ref))
  if( ! defined($lastRegister)) {
    OInventory::log(0, "No previous PerfMetricId like this, let's insert:");
    my $aPerfMetricId = OMockView::OMockPerfMetricId->new(
                          [ $perfData->id->counterId, $perfData->id->instance ]
                        );
    if( ! OvomDao::insert($aPerfMetricId, $entity) ) {
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
    # update

    OInventory::log(0, "Let's update previous PerfMetricId:");
    my $aPerfMetricId = OMockView::OMockPerfMetricId->new(
                          [ $perfData->id->counterId, $perfData->id->instance ]
                        );
    # TO_DO : update unimplemented for PerfMetric , 2nd extra argument
    if( ! OvomDao::update($aPerfMetricId, $entity) ) {
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


  return 1;
}

#
# Save perf data to disk
#
# @arg array of PerfEntityMetricCSV || OMockView::OMockPerfEntityMetricCSV
# @arg entity view
# @return 1 ok, 0 errors
#
sub savePerfData {
  my $perfDataArray = shift;
  my $entityView    = shift;

  if( ! defined($perfDataArray) ) {
    OInventory::log(3, "savePerfData: expects a PerfEntityMetricCSV");
    return 0;
  }

# if( ref($perfData) ne 'PerfEntityMetricCSV'
#  && ref($perfData) ne 'OMockView::OMockPerfEntityMetricCSV')
  if( ref($perfDataArray) ne 'ARRAY') {
    OInventory::log(3, "savePerfData: Got unexpected '" . ref($perfDataArray)
                     . "' instead of ARRAY of PerfEntityMetricCSV");
    return 0;
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
# print "DEBUG: ** path=$csvPath : instance='" . $instance . "',counterId='"
# . $counterId . "',value='" . substr($value, 0, 15) . "...'\n";
      OInventory::log(0, "Saving in $csvPathLatest");
  
      my $timestamps = getSampleInfoArrayRefFromString($sampleInfoCSV);
      my @values = split /,/, $value;
      if($#$timestamps < 3) {
        OInventory::log(3, "Too few perf data values for mo_ref=" 
                         . $mo_ref 
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
  
      my $pDHandle;
      if(!open($pDHandle, ">:utf8", $csvPathLatest)) {
        OInventory::log(3, "Could not open perf data file $csvPathLatest: $!");
        return 0;
      }
  
      for(my $i = 0; $i <=$#$timestamps; $i++) {
        print $pDHandle $$timestamps[$i] . ";" . $values[$i] . "\n";
      }
  
      if(!close($pDHandle)) {
        OInventory::log(3, "Could not close perf data file $csvPathLatest: $!");
        return 0;
      }
      OInventory::log(0, "Saved in $csvPathLatest");

      #
      # Let's register on Database that this perfData has been saved
      #
      if(! registerPerfDataSaved($p, $entityView)) {
        OInventory::log(3, "Errors registering that perfData was taken from " . ref($entityView)
                         . " with mo_ref '" . $entityView->value . "'");
        return 0;
      }
    }
  }

  return 1;
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
  my $z = 0;
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

    # TO_DO : code cleanup: move it to a getAvailablePerfMetric function


    eval {
      local $SIG{ALRM} = sub { die "Timeout calling QueryAvailablePerfMetric" };
      my $maxSecs = $OInventory::configuration{'api.timeout'};
      OInventory::log(0, "Calling QueryAvailablePerfMetric, "
                       . "with a timeout of $maxSecs seconds");
      alarm $maxSecs;
      $availablePerfMetricIds =
        $perfManager->QueryAvailablePerfMetric(entity => $aEntity->{view});
      alarm 0;
    };
    if ($@) {
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
    my $perfQuerySpec = getPerfQuerySpec(entity     => $aEntity->{view},
                                         metricId   => $filteredPerfMetricIds,
                                         format     => 'csv',
                                         intervalId => 20); # 20s hardcoded
    if(! defined($perfQuerySpec)) {
      OInventory::log(3, "Could not get QuerySpec for entity");
      next;
    }

    #
    # Let's get perfData
    #
    # PerfEntityMetricCSV || OMockView::OMockPerfEntityMetricCSV
    $timeBefore=Time::HiRes::time;
    my $perfData = getPerfData($perfQuerySpec);
    if(! defined($perfData)) {
      OInventory::log(3, "Could not get perfData for entity");
      next;
    }
#   if( ref($perfData) ne 'PerfEntityMetricCSV'
#    && ref($perfData) ne 'OMockView::OMockPerfEntityMetricCSV') 
    if( ref($perfData) ne 'ARRAY') {
      OInventory::log(3, "Got unexpected " . ref($perfData)
                       . " instead of array of PerfEntityMetricCSV for entity");
      next;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(1, "Profiling: Getting performance for "
                     . ref($aEntity) . ": "
                     . "{name='" . $aEntity->{name} . "',mo_ref='"
                     . $aEntity->{mo_ref} . "'} took "
                     . sprintf("%.3f", $eTime) . " s");

    $timeBefore=Time::HiRes::time;
    if(! savePerfData($perfData, $aEntity)) {
      OInventory::log(3, "Errors getting performance from " . ref($aEntity)
                       . " with mo_ref '" . $aEntity->{mo_ref} . "'");
      if(! --$maxErrs) {
        OInventory::log(3, "Too many errors when getting performance from "
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

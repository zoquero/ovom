package OMockView::OMockPerformanceManager;
use strict;
use warnings;
use Carp;
use Data::Dumper;

use OInventory;
use OPerfCounterInfo;
use OMockView::OMockNameInfo;
use OMockView::OMockGroupInfo;
use OMockView::OMockUnitInfo;
use OMockView::OMockStatsType;
use OMockView::OMockRollupType;
use OMockView::OMockPerfMetricId;
use OMockView::OMockPerfEntityMetricCSV;
use OMockView::OMockPerfMetricSeriesCSV;


our $csvSep = ";";

sub new {
  my ($class, @args) = @_;
  my $self = bless {
    # array of OPerfCounterInfo objects
    _perfCounter => undef,
  }, $class;

  if($self->_loadPerfCounterInfoFromCsv()) {
    return $self;
  }
  else {
    return undef;
  }
}


sub perfCounter {
  my $self = shift;
  return $self->{_perfCounter};
}

#
# Loads OPerfCounterInfo objects from CSV files.
#
# Usefull for Mocking when debugging,
# to fill OMockPerfManager->perfCounter array
#
# @return 1 if ok, 0 if error
#
sub _loadPerfCounterInfoFromCsv {
  my $self = shift;
  my @countersInfo;
  my ($csv, $csvHandler);
  my $mockingCsvBaseFolder = $OInventory::configuration{'debug.mock.perfmgrRoot'};

  $csv = "$mockingCsvBaseFolder/counter_info.csv";

  OInventory::log(1, "Reading counterInfo objects from CSV file "
                        . $csv . " for mocking");

  if( ! open($csvHandler, "<", $csv) ) {
    OInventory::log(3, "Could not open mocking CSV file '$csv': $!");
    return 0;
  }

  while (my $line = <$csvHandler>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    my @parts = split /$csvSep/, $line;
    if ($#parts < 0) {
      OInventory::log(3, "Can't parse this line '$line' on file '$csv': $!");
      if( ! close($csvHandler) ) {
        OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
      }
      return 0;
    }

    my $aCounterInfo = OPerfCounterInfo->new(\@parts);
    if ( ! defined($aCounterInfo) ) {
      OInventory::log(3, "Errors loading a mocking counterInfo object");
      return 0;
    }
    OInventory::log(0, "Loaded: $aCounterInfo");
    push @countersInfo, $aCounterInfo;
  }
  if( ! close($csvHandler) ) {
    OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
    return 0;
  }

  $self->{_perfCounter} = \@countersInfo;
  return 1;
}

#
# Get available performance metric ids for a entity
#
# Note on vCenter API:
# $perfManagerView->QueryAvailablePerfMetric(entity => $entity) returns a 
# reference to an array of PerfMetricId objects like this:
#          bless( {
#                   'counterId' => '2',
#                   'instance' => ''
#                 }, 'PerfMetricId' ),
#          bless( {
#                   'instance' => '',
#                   'counterId' => '6'
#                 }, 'PerfMetricId' ),
#   ...
#          bless( {
#                   'instance' => 'DISKFILE',
#                   'counterId' => '240'
#                 }, 'PerfMetricId' ),
#          bless( {
#                   'counterId' => '240',
#                   'instance' => 'SWAPFILE'
#                 }, 'PerfMetricId' ),
#
# Those "counterID" are the "key" field for the perfCounters
# got from perfManagerView->perfCounter
#
# @arg reference to the entity view object
# @return reference to array of OMockPerfMetricId objects, undef if errors
#
#
sub QueryAvailablePerfMetric {
  my ($self, %args) = @_;

  my $entityView = $args{'entity'};

  if(!defined($entityView)) {
    OInventory::log(3, "Missing entity argument at QueryAvailablePerfMetric");
    return undef;
  }

  my @perfMetricIds;
  my ($csv, $csvHandler);
  my $mockingCsvBaseFolder = $OInventory::configuration{'debug.mock.perfmgrRoot'};

  if(ref($entityView) eq 'HostSystem' || ref($entityView) eq "OMockView::OMockHostView") {
    $csv = "$mockingCsvBaseFolder/perf_metric_id.HostSystem.csv";
  }
  elsif(ref($entityView) eq 'VirtualMachine' || ref($entityView) eq "OMockView::OMockVirtualMachineView") {
    $csv = "$mockingCsvBaseFolder/perf_metric_id.VirtualMachine.csv";
  }
  else {
    OInventory::log(3, "Unexpected entity type (". ref($entityView) . ") "
                     . "trying to QueryAvailablePerfMetric");
    return undef;
  }

  OInventory::log(1, "QueryAvailablePerfMetric: Reading perfMetric objects "
                   . "for the entity with mo_ref '"
                   . $entityView->{mo_ref}->{value}
                   . "' from CSV file $csv for mocking");

  if( ! open($csvHandler, "<", $csv) ) {
    OInventory::log(3, "Could not open mocking CSV file '$csv': $!");
    return undef;
  }

  while (my $line = <$csvHandler>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    my @parts = split /$csvSep/, $line, -1;
    if ($#parts < 0) {
      OInventory::log(3, "Can't parse this line '$line' on file '$csv': $!");
      if( ! close($csvHandler) ) {
        OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
      }
      return undef;
    }

    my $aPerfMetricId = OMockView::OMockPerfMetricId->new(\@parts);
    if ( ! defined($aPerfMetricId) ) {
      OInventory::log(3, "Errors loading a mocking perf metric id object");
      return undef;
    }
#   OInventory::log(0, "Loaded: $aPerfMetricId");
    push @perfMetricIds, $aPerfMetricId;
  }
  if( ! close($csvHandler) ) {
    OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
    return undef;
  }

  OInventory::log(0, "QueryAvailablePerfMetric returns "
                   . ($#perfMetricIds + 1) . " perfMetricIds "
                   . "for the entity with mo_ref '"
                   . $entityView->{mo_ref}->{value});

  return \@perfMetricIds;
}


#
# Query performance for a entity
#
# Note on vCenter API:
# $perfManagerView->QueryAvailablePerfMetric(entity => $entity) returns a 
# reference to a PerfEntityMetricCSV object like this:
# 
# $VAR1 = [
#           bless( {
#                    'sampleInfoCSV' => '20,2017-08-25T06:17:20Z,20,2017-08-25T06:17:40Z...',
#                    'value' => [
#                                 bless( {
#                                          'value' => '42,83,...',
#                                          'id' => bless( {
#                                                           'instance' => '',
#                                                           'counterId' => '2'
#                                                         }, 'PerfMetricId' )
#                                        }, 'PerfMetricSeriesCSV' ),
#                                 bless( {
#                                          'id' => bless( {
#                                                           'instance' => '',
#                                                           'counterId' => '6'
#                                                         }, 'PerfMetricId' ),
#                                          'value' => '38,76,...'
#                                        }, 'PerfMetricSeriesCSV' ),
#                                 ...
#                               ],
#                    'entity' => bless( {
#                                         'type' => 'VirtualMachine',
#                                         'value' => 'vm-17xxx'
#                                       }, 'ManagedObjectReference' )
#                  }, 'PerfEntityMetricCSV' )
#         ];
#
# @arg ref to the PerfQuerySpec object
# @return ref to an array of OMockPerfEntityMetricCSV objects, undef if errors
#
sub QueryPerf {
  my ($self, %args) = @_;
  my @perfMetricSeriesCSV = ();

  if(!defined($args{'querySpec'})) {
    OInventory::log(3, "Missing querySpec argument at QueryPerf");
    return undef;
  }

  my $perfQuerySpec = $args{'querySpec'};
  if ( ref($perfQuerySpec) ne 'PerfQuerySpec'
    && ref($perfQuerySpec) ne 'OMockView::OMockPerfQuerySpec' ) {
     OInventory::log(3, "QueryPerf needs a PerfQuerySpec");
     return undef;
  }

  my $str = "Querying perf for: ";
  foreach my $aMetricId (@{$perfQuerySpec->{_metricId}}) {
    $str .= "{counterId=" . $aMetricId->{_counterId} . ",instance=" . $aMetricId->{_instance} . "} ";

    my $value = '42,83,61,137,60,79,107,78,46,117,50,45,125,270,115,57,82,75,88,77,72,42,43,251,138,60,46,99,154,51,58,90,138,73,68,81,44,75,53,83,47,124,46,214,87,42,84,66,88,43,78,41,47,121,119,70,80,116,445,113,107,84,62,72,59,77,39,63,51,132,50,98,91,286,73,152,157,60,109,41,92,43,46,50,52,66,66,65,135,57,42,143,50,156,44,91,38,133,49,103,122,84,51,114,43,61,149,52,68,58,79,44,60,50,49,51,44,49,94,48,150,85,53,74,46,79,45,48,130,64,59,64,66,107,46,67,87,57,90,45,109,51,47,123,51,77,48,64,107,101,40,83,45,94,43,85,44,69,57,69,99,40,106,242,74,44,101,45,72,85,283,232,142,153,57,57,63,45,420,76';
    push @perfMetricSeriesCSV, OMockView::OMockPerfMetricSeriesCSV->new(
                   value => $value,
                   id    => $aMetricId);
   }
 
   my $sampleInfoCSV = '20,2017-08-25T06:17:20Z,20,2017-08-25T06:17:40Z,20,2017-08-25T06:18:00Z,20,2017-08-25T06:18:20Z,20,2017-08-25T06:18:40Z,20,2017-08-25T06:19:00Z,20,2017-08-25T06:19:20Z,20,2017-08-25T06:19:40Z,20,2017-08-25T06:20:00Z,20,2017-08-25T06:20:20Z,20,2017-08-25T06:20:40Z,20,2017-08-25T06:21:00Z,20,2017-08-25T06:21:20Z,20,2017-08-25T06:21:40Z,20,2017-08-25T06:22:00Z,20,2017-08-25T06:22:20Z,20,2017-08-25T06:22:40Z,20,2017-08-25T06:23:00Z,20,2017-08-25T06:23:20Z,20,2017-08-25T06:23:40Z,20,2017-08-25T06:24:00Z,20,2017-08-25T06:24:20Z,20,2017-08-25T06:24:40Z,20,2017-08-25T06:25:00Z,20,2017-08-25T06:25:20Z,20,2017-08-25T06:25:40Z,20,2017-08-25T06:26:00Z,20,2017-08-25T06:26:20Z,20,2017-08-25T06:26:40Z,20,2017-08-25T06:27:00Z,20,2017-08-25T06:27:20Z,20,2017-08-25T06:27:40Z,20,2017-08-25T06:28:00Z,20,2017-08-25T06:28:20Z,20,2017-08-25T06:28:40Z,20,2017-08-25T06:29:00Z,20,2017-08-25T06:29:20Z,20,2017-08-25T06:29:40Z,20,2017-08-25T06:30:00Z,20,2017-08-25T06:30:20Z,20,2017-08-25T06:30:40Z,20,2017-08-25T06:31:00Z,20,2017-08-25T06:31:20Z,20,2017-08-25T06:31:40Z,20,2017-08-25T06:32:00Z,20,2017-08-25T06:32:20Z,20,2017-08-25T06:32:40Z,20,2017-08-25T06:33:00Z,20,2017-08-25T06:33:20Z,20,2017-08-25T06:33:40Z,20,2017-08-25T06:34:00Z,20,2017-08-25T06:34:20Z,20,2017-08-25T06:34:40Z,20,2017-08-25T06:35:00Z,20,2017-08-25T06:35:20Z,20,2017-08-25T06:35:40Z,20,2017-08-25T06:36:00Z,20,2017-08-25T06:36:20Z,20,2017-08-25T06:36:40Z,20,2017-08-25T06:37:00Z,20,2017-08-25T06:37:20Z,20,2017-08-25T06:37:40Z,20,2017-08-25T06:38:00Z,20,2017-08-25T06:38:20Z,20,2017-08-25T06:38:40Z,20,2017-08-25T06:39:00Z,20,2017-08-25T06:39:20Z,20,2017-08-25T06:39:40Z,20,2017-08-25T06:40:00Z,20,2017-08-25T06:40:20Z,20,2017-08-25T06:40:40Z,20,2017-08-25T06:41:00Z,20,2017-08-25T06:41:20Z,20,2017-08-25T06:41:40Z,20,2017-08-25T06:42:00Z,20,2017-08-25T06:42:20Z,20,2017-08-25T06:42:40Z,20,2017-08-25T06:43:00Z,20,2017-08-25T06:43:20Z,20,2017-08-25T06:43:40Z,20,2017-08-25T06:44:00Z,20,2017-08-25T06:44:20Z,20,2017-08-25T06:44:40Z,20,2017-08-25T06:45:00Z,20,2017-08-25T06:45:20Z,20,2017-08-25T06:45:40Z,20,2017-08-25T06:46:00Z,20,2017-08-25T06:46:20Z,20,2017-08-25T06:46:40Z,20,2017-08-25T06:47:00Z,20,2017-08-25T06:47:20Z,20,2017-08-25T06:47:40Z,20,2017-08-25T06:48:00Z,20,2017-08-25T06:48:20Z,20,2017-08-25T06:48:40Z,20,2017-08-25T06:49:00Z,20,2017-08-25T06:49:20Z,20,2017-08-25T06:49:40Z,20,2017-08-25T06:50:00Z,20,2017-08-25T06:50:20Z,20,2017-08-25T06:50:40Z,20,2017-08-25T06:51:00Z,20,2017-08-25T06:51:20Z,20,2017-08-25T06:51:40Z,20,2017-08-25T06:52:00Z,20,2017-08-25T06:52:20Z,20,2017-08-25T06:52:40Z,20,2017-08-25T06:53:00Z,20,2017-08-25T06:53:20Z,20,2017-08-25T06:53:40Z,20,2017-08-25T06:54:00Z,20,2017-08-25T06:54:20Z,20,2017-08-25T06:54:40Z,20,2017-08-25T06:55:00Z,20,2017-08-25T06:55:20Z,20,2017-08-25T06:55:40Z,20,2017-08-25T06:56:00Z,20,2017-08-25T06:56:20Z,20,2017-08-25T06:56:40Z,20,2017-08-25T06:57:00Z,20,2017-08-25T06:57:20Z,20,2017-08-25T06:57:40Z,20,2017-08-25T06:58:00Z,20,2017-08-25T06:58:20Z,20,2017-08-25T06:58:40Z,20,2017-08-25T06:59:00Z,20,2017-08-25T06:59:20Z,20,2017-08-25T06:59:40Z,20,2017-08-25T07:00:00Z,20,2017-08-25T07:00:20Z,20,2017-08-25T07:00:40Z,20,2017-08-25T07:01:00Z,20,2017-08-25T07:01:20Z,20,2017-08-25T07:01:40Z,20,2017-08-25T07:02:00Z,20,2017-08-25T07:02:20Z,20,2017-08-25T07:02:40Z,20,2017-08-25T07:03:00Z,20,2017-08-25T07:03:20Z,20,2017-08-25T07:03:40Z,20,2017-08-25T07:04:00Z,20,2017-08-25T07:04:20Z,20,2017-08-25T07:04:40Z,20,2017-08-25T07:05:00Z,20,2017-08-25T07:05:20Z,20,2017-08-25T07:05:40Z,20,2017-08-25T07:06:00Z,20,2017-08-25T07:06:20Z,20,2017-08-25T07:06:40Z,20,2017-08-25T07:07:00Z,20,2017-08-25T07:07:20Z,20,2017-08-25T07:07:40Z,20,2017-08-25T07:08:00Z,20,2017-08-25T07:08:20Z,20,2017-08-25T07:08:40Z,20,2017-08-25T07:09:00Z,20,2017-08-25T07:09:20Z,20,2017-08-25T07:09:40Z,20,2017-08-25T07:10:00Z,20,2017-08-25T07:10:20Z,20,2017-08-25T07:10:40Z,20,2017-08-25T07:11:00Z,20,2017-08-25T07:11:20Z,20,2017-08-25T07:11:40Z,20,2017-08-25T07:12:00Z,20,2017-08-25T07:12:20Z,20,2017-08-25T07:12:40Z,20,2017-08-25T07:13:00Z,20,2017-08-25T07:13:20Z,20,2017-08-25T07:13:40Z,20,2017-08-25T07:14:00Z,20,2017-08-25T07:14:20Z,20,2017-08-25T07:14:40Z,20,2017-08-25T07:15:00Z,20,2017-08-25T07:15:20Z,20,2017-08-25T07:15:40Z,20,2017-08-25T07:16:00Z,20,2017-08-25T07:16:20Z,20,2017-08-25T07:16:40Z,20,2017-08-25T07:17:00Z';

  my $perfEntityMetricCsv = OMockView::OMockPerfEntityMetricCSV->new(
                                sampleInfoCSV => $sampleInfoCSV,
                                value         => \@perfMetricSeriesCSV,
                                entity        => $perfQuerySpec->{_entity});
  OInventory::log(3, "Mocking: $str");
  return [$perfEntityMetricCsv];
}

1;

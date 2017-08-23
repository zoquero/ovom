package OMockView::OMockPerformanceManager;
use strict;
use warnings;
use Carp;
use Data::Dumper;

use OInventory;
use OMockView::OMockPerfCounterInfo;
use OMockView::OMockNameInfo;
use OMockView::OMockGroupInfo;
use OMockView::OMockUnitInfo;
use OMockView::OMockStatsType;
use OMockView::OMockRollupType;


our $csvSep = ";";

sub new {
  my ($class, @args) = @_;
  my $self = bless {
    # array of OMockPerfCounterInfo objects
    _perfCounter => undef,
  }, $class;

  if($self->_loadFromCsv()) {
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
# Loads OMockPerfCounterInfo objects from CSV files.
#
# Usefull for Mocking when debugging,
# to fill OMockPerfManager->perfCounter array
#
# @return 1 if ok, 0 if error
#
sub _loadFromCsv {
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

    my $aCounterInfo = OMockView::OMockPerfCounterInfo->new(\@parts);
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

1;

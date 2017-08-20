#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use OvomExtractor;

my $justOneLoop = 0;
$justOneLoop = 1 if ( defined($ARGV[0]) && $ARGV[0] eq '--once' );

my $inventoryRefreshCount = 0;
OvomExtractor::collectorInit();
while(1) {
  ####################
  # Inventory update #
  ####################
  OvomExtractor::log(1, "Extraction loop #" . $inventoryRefreshCount);
  if($inventoryRefreshCount++
     % $OvomExtractor::configuration{'inventory.refreshPeriod'} == 0) {
    OvomExtractor::log(1, "Let's update the inventory");
    if(! OvomExtractor::updateOvomInventoryDatabaseFromVcenter()) {
      OvomExtractor::log(3, "Can't update inventory");
    }
    else {
      OvomExtractor::log(1, "The inventory has been updated on memory");
    }
  }
  else {
    OvomExtractor::log(0,
      "We will not update the inventory this loop. You can adjust it with "
      . "the 'inventory.refreshPeriod' configuration parameter");
  }

  ###################
  # Get performance #
  ###################
  OvomExtractor::log(1, "Let's get latest performance data");
  if(OvomExtractor::getLatestPerformance()) {
    OvomExtractor::log(3, "Errors getting performance data");
  }

  last if($justOneLoop);

  #########################
  # Sleep until next loop #
  #########################
  my $sleepSecs = $OvomExtractor::configuration{'polling.wait_seconds'};
  OvomExtractor::log(1, "Let's sleep ${sleepSecs}s after a loop");
  sleep($sleepSecs);
}
OvomExtractor::collectorStop();


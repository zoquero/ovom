#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use OInventory;

my $justOneLoop = 0;
$justOneLoop = 1 if ( defined($ARGV[0]) && $ARGV[0] eq '--once' );

my $inventoryRefreshCount = 0;
OInventory::pickerInit();
while(1) {
  ####################
  # Inventory update #
  ####################
  OInventory::log(1, "Extraction loop #" . $inventoryRefreshCount);
  if($inventoryRefreshCount++
     % $OInventory::configuration{'inventory.refreshPeriod'} == 0) {
    OInventory::log(1, "Let's update the inventory");
    # Retrieves live inventory and updates our inventory DB
    if(! OInventory::updateOvomInventoryDatabaseFromVcenter()) {
      OInventory::log(3, "Can't update inventory");
    }
    else {
      OInventory::log(1, "The inventory has been updated on memory");
    }
  }
  else {
    OInventory::log(0,
      "We will not update the inventory this loop. You can adjust it with "
      . "the 'inventory.refreshPeriod' configuration parameter");
  }

  ###################
  # Get performance #
  ###################
  OInventory::log(1, "Let's get latest performance data");
  if(OInventory::getLatestPerformance()) {
    OInventory::log(3, "Errors getting performance data");
  }

  if($justOneLoop) {
    OInventory::log(1, "Running just one loop, let's finish.");
    last;
  }

  #########################
  # Sleep until next loop #
  #########################
  my $sleepSecs = $OInventory::configuration{'polling.wait_seconds'};
  OInventory::log(1, "Let's sleep ${sleepSecs}s after a loop");
  sleep($sleepSecs);
}
OInventory::pickerStop();


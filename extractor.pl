#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use OvomExtractor;

my $inventoryRefreshCount = 0;
OvomExtractor::collectorInit();
while(1) {
  OvomExtractor::log(1, "Extraction loop #" . ++$inventoryRefreshCount);
  if($inventoryRefreshCount % $OvomExtractor::configuration{'inventory.refreshPeriod'} == 0) {
    OvomExtractor::log(1, "Let's update the inventory");
    if(OvomExtractor::updateInventory()) {
      OvomExtractor::log(2, "Errors updating inventory");
    }
    else {
      OvomExtractor::log(2, "The inventory has been updated");
    }
  }
  OvomExtractor::log(1, "Let's get latest performance data");
  if(OvomExtractor::getLatestPerformance()) {
    OvomExtractor::log(3, "Errors getting performance data");
  }
  my $sleepSecs = $OvomExtractor::configuration{'polling.wait_seconds'};
  OvomExtractor::log(1, "Let's sleep ${sleepSecs}s after a loop");
  sleep($sleepSecs);
}
OvomExtractor::collectorStop();


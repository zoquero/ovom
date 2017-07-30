#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use OvomExtractor;

OvomExtractor::collectorInit();
while(1) {
  # OvomExtractor::log(1, "Main, post collectorInit");
  if(OvomExtractor::updateInventory()) {
    OvomExtractor::log(2, "Couldn't update inventory");
  }
  else {
    OvomExtractor::log(2, "The inventory has been updated");
  }
  if(OvomExtractor::updatePerformance()) {
    OvomExtractor::log(3, "Couldn't update performance");
  }
  my $sleepSecs = $OvomExtractor::configuration{'polling.wait_seconds'};
  OvomExtractor::log(1, "Let's sleep ${sleepSecs}s after a loop");
  sleep($sleepSecs);
}
OvomExtractor::collectorStop();


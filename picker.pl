#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use POSIX qw/strftime/;
use Time::HiRes; ## gettimeofday
use OInventory;
use OPerformance;

use open 'IN',   ':encoding(UTF-8)';
use open 'IO',   ':encoding(UTF-8)';
use open 'OUT',  ':encoding(UTF-8)';
use open ':std', ':encoding(UTF-8)';
my $justOneLoop = 0;
$justOneLoop = 1 if ( defined($ARGV[0]) && $ARGV[0] eq '--once' );
my $inventoryRefreshCount = 0;

OInventory::pickerInit();

my ($timeBefore, $r, $eTime);
while(1) {
  #
  # Inventory update
  #
  OInventory::log(1, "Extraction loop #" . $inventoryRefreshCount);
  if($inventoryRefreshCount++
     % $OInventory::configuration{'inventory.refreshPeriod'} == 0) {

    OInventory::log(1, "Let's update the inventory");
    # Retrieve live inventory and update our inventory DB

    $timeBefore=Time::HiRes::time;
    $r = OInventory::updateOvomInventoryDatabaseFromVcenter();
    $eTime=Time::HiRes::time - $timeBefore;

    if(! $r) {
      OInventory::log(3, "Can't update inventory");
    }
    else {
      OInventory::log(1, "Profiling: Retrieve inventory and update DB took "
                         . sprintf("%.3f", $eTime) . " s");
    }
  }
  else {
    OInventory::log(0,
      "We will not update the inventory this loop. You can adjust it with "
      . "the 'inventory.refreshPeriod' configuration parameter");
  }

  #
  # Get performance
  #
  OInventory::log(1, "Let's get latest performance data");
  $timeBefore=Time::HiRes::time;
  $r = OPerformance::getLatestPerformance();
  $eTime=Time::HiRes::time - $timeBefore;

  if(! $r) {
    OInventory::log(3, "Errors getting performance data");
    # Will not break, just a sleep time is left in this loop
  }

  if($justOneLoop) {
    OInventory::log(1, "Running just one loop, let's finish.");
    last;
  }

  #
  # Sleep until next loop
  #
  my $sleepSecs = $OInventory::configuration{'polling.wait_seconds'};
  OInventory::log(1, "Let's sleep ${sleepSecs}s after a loop");
  sleep($sleepSecs);
}
OInventory::pickerStop();


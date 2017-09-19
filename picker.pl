#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use POSIX qw/strftime/;
use Time::HiRes; ## gettimeofday
use OInventory;
use OPerformance;

# use open 'IN',   ':encoding(UTF-8)';
# use open 'IO',   ':encoding(UTF-8)';
# use open 'OUT',  ':encoding(UTF-8)';
# use open ':std', ':encoding(UTF-8)';
my $justOneIteration = 0;
$justOneIteration = 1 if ( defined($ARGV[0]) && $ARGV[0] eq '--once' );
my $inventoryRefreshCount = 0;

if( ! OInventory::pickerInit()) {
  die "Exiting";
}

my ($timeBefore, $r, $eTime);
while(1) {
  #
  # Connect to Database if needed:
  #
  if(OvomDao::connected() != 1) {
    OInventory::log(3, "Somehow wasn't connected to DB, let's connect again.");
    if(OvomDao::connect() != 1) {
      OInventory::log(3, "Cannot connect to DataBase. This iteration ends.");
      goto ITERATION_END;
    }
  }

  #
  # Inventory update
  #
  OInventory::log(1, "Extraction iteration #" . $inventoryRefreshCount);
  if($inventoryRefreshCount++
     % $OInventory::configuration{'inventory.refreshPeriod'} == 0) {

    OInventory::log(1, "Let's update the inventory");
    # Retrieve live inventory and update our inventory DB

    $timeBefore=Time::HiRes::time;
    $r = OInventory::updateOvomInventoryDatabaseFromVcenter();
    $eTime=Time::HiRes::time - $timeBefore;

    if($r) {
      #
      # Ok! Commit on Database
      #
      OInventory::log(1, "Let's commit the transaction on DB.");
      if( ! OvomDao::transactionCommit()) {
        OInventory::log(3, "Cannot commit transactions on DataBase. "
                         . "Trying to disconnect from DB. Iteration end.");
        #
        # Let's disconnect from DB
        #
        if( OvomDao::disconnect() != 1 ) {
          OInventory::log(3, "Cannot disconnect from DataBase");
        }
        goto ITERATION_END;
      }

      OInventory::log(1, "Profiling: Retrieving inventory and updating DB took "
                         . sprintf("%.3f", $eTime) . " s");
    }
    else {
      OInventory::log(3, "Can't update inventory. Rolling back. Iteration ends");
      if( ! OvomDao::transactionRollback()) {
        OInventory::log(3, "Cannot rollback transactions on DataBase"
                         . "Trying to disconnect from DB. Iteration end.");
        #
        # Let's disconnect from DB
        #
        if( OvomDao::disconnect() != 1 ) {
          OInventory::log(3, "Cannot disconnect from DataBase");
        }
      }
      goto ITERATION_END;
    }
  }
  else {
    OInventory::log(0,
      "We will not update the inventory this iteration. You can adjust it with "
      . "the 'inventory.refreshPeriod' configuration parameter");
  }

  #
  # Get performance
  #
  OInventory::log(1, "Let's get latest performance data");
  $timeBefore=Time::HiRes::time;
  $r = OPerformance::getLatestPerformance();
  $eTime=Time::HiRes::time - $timeBefore;

  if($r) {
    #
    # Ok! Commit on Database
    #
    OInventory::log(1, "Let's commit the transaction on DB.");
    if( ! OvomDao::transactionCommit()) {
      OInventory::log(3, "Cannot commit transactions on DataBase. "
                       . "Trying to disconnect from DB. Iteration end.");
      #
      # Let's disconnect from DB
      #
      if( OvomDao::disconnect() != 1 ) {
        OInventory::log(3, "Cannot disconnect from DataBase");
      }
      goto ITERATION_END;
    }

    OInventory::log(1, "Profiling: getting the whole performance took "
                       . sprintf("%.3f", $eTime) . " s");
  }
  else {
    OInventory::log(3, "Can't get performance data. Rolling back. Iteration ends");
    # Will not break, just a sleep time is left in this iteration

    if( ! OvomDao::transactionRollback()) {
      OInventory::log(3, "Cannot rollback transactions on DataBase"
                       . "Trying to disconnect from DB. Iteration end.");
      #
      # Let's disconnect from DB
      #
      if( OvomDao::disconnect() != 1 ) {
        OInventory::log(3, "Cannot disconnect from DataBase");
      }
    }
    goto ITERATION_END;
  }

  #
  # Iteration has finished
  #
  ITERATION_END:
  if($justOneIteration) {
    OInventory::log(1, "Running just one iteration, let's finish.");
    last;
  }

  #
  # Sleep until next iteration
  #
  my $sleepSecs = $OInventory::configuration{'polling.wait_seconds'};
  OInventory::log(1, "Let's sleep ${sleepSecs}s after an iteration");
  sleep($sleepSecs);
}

if( ! OInventory::pickerStop()) {
  die "Exiting";
}

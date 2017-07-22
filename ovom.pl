#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use Ovom;

Ovom::collectorInit();
# Ovom::log(1, "Main, post collectorInit");
if(Ovom::updateInventory()) {
  Ovom::log(2, "Couldn't update inventory");
}
else {
  Ovom::log(2, "The inventory has been updated");
}
if(Ovom::updatePerformance()) {
  Ovom::log(3, "Couldn't update performance");
}
Ovom::collectorStop();

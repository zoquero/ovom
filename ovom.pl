#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use Ovom;

Ovom::collectorInit();
# Ovom::log(1, "Main, post collectorInit");
Ovom::updateInventory();
Ovom::updatePerformance();
Ovom::collectorStop();

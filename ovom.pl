#!/usr/bin/perl
use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use Ovom;

Ovom::collectorInit();
Ovom::log(1, "Main, post collectorInit");
print "logLevel        = $Ovom::configuration{'logLevel'}\n";
print "perfDataRoot    = $Ovom::configuration{'perfDataRoot'}\n";
print "vDataCenterName = $Ovom::configuration{'vDataCenterName'}\n";
print "vCenterName     = $Ovom::configuration{'vCenterName'}\n";
print "command.dcList  = $Ovom::configuration{'command.dcList'}\n";
Ovom::updateInventory();
Ovom::updatePerformance();
Ovom::collectorStop();

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
print "Main: Let's print hosts:\n";
my($aHost, $aVM);
foreach $aHost (@{$Ovom::inventory{'hosts'}}) {
  print "$aHost; ";
print "\n";
}
print "Main: Let's print VMs:\n";
foreach $aVM (@{$Ovom::inventory{'vms'}}) {
  print "$aVM; ";
}
print "\n";

Ovom::updatePerformance();
Ovom::collectorStop();

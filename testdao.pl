#!/usr/bin/perl
use warnings;
use strict;
use OvomExtractor;
use OvomDao;
use ODatacenter;
use OvomExtractor;
use OVirtualMachine;
use OFolder;
use OHost;
use OCluster;


print "Testing DBI\n";
OvomExtractor::collectorInit();

if(OvomExtractor::updateInventory()) {
  OvomExtractor::log(2, "Errors updating inventory");
}
else {
  OvomExtractor::log(2, "The inventory has been updated on memory");
}

# OvomExtractor::printInventoryForDebug();

my %inventOnDb = (); # keys = Folder Datacenter ClusterComputeResource HostSystem VirtualMachine
foreach my $entityType (@$OvomExtractor::entityTypes) {
  $inventOnDb{$entityType} = \();
}

#########################
# Connect to Database
#########################

my $r;
if(OvomDao::connect() != 1) {
  OvomExtractor::collectorStop();
  die "Cannot connect to DataBase\n";
}
# $r = OvomDao::connected();

#########################
# OFolder
#########################
print "getAll OFolder\n";
my $allFoldersFromDB = OvomDao::getAllEntitiesOfType('OFolder');
if (! defined($allFoldersFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# print "call to updateAsNeeded for Folder.\n";
# $r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'Folder'}}, $allFoldersFromDB);
# if($r == -1) {
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }

push @{$inventOnDb{'Folder'}}, @$allFoldersFromDB;

#########################
# ODatacenter
#########################
print "getAll ODatacenter\n";
my $allDatacentersFromDB = OvomDao::getAllEntitiesOfType('ODatacenter');
if (! defined($allDatacentersFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# print "call to updateAsNeeded for Datacenter.\n";
# $r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'Datacenter'}}, $allDatacentersFromDB);
# if($r == -1) {
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }

push @{$inventOnDb{'Datacenter'}}, @$allDatacentersFromDB;

#########################
# OCluster
#########################
print "getAll OCluster\n";
my $allClustersFromDB = OvomDao::getAllEntitiesOfType('OCluster');
if (! defined($allClustersFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# print "call to updateAsNeeded for Cluster.\n";
# $r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'ClusterComputeResource'}}, $allClustersFromDB);
# if($r == -1) {
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }

push @{$inventOnDb{'ClusterComputeResource'}}, @$allClustersFromDB;

#########################
# OHost
#########################
print "getAll OHost\n";
my $allHostsFromDB = OvomDao::getAllEntitiesOfType('OHost');
if (! defined($allHostsFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# print "call to updateAsNeeded for Host.\n";
# $r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'HostSystem'}}, $allHostsFromDB);
# if($r == -1) {
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }

push @{$inventOnDb{'HostSystem'}}, @$allHostsFromDB;

#########################
# OVirtualMachine
#########################
print "getAll OVirtualMachine\n";
my $allVirtualMachinesFromDB = OvomDao::getAllEntitiesOfType('OVirtualMachine');
if (! defined($allVirtualMachinesFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# print "call to updateAsNeeded for VirtualMachine.\n";
# $r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'VirtualMachine'}}, $allVirtualMachinesFromDB);
# if($r == -1) {
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }

push @{$inventOnDb{'VirtualMachine'}}, @$allVirtualMachinesFromDB;

#######################################
# Let's updateAsNeeded
#######################################
print "call to updateAsNeeded:\n";

$r = OvomDao::updateAsNeeded(\%inventOnDb);
print "call to updateAsNeeded returned = $r\n";
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

#######################################
# Ok! Commit and disconnect to Database
#######################################
OvomDao::transactionCommit();
if( OvomDao::disconnect() != 1 ) {
  OvomExtractor::collectorStop();
  die "Cannot disconnect from DataBase\n";
}

OvomExtractor::collectorStop();


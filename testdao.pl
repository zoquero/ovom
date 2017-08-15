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

#print "Show Folders::\n";
#foreach my $aEntity (@{$OvomExtractor::inventory{'Folder'}}) {
#  print "a Folder = " . $$aEntity->toCsvRow() . "\n";
#}

# my @foundDatacenters;
# my @foundVirtualMachines;
# my @foundHosts;
# my @foundClusters;
# my @foundFolders;
# 
# my $someDatacenterViews     = OvomExtractor::getViewsFromCsv('Datacenter');
# my $someVirtualMachineViews = OvomExtractor::getViewsFromCsv('VirtualMachine');
# my $someHostViews           = OvomExtractor::getViewsFromCsv('HostSystem');
# my $someClusterViews        = OvomExtractor::getViewsFromCsv('ClusterComputeResource');
# my $someFolderViews         = OvomExtractor::getViewsFromCsv('Folder');
# 
# foreach my $aView (@$someDatacenterViews) {
#   my $aEntity = ODatacenter->newFromView($aView);
#   push @foundDatacenters, $aEntity;
# # print "vDC : name = "            . $aEntity->{name}            . " mo_ref = "         . $aEntity->{mo_ref}        . " parent = " . $aEntity->{parent}
# #          . " datastoreFolder = " . $aEntity->{datastoreFolder} . " vmFolder = "      . $aEntity->{vmFolder}
# #          . " hostFolder = "      . $aEntity->{hostFolder}      . " networkFolder = " . $aEntity->{networkFolder} . "\n";
# }
# foreach my $aView (@$someVirtualMachineViews) {
#   my $aEntity = OVirtualMachine->new($aView);
#   push @foundVirtualMachines, $aEntity;
# # print "VM : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
# }
# foreach my $aView (@$someHostViews) {
#   my $aEntity = OHost->new($aView);
#   push @foundHosts, $aEntity;
# # print "Host : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
# }
# foreach my $aView (@$someClusterViews) {
#   my $aEntity = OCluster->new($aView);
#   push @foundClusters, $aEntity;
# # print "Cluster : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
# }
# foreach my $aView (@$someFolderViews) {
#   my $aEntity = OFolder->newFromView($aView);
#   push @foundFolders, $aEntity;
#   my $parent = defined($aEntity->{parent}) ? $aEntity->{parent} : '';
#   print "Folder : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = $parent\n";
# }

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

$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'Folder'}}, $allFoldersFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

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

print "call to updateAsNeeded for Datacenter.\n";
$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'Datacenter'}}, $allDatacentersFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

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

print "call to updateAsNeeded for Cluster.\n";
$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'ClusterComputeResource'}}, $allClustersFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}


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

print "call to updateAsNeeded for Host.\n";
$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'HostSystem'}}, $allHostsFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}


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

print "call to updateAsNeeded for VirtualMachine.\n";
$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'VirtualMachine'}}, $allVirtualMachinesFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# Ok
OvomDao::transactionCommit();
if( OvomDao::disconnect() != 1 ) {
  OvomExtractor::collectorStop();
  die "Cannot disconnect from DataBase\n";
}

OvomExtractor::collectorStop();


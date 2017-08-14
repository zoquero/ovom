#!/usr/bin/perl
use warnings;
use strict;
use OvomExtractor;
use OvomDao;
use ODataCenter;
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
  OvomExtractor::log(2, "The inventory has been updated");
}

#print "Show Folders::\n";
#foreach my $aEntity (@{$OvomExtractor::inventory{'Folder'}}) {
#  print "a Folder = " . $$aEntity->toCsvRow() . "\n";
#}

# my @foundDataCenters;
# my @foundVirtualMachines;
# my @foundHosts;
# my @foundClusters;
# my @foundFolders;
# 
# my $someDataCenterViews     = OvomExtractor::getViewsFromCsv('Datacenter');
# my $someVirtualMachineViews = OvomExtractor::getViewsFromCsv('VirtualMachine');
# my $someHostViews           = OvomExtractor::getViewsFromCsv('HostSystem');
# my $someClusterViews        = OvomExtractor::getViewsFromCsv('ClusterComputeResource');
# my $someFolderViews         = OvomExtractor::getViewsFromCsv('Folder');
# 
# foreach my $aView (@$someDataCenterViews) {
#   my $aEntity = ODataCenter->newFromView($aView);
#   push @foundDataCenters, $aEntity;
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

my $allFoldersFromDB = OvomDao::getAllEntitiesOfType('OFolder');
if (! defined($allFoldersFromDB) ) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}

# my $folderMoRef = 'group-d1';
# my $aFolderFromDB = OvomDao::loadFolderByMoRef($folderMoRef);
# if (! defined($aFolderFromDB) ) {
#   print "Can't find the folder with mo_ref = $folderMoRef\n";
#   OvomDao::transactionRollback();
#   OvomDao::disconnect();
#   OvomExtractor::collectorStop();
#   exit(1);
# }
# print "Found the folder " . $aFolderFromDB->toCsvRow() . "\n";
# OvomDao::transactionRollback();
# OvomDao::disconnect();
# OvomExtractor::collectorStop();
# exit(1);

$r = OvomDao::updateAsNeeded(\@{$OvomExtractor::inventory{'Folder'}}, $allFoldersFromDB);
if($r == -1) {
  OvomDao::transactionRollback();
  OvomDao::disconnect();
  OvomExtractor::collectorStop();
  exit(1);
}
OvomDao::transactionCommit();
if( OvomDao::disconnect() != 1 ) {
  OvomExtractor::collectorStop();
  die "Cannot disconnect to DataBase\n";
}

OvomExtractor::collectorStop();


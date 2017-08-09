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

my $someDataCenterViews     = OvomExtractor::getViewsFromCsv('vDCs');
my $someVirtualMachineViews = OvomExtractor::getViewsFromCsv('vms');
my $someHostViews           = OvomExtractor::getViewsFromCsv('hosts');
my $someClusterViews        = OvomExtractor::getViewsFromCsv('clusters');
my $someFolderViews         = OvomExtractor::getViewsFromCsv('folders');

foreach my $aView (@$someDataCenterViews) {
  my $aEntity = ODataCenter->new($aView);
  print "vDC : name = "            . $aEntity->{name}            . " mo_ref = "         . $aEntity->{mo_ref}        . " parent = " . $aEntity->{parent}
           . " datastoreFolder = " . $aEntity->{datastoreFolder} . " vmFolder = "      . $aEntity->{vmFolder}
           . " hostFolder = "      . $aEntity->{hostFolder}      . " networkFolder = " . $aEntity->{networkFolder} . "\n";
}
foreach my $aView (@$someVirtualMachineViews) {
  my $aEntity = OVirtualMachine->new($aView);
  print "VM : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someHostViews) {
  my $aEntity = OHost->new($aView);
  print "Host : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someClusterViews) {
  my $aEntity = OCluster->new($aView);
  print "Cluster : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someFolderViews) {
  my $aEntity = OFolder->new($aView);
  my $parent = defined($aEntity->{parent}) ? $aEntity->{parent} : '';
  print "Folder : name = " . $aEntity->{name} . " mo_ref = " . $aEntity->{mo_ref} . " parent = $parent\n";
}

OvomDao::connect();
OvomDao::disconnect();

OvomExtractor::collectorStop();


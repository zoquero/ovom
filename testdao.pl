#!/usr/bin/perl
use warnings;
use strict;
use OvomExtractor;
use ODataCenter;
use OvomExtractor;
use OVirtualMachine;
use OFolder;
use OHost;
use OCluster;


print "Testing DBI\n";

# ## vDCs
# my $aVdcView = OvomExtractor::getDummyVdcView();
# my $aVdc     = ODataCenter->new($aVdcView);
# 
## vms

OvomExtractor::collectorInit();

  # %inventory keys = vDCs, vms, hosts, clusters, folders


my $someDataCenterViews     = OvomExtractor::getViewsFromCsv('vDCs');
my $someVirtualMachineViews = OvomExtractor::getViewsFromCsv('vms');
my $someHostViews           = OvomExtractor::getViewsFromCsv('hosts');
my $someClusterViews        = OvomExtractor::getViewsFromCsv('clusters');
my $someFolderViews         = OvomExtractor::getViewsFromCsv('folders');

foreach my $aView (@$someDataCenterViews) {
  my $aEntity = ODataCenter->new($aView);
#  print "vDC : name = "            . $aEntity->{name}            . " moref = "         . $aEntity->{mo_ref}        . " parent = " . $aEntity->{parent}
#           . " datastoreFolder = " . $aEntity->{datastoreFolder} . " vmFolder = "      . $aEntity->{vmFolder}
#           . " hostFolder = "      . $aEntity->{hostFolder}      . " networkFolder = " . $aEntity->{networkFolder} . "\n";
}
foreach my $aView (@$someVirtualMachineViews) {
  my $aEntity = OVirtualMachine->new($aView);
  print "VM : name = " . $aEntity->{name} . " moref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someHostViews) {
  my $aEntity = OHost->new($aView);
  print "Host : name = " . $aEntity->{name} . " moref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someClusterViews) {
  my $aEntity = OCluster->new($aView);
  print "Cluster : name = " . $aEntity->{name} . " moref = " . $aEntity->{mo_ref} . " parent = " . $aEntity->{parent} . "\n";
}
foreach my $aView (@$someFolderViews) {
  my $aEntity = OFolder->new($aView);
  my $parent = defined($aEntity->{parent}) ? $aEntity->{parent} : '';
  print "Folder : name = " . $aEntity->{name} . " moref = " . $aEntity->{mo_ref} . " parent = $parent\n";
}

OvomExtractor::collectorStop();

# 
# ## hosts
# my $aHostView = OvomExtractor::getDummyHostView();
# my $aHost = OHost->new($aHostView);
# 
# ## clusters
# my $aClusterView = OvomExtractor::getDummyClusterView();
# my $aCluster = OCluster->new($aClusterView);
# 
# ## folders
# my $aFolderView = OvomExtractor::getDummyFolderView();
# my $aFolder = OFolder->new($aFolderView);


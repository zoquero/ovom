package OInventory;
use strict;
use warnings;

use Exporter;
use Cwd 'abs_path';
use File::Basename;
use POSIX qw/strftime/;  ## time string to rotate logs
use Time::Piece;
use IO::Handle;          ## autoflush
use Time::HiRes;         ## gettimeofday
use VMware::VIRuntime;
use Scalar::Util qw(looks_like_number);
use File::Copy qw(move); ## move to rotate logs

# Our packages
use OvomDao;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;

# Mocking views to load entities:
use OMockView::OMockVirtualMachineView;
use OMockView::OMockClusterView;
use OMockView::OMockHostView;
use OMockView::OMockDatacenterView;
use OMockView::OMockFolderView;
use OMockView::OMockVirtualMachineView;


our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( updateInventory getLatestPerformance pickerInit pickerStop readConfiguration log );

# # Functions that are exported by default:
# our @EXPORT = qw( getLatestPerformance );

our $csvSep = ";";
our %configuration;
our %ovomGlobals;
#
# Hash with the discovered objects on the vCenter
#
# keys: Datacenter, VirtualMachine, HostSystem, ClusterComputeResource, Folder
#      (VIM view names)
# components: array of references to objects of the key type
#
our %inventory = ();
#
# Hash with inventory database contents.
#
# keys: Datacenter, VirtualMachine, HostSystem, ClusterComputeResource, Folder
#      (VIM view names)
# components: array of references to objects of the key type
#
our %inventDb = ();

our @counterTypes = ("cpu", "mem", "net", "disk", "sys");
# our @entityTypes = ("Folder", "HostSystem", "ResourcePool", "VirtualMachine", "ComputeResource", "Datacenter", "ClusterComputeResource");
our @entityTypes = ("Folder", "Datacenter", "ClusterComputeResource",
                    "HostSystem", "VirtualMachine");

# vmname/last_hour/
# vmname/last_day/
# vmname/last_week/
# vmname/last_month/
# vmname/last_year/

# sub getIntervalNames {
#   my @intervalNames = split /;/, $configuration{'intervals.names'};
#   return \@intervalNames;
# }
# 
# 
# sub getIntervalWidths {
#   my @intervalWidths = split /;/, $configuration{'intervals.widths'};
#   return \@intervalWidths;
# }
# 
# 
# sub getSampleLengths {
#   my @sampleLengths = split /;/, $configuration{'intervals.sample_lengths'};
#   return \@sampleLengths;
# }


#
# Get a reference to the entity types array.
#
sub getEntityTypes {
  return \@entityTypes;
}

#
# Get a reference to the inventory hash
# (inventory objects from vCenter).
#
sub getInventory {
  return \%inventory;
}

#
# Get a reference to the inventDb hash
# (inventory objects from our inventory database).
#
sub getInventDb {
  return \%inventDb;
}

#
# Connect to vCenter.
#
# @return 1 error, 0 ok
#
sub connectToVcenter {

  if($configuration{'debug.mock.enabled'}) {
    OInventory::log(1, "In mocking mode. "
                     . "Now we should be connecting to vCenter...");
    return 1;
  }

  my $vCWSUrl = 'https://'
                . $OInventory::configuration{'vCenter.fqdn'}
                . '/sdk/webService';
  my $user = $ENV{'OVOM_VC_USERNAME'};
  my $pass = $ENV{'OVOM_VC_PASSWORD'};
  if ( ! defined($user) || $user eq '' ||  ! defined($pass) || $pass eq '') {
    OInventory::log(3, "Can't find username or password for vCenter "
                        . "in the environment. Read install instructions.");
    return 0;
  }
  eval {
    local $SIG{ALRM} = sub { die "Timeout connecting to vCenter" };
    my $maxSecs = $OInventory::configuration{'api.timeout'};
    OInventory::log(0, "Connecting to vCenter, with ${maxSecs}s timeout");
    alarm $maxSecs;
    Util::connect($vCWSUrl, $user, $pass);
    alarm 0;
  };
  if($@) {
    alarm 0;
    OInventory::log(3, "Errors connecting to $vCWSUrl: $@");
    return 0;
  }
  OInventory::log(1, "Successfully connected to $vCWSUrl");
  return 1;
}

#
# Disconnect from vCenter.
#
# @return 1 error, 0 ok
#
sub disconnectFromVcenter {

  if($configuration{'debug.mock.enabled'}) {
    OInventory::log(1, "In mocking mode. "
                     . "Now we should be disconnecting from vCenter...");
    return 1;
  }

  eval {
    local $SIG{ALRM} = sub { die "Timeout disconnecting from vCenter" };
    my $maxSecs = $OInventory::configuration{'api.timeout'};
    alarm $maxSecs;
    Util::disconnect();
    alarm 0;
  };
  if($@) {
    alarm 0;
    OInventory::log(3, "Errors disconnecting from vCenter : $@");
    return 0;
  }
  OInventory::log(1, "Successfully disconnected from vCenter");
  return 1;
}


#
# Insert, update or delete objects on database as needed.
#
# Inserts the new objects,
# updates the existing that have changes,
# noops on the existing objects that haven't changed,
# and deletes the ones that doesn't exist now in inventory
#
# It gets the current inventory from $OInventory::inventory
#
# It gets the inventory that was stored on DataBase for the last time
#    from $OInventory::inventDb
#
# It also updates the 'Virtual' Folder objects created in pushToInventory
# for the ClusterComputeResource and Datacenter 
#
# @return How many kinds of entityTypes had changes (not how many objects),
#         -1 if errors.
#
sub updateAsNeeded {
  my $databaseHashRef    = OInventory::getInventDb();

  #
  # Reference to the hash of refs to arrays of references
  # to objects (entities) found at vCenter.
  # The keys of the hash should be the entityTypes.
  #
  my $inventoryHashRef    = OInventory::getInventory();
  my $entityTypesArrayRef = OInventory::getEntityTypes();
  my $discoveredHashRef;
  my $somethingChanged = 0;
  #
  # Hashes containing a component for each type
  # holding an array (not a reference to array!) of references
  # to objects of that type. The hashes will have the same keys
  # than the inventory hash.
  #
  my %toInsert = ();
  my %toUpdate = ();
  my %toDelete = ();

  OInventory::log(0, "Running updateAsNeeded");

  ###################################
  # Preconditions for databaseHashRef
  ###################################
  if( ! ref($databaseHashRef) eq "HASH") {
    Carp::croak("updateAsNeeded: database contents parameter "
              . "should be a hash of references to arrays "
              . "and 'ref' tells '" . ref($databaseHashRef). "'");
    return -1;
  }
  if( !defined($databaseHashRef)) {
    Carp::croak("updateAsNeeded: missing parameter with database contents");
    return -1;
  }
  foreach my $entityType (@$entityTypesArrayRef) {
    if( ! defined($$databaseHashRef{$entityType})) {
      my $msg = "updateAsNeeded: database contents parameter "
                . "should be a hash of references to arrays "
                . "and its keys should be the entityTypes. "
                . "At least '$entityType' is undefined "
                . "If it's not the first run then probably "
                . "there's a bug somewhere in this software";
      OInventory::log(1, $msg);
#     return -1;
    }
    if ( ref($$databaseHashRef{$entityType}) ne 'ARRAY') {
      my $msg = "updateAsNeeded: database contents parameter "
                . "should be a hash of references to arrays "
                . "and its component $entityType "
                . "is not a reference to an array. "
                . "If it's not the first run then probably "
                . "there's a bug somewhere in this software";
      OInventory::log(1, $msg);
#     return -1;
    }
  }

  ####################################
  # Preconditions for loaded inventory
  ####################################
# OInventory::printInventoryForDebug();

  if( !defined($inventoryHashRef)) {
    Carp::croak("updateAsNeeded: inventory hash is not defined");
    return -1;
  }

  if( ! ref($inventoryHashRef) eq "HASH") {
    Carp::croak("updateAsNeeded: inventory hash should be a hash of arrays "
              . "and its not a reference to a HASH");
    return -1;
  }

  foreach my $entityType (@$entityTypesArrayRef) {
    if( ! defined($$inventoryHashRef{$entityType})) {
      Carp::croak("updateAsNeeded: The loaded inventory "
                . "should be a hash of arrays of references to objects "
                . "and the keys of the hash should be the entityTypes. "
                . "At least it's not defined the comp with key $entityType'");
      return -1;
    }
  }

  ####################################################################
  # Lets see what has to be inserted, updated or deleted for each type
  ####################################################################
  foreach my $entityType (@$entityTypesArrayRef) {
    #
    # Loop for each entity type
    #

    #
    # Refs to arrays, for commodity
    #
    my $discovered   = $$inventoryHashRef{$entityType};
    my $loadedFromDb = $$databaseHashRef{$entityType};
    my @loadedPositionsNotTobeDeleted = ();

    if( $#$discovered == -1 && $#$loadedFromDb == -1 ) {
      OInventory::log(2, "updateAsNeeded: NOP for $entityType: "
                          . "Got 0 entities discovered (mem inventory) "
                          . "and 0 entities in inventory DB. "
                          . "Is there anybody out there?");
      next;
    }

# print "DEBUG: $entityType : there are " . ($#$discovered + 1) . " discovered i " . ($#$loadedFromDb + 1) . " on BD\n";
  
    foreach my $aDiscovered (@$discovered) {
      my $found = 0;
      my $j = -1;
      foreach my $aLoadedFromDb (@$loadedFromDb) {

        $j++;
        my $r;
# print "DEBUG: ref aDiscovered   = ". ref($aDiscovered) . "\n";
# print "DEBUG: ref aLoadedFromDb = ". ref($aLoadedFromDb) . "\n";
# print "DEBUG: (j=$j)      \tcomparing " . $aDiscovered->toCsvRow() . " with " . $aLoadedFromDb->toCsvRow() . "\n";
        $r = $aDiscovered->compare($aLoadedFromDb);
        if ($r == -2) {
          # Errors
          return -1;
        }
        elsif ($r == 1) {
# print "DEBUG: It's equal. It hasn't to change in DB. Pushed position $j NOT to be deleted\n";
          # Equal
          push @loadedPositionsNotTobeDeleted, $j;
          $found = 1;
          last;
        }
        elsif ($r == 0) {
          # Changed (same mo_ref but some other attribute differs)
# print "DEBUG: It has to be UPDATED into DB. Pushed position $j NOT to be deleted\n";
          push @{$toUpdate{$entityType}}, $aDiscovered;
          push @loadedPositionsNotTobeDeleted, $j;
          $found = 1;
          last;
        }
        else {
          # $r == -1  =>  differ
        }
      }
  
      if (! $found) {
# print "DEBUG: It has to be INSERTED into DB: " .  $aDiscovered->toCsvRow() . "\n";
        push @{$toInsert{$entityType}}, $aDiscovered;
      }
    }
    for (my $i = 0; $i <= $#$loadedFromDb; $i++) {
      if ( ! grep /^$i$/, @loadedPositionsNotTobeDeleted ) {
        push @{$toDelete{$entityType}}, $$loadedFromDb[$i];
      }
    }

    #
    # Let's report what's going to be done:
    #
    my $str = ($#$discovered + 1)              . " ${entityType}s discovered "
                                               .           "(mem inventory), "
            . ($#$loadedFromDb + 1)            . " in inventory DB, "
            . ($#{$toInsert{$entityType}} + 1) . " toInsert, "
            . ($#{$toUpdate{$entityType}} + 1) . " toUpdate, "
            . ($#{$toDelete{$entityType}} + 1) . " toDelete";
    OInventory::log(1, "updateAsNeeded: $str ");

    if(   $#{$toInsert{$entityType}} > -1
       || $#{$toUpdate{$entityType}} > -1
       || $#{$toDelete{$entityType}} > -1) {
      $somethingChanged++;
    }
  }
  
  ####################################
  # Now let's update in the right way:
  # * 1) insert for each type
  # * 2) update for each type
  # * 3) delete for each type
  ####################################
  foreach my $entityType (@$entityTypesArrayRef) {
 
    # Let's work:
    OInventory::log(1, "updateAsNeeded: Inserting "
                          . ($#{$toInsert{$entityType}} + 1)
                          . " ${entityType}s")
      if $#{$toInsert{$entityType}} >= 0;

    if($entityType eq 'Folder') {
      # Let's keep parental integrity
      while (my $aEntity = popNextFolderWithParent(\@{$toInsert{$entityType}})) {
        if( ! OvomDao::insert($aEntity) ) {
          OInventory::log(3, "updateAsNeeded can't insert the entity "
                      . " with mo_ref '" . $aEntity->{mo_ref} . "'" );
          return -1;
        }
      }
      if($#{$toInsert{$entityType}} != -1) {
        my $s = "Something went wrong and couldn't get next "
              . "Folder with parent. Did you created "
              . "the initial root Folder? Read install instructions.";
        OInventory::log(3, $s);
        return -1;
      }
    }
    else {
      foreach my $aEntity (@{$toInsert{$entityType}}) {
#  print "DEBUG: Let's insert the entity " . $aEntity->toCsvRow . "\n";
        if( ! OvomDao::insert($aEntity) ) {
          OInventory::log(3, "updateAsNeeded can't insert the entity "
                              . "with mo_ref " . $aEntity->{mo_ref} );
          return -1;
        }
      }
    }
  }
  
  foreach my $entityType (@$entityTypesArrayRef) {
    OInventory::log(1, "updateAsNeeded: Updating "
                          . ($#{$toUpdate{$entityType}} + 1)
                          . " ${entityType}s")
      if $#{$toUpdate{$entityType}} >= 0;

    foreach my $aEntity (@{$toUpdate{$entityType}}) {

#  print "DEBUG: Let's update the entity " . $aEntity->toCsvRow . "\n";
      if( ! OvomDao::update($aEntity) ) {
        OInventory::log(3, "updateAsNeeded can't update the entity "
                            . " with mo_ref " . $aEntity->{mo_ref} );
        return -1;
      }

      #
      # Remember that the parent for the base folders for hosts, networks, VMs
      # and datastores are not folders, are its datacenters.
      # So in pushToInventory we also create a Folder object
      # for each Datacenter and ClusterComputeResource .
      #
      if( $entityType eq 'Datacenter' ) {
        #
        # Let's update the extra 'Virtual' OFolder object
        #
        my $extraFolderEntity = OFolder->cloneFromDatacenter($aEntity);
        if( ! OvomDao::update($extraFolderEntity) ) {
          OInventory::log(3, "updateAsNeeded can't update the 'virtual' "
                              . "entity with mo_ref "
                              . $extraFolderEntity->{mo_ref} );
          return -1;
        }
        OInventory::log(0, "Also updated the 'virtual' Folder for the "
                            . "Datacenter " . $extraFolderEntity->{mo_ref});
      }
      elsif( $entityType eq 'ClusterComputeResource' ) {
        #
        # Let's update the extra 'Virtual' OFolder object
        #
        my $extraFolderEntity = OFolder->cloneFromCluster($aEntity);
        if( ! OvomDao::update($extraFolderEntity) ) {
          OInventory::log(3, "updateAsNeeded can't update the 'virtual' "
                              . "entity with mo_ref "
                              . $extraFolderEntity->{mo_ref} );
          return -1;
        }
        OInventory::log(0, "Also updated the 'virtual' Folder for "
                            . "the Cluster " . $extraFolderEntity->{mo_ref});
      }
    }
  }
  
  foreach my $entityType (reverse @$entityTypesArrayRef) {

    OInventory::log(1, "updateAsNeeded: Deleting "
                          . ($#{$toDelete{$entityType}} + 1)
                          . " ${entityType}s")
      if $#{$toDelete{$entityType}} >= 0;

    foreach my $aEntity (@{$toDelete{$entityType}}) {
#  print "DEBUG: Let's delete the entity " . $aEntity->toCsvRow . "\n";
      if( ! OvomDao::delete($aEntity) ) {
        OInventory::log(3, "updateAsNeeded can't delete the entity "
                            . "with mo_ref " . $aEntity->{mo_ref} );
        return -1;
      }

      #
      # Remember that the parent for the base folders for hosts, networks, VMs
      # and datastores are not folders, are its datacenters.
      # So in pushToInventory we also create a Folder object
      # for each Datacenter and ClusterComputeResource .
      #
      if( $entityType eq 'Datacenter' ) {
        #
        # Let's delete the extra 'Virtual' OFolder object
        #
        my $extraFolderEntity = OFolder->cloneFromDatacenter($aEntity);
        if( ! OvomDao::delete($extraFolderEntity) ) {
          OInventory::log(3, "updateAsNeeded can't delete the 'virtual' entity "
                              . "with mo_ref " . $extraFolderEntity->{mo_ref} );
          return -1;
        }
        OInventory::log(0, "Also delete the 'virtual' Folder for the "
                              . "Datacenter " . $extraFolderEntity->{mo_ref});
      }
      elsif( $entityType eq 'ClusterComputeResource' ) {
        #
        # Let's delete the extra 'Virtual' OFolder object
        #
        my $extraFolderEntity = OFolder->cloneFromCluster($aEntity);
        if( ! OvomDao::delete($extraFolderEntity) ) {
          OInventory::log(3, "updateAsNeeded can't delete the 'virtual' "
                              . "entity with mo_ref "
                              . $extraFolderEntity->{mo_ref} );
          return -1;
        }
        OInventory::log(0, "Also deleted the 'virtual' Folder for "
                            . "the Cluster " . $extraFolderEntity->{mo_ref});
      }
    }
  }
  return $somethingChanged;
}

#
# Get next Folder that has parent and remove it from the array.
#
# @arg Reference to the array of references to entities
# @return a reference to the first entity with parent in the array (if ok)
#         undef (if errors)
#
sub popNextFolderWithParent {
  my $entities = shift;
  for(my $i = 0; $i <= $#$entities; $i++) {
    if ( ! defined($$entities[$i]->{parent})
        ||         $$entities[$i]->{parent} eq '' ) {

      OInventory::log(3, " Got the entity with mo_ref "
                . $$entities[$i]->{mo_ref}
                . " and name " . $$entities[$i]->{name}
                . " but without parent at popNextFolderWithParent");
      return undef;
    }
    my $aParent = OvomDao::loadEntity($$entities[$i]->{parent},
                                             'Folder');
    if (defined $aParent) {
      my $r = $$entities[$i];
      splice @$entities, $i, 1;
      return $r;
    }
  }
}


#
# Gets the contents of the inventory Database
#
# Stores it in the global hash %inventDb
#
# Precondition: must be previously connected to Database
#
# @return 1 if ok, 0 if errors
#
#
sub loadInventoryDatabaseContents {

  if(OvomDao::connected() != 1) {
    OInventory::log(3, "Must be previously correctly connected to Database");
    return 0;
  }
 
  foreach my $entityType (@entityTypes) {
    $OInventory::inventDb{$entityType} = [];
    OInventory::log(0, "Getting all ${entityType}s");
    my $entities = OvomDao::getAllEntitiesOfType($entityType);
    if (! defined($entities) ) {
      OInventory::log(3, "Errors getting ${entityType}s from DataBase");
      return 0;
    }
    push @{$OInventory::inventDb{$entityType}}, @$entities;
  }
  
  return 1;
}


#
# Update the inventory DB according to the discovered inventory from vCenter.
#
# It does it this way:
# * filling %inventory hash (from vCenter)
# * Connecting to Database
# * filling %inventDb  hash (from Database)
# * updating database contents
# * Disconnecting from Database
#
# @return 1 if ok, 0 if errors
#
sub updateOvomInventoryDatabaseFromVcenter {

  # Get both inventories (the alive and the one saved on DB for the last time)
  OInventory::log(1, "Let's read the inventory from the vCenter.");

  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $r = updateInventory();
  $eTime=Time::HiRes::time - $timeBefore;

  OInventory::log(1, "Profiling: Update inventory on mem from vCenter took "
                     . sprintf("%.3f", $eTime) . " s");

  if($r > 0) {
    OInventory::log(2, "The inventory has been updated on mem from vCenter");
  }
  elsif($r == 0) {
    OInventory::log(2, "The inventory has been revised "
                        . "but there we found no changes.");
    return 1;
  }
  else {
    OInventory::log(3, "Errors updating inventory");
    return 0;
  }
  
  OInventory::log(1, "Let's read the last inventory saved on DB.");
  $timeBefore=Time::HiRes::time;
  $r = loadInventoryDatabaseContents();
  $eTime=Time::HiRes::time - $timeBefore;

  OInventory::log(1, "Profiling: Get inventory from BD took "
                     . sprintf("%.3f", $eTime) . " s");
  
  if(! $r) {
    OInventory::log(3, "Errors getting inventory from DB");
    return 0;
  }
  else {
    OInventory::log(2, "The inventory database contents have been loaded");
  }
  
# print "\nDEBUG: Let's print inventory contents:\n";
# printInventoryForDebug(getInventory());
  
# print "\nDEBUG: Let's print inventory DB contents:\n";
# printInventoryForDebug(getInventDb());
  
  OInventory::log(1, "Let's Update inventory DB contents:");

  $timeBefore=Time::HiRes::time;
  $r = updateAsNeeded();
  $eTime=Time::HiRes::time - $timeBefore;

  OInventory::log(1, "Profiling: update inventory DB contents took "
                     . sprintf("%.3f", $eTime) . " s");

  if($r == -1) {
    OInventory::log(3, "Errors updating inventory DB contents.");
    return 0;
  }
  
  return 1;
}


#
# Pushes entities to the inventory hash.
#
# First loads new Entity Objects from each view
# and then pushes new objects to the inventory hash.
#
# @param Array of Views from VIM API
# @param string specifying the type.
#               It can be: Datacenter | VirtualMachine
#                        | HostSystem | ClusterComputeResource | Folder
# @return none
#
sub pushToInventory {
  my $entityViews = shift;
  my $type        = shift;
  foreach my $aEntityView (@$entityViews) {
    my $aEntity;
    if($type eq 'Datacenter') {
      #
      # The parent for the base folders for hosts, networks, VMs
      # and datastores are not folders, are its datacenters.
      # So we will create a Folder object also for each Datacenter.
      #

      #
      # First let's create the regular ODatacenter object
      #
      $aEntity = ODatacenter->newFromView($aEntityView);

      #
      # Now let's create the extra 'Virtual' OFolder object
      #
      my $extraFolderEntity = OFolder->cloneFromDatacenter($aEntity);
      push @{$inventory{'Folder'}}, $extraFolderEntity;
      OInventory::log(1, "Pushed a 'virtual' Folder for the Datacenter "
                            . $aEntityView->{name} . " with same mo_ref as a "
                            . "simple solution for base Folders that have its "
                            . "Datacenter as parent");
    }
    elsif($type eq 'VirtualMachine') {
      $aEntity = OVirtualMachine->newFromView($aEntityView);
    }
    elsif($type eq 'HostSystem') {
      $aEntity = OHost->newFromView($aEntityView);
    }
    elsif($type eq 'ClusterComputeResource') {
      #
      # The parent for the hosts of a cluster is its cluster.
      # So let's create a Folder object also for each ClusterComputeResource
      #

      #
      # First let's create the regular OCluster object
      #
      $aEntity = OCluster->newFromView($aEntityView);

      #
      # Now let's create the extra 'Virtual' OFolder object
      #
      my $extraFolderEntity = OFolder->cloneFromCluster($aEntity);
      push @{$inventory{'Folder'}}, $extraFolderEntity;
      OInventory::log(1, "Pushed a 'virtual' Folder for the Cluster "
                            . $aEntityView->{name} . " with same mo_ref as a "
                            . "simple solution for hosts of a cluster "
                            . "that have its cluster as parent");
    }
    elsif($type eq 'Folder') {
      $aEntity = OFolder->newFromView($aEntityView);

      if(! defined($aEntity->{parent})
         && $aEntity->{name}
            eq $OInventory::configuration{'root_folder.name'}
         && $aEntity->{mo_ref}
            eq $OInventory::configuration{'root_folder.mo_ref'} ) {
        OInventory::log(1, "pushToInventory: $type found without parent and "
            . "its name and mo_ref matches with the ones configured to be the "
            . "root for Datacenters (name '" . $aEntity->{name} . "', mo_ref '"
            . $aEntity->{mo_ref} ."'). To maintain the integrity of the "
            . "parentage in our hierarchy (db constraints) let's set itself "
            . "as its own parent, it's not accepted a NULL parent.");
        $aEntity->{parent} = $OInventory::configuration{'root_folder.mo_ref'};
      }
    }
    else {
      OInventory::log(3, "Unexpected type '$type' in pushToInventory");
    }

    push @{$inventory{$type}}, $aEntity;
  }
}


#
# Gets views from CSV files.
# Usefull for Mocking when debugging
#
# @arg $entityType
# @return undef if error, \@entities else
#
sub getViewsFromCsv {
  my $entityType = shift;
  my @entities;
  my ($csv, $csvHandler);
  my $mockingCsvBaseFolder =
         $OInventory::configuration{'debug.mock.inventExpRoot'}
         . "/" . $OInventory::configuration{'vCenter.fqdn'} ;

  if( $entityType eq "Datacenter"
   || $entityType eq "VirtualMachine"
   || $entityType eq "HostSystem"
   || $entityType eq "ClusterComputeResource"
   || $entityType eq "Folder") {
    $csv = "$mockingCsvBaseFolder/$entityType.csv";

    OInventory::log(0, "Reading $entityType entities from inventory CSV file "
                          . $csv . " for mocking");

    if( ! open($csvHandler, "<:encoding(UTF-8)", $csv) ) {
      OInventory::log(3, "Could not open mocking CSV file '$csv': $!");
      return undef;
    }

    while (my $line = <$csvHandler>) {
      chomp $line;
      next if $line =~ /^\s*$/;
      my @parts = split /$csvSep/, $line;
      if ($#parts < 0) {
        OInventory::log(3, "Can't parse this line '$line' on file '$csv': $!");
        if( ! close($csvHandler) ) {
          OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
        }
        return undef;
      }
      if( $entityType eq "Datacenter") {
        push @entities, OMockView::OMockDatacenterView->new(@parts);
      }
      elsif( $entityType eq "VirtualMachine") {
        push @entities, OMockView::OMockVirtualMachineView->new(@parts);
      }
      elsif( $entityType eq "HostSystem") {
        push @entities, OMockView::OMockHostView->new(@parts);
      }
      elsif( $entityType eq "ClusterComputeResource") {
        push @entities, OMockView::OMockClusterView->new(@parts);
      }
      elsif( $entityType eq "Folder") {
        push @entities, OMockView::OMockFolderView->new(@parts);
      }
      else {
        OInventory::log(3, "Unknown entity type '$entityType' "
                            . "passed to getViewsFromCsv");
        if( ! close($csvHandler) ) {
          OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
        }
        return undef;
      }
    }
    if( ! close($csvHandler) ) {
      OInventory::log(3, "Could not close mocking CSV file '$csv': $!");
      return undef;
    }
  }
  else {
    OInventory::log(3, "Unknown entity type '$entityType' "
                        . "passed to getViewsFromCsv");
    return undef;
  }
  
  return \@entities;
}


#
# Print %inventory to CSV files
#
# @arg (none)
# @return 1 error, 0 ok
#
sub inventory2Csv {
  my ($csv, $csvHandler);
  my $entityType;
  my($inventoryBaseFolder) = $OInventory::configuration{'inventory.export.root'}
                             . "/" . $OInventory::configuration{'vCenter.fqdn'};

  OInventory::log(1, "Let's write inventory into CSV files on "
                        . $inventoryBaseFolder);

  foreach my $aEntityType (@entityTypes) {
    $csv = "$inventoryBaseFolder/$aEntityType.csv";
    OInventory::log(0, "Writing inventory for $aEntityType entities "
                        . "on CSV file '$csv'");
    if( ! open($csvHandler, ">:utf8", $csv) ) {
      OInventory::log(3, "Could not open picker CSV file '$csv': $!");
      return 1;
    }
    foreach my $aEntity (@{$inventory{$aEntityType}}) {
      print $csvHandler $aEntity->toCsvRow() . "\n";
    }
    if( ! close($csvHandler) ) {
      OInventory::log(3, "Could not close picker CSV file '$csv': $!");
      return 1;
    }
  }
  # Ok!
  return 0;
}


#
# Gets inventory from vCenter and updates globals @hostArray and @vmArray .
#
# @return 0 error, 1 ok
#
sub updateInventory {
  my @hosts = ();
  my @vms   = ();
  my ($timeBefore, $eTime);

  ##############
  # Get entities
  ##############
  #   Folder | HostSystem | ResourcePool | VirtualMachine
  # | ComputeResource | Datacenter | ClusterComputeResource

  foreach my $aEntityType (@entityTypes) {
    OInventory::log(0, "Getting $aEntityType list");
    my $entityViews;
    $timeBefore=Time::HiRes::time;

    if($configuration{'debug.mock.enabled'}) {
      $entityViews = getViewsFromCsv($aEntityType);
      if( ! defined($entityViews) ) {
        OInventory::log(3, "Can't get $aEntityType list from CSV files");
        return 0;
      }
      OInventory::log(1, "Found " . ($#$entityViews + 1)
                            . " ${aEntityType}s on CSV files");
    }
    else {
      if ($aEntityType eq 'Datacenter') {
        eval {
          local $SIG{ALRM} = sub {die "Timeout calling Vim::find_entity_views"};
          my $maxSecs = $OInventory::configuration{'api.timeout'};
          alarm $maxSecs;
          $entityViews = Vim::find_entity_views(
            'view_type'  => $aEntityType,
#           'properties' => ['name','parent','datastoreFolder','vmFolder',
#                            'datastore','hostFolder','network','networkFolder']
            'properties' => ['name','parent','datastoreFolder',
                             'vmFolder','hostFolder','networkFolder']
          );
          alarm 0;
        };
        if ($@) {
          alarm 0;
          OInventory::log(3, "Vim::find_entity_views failed: $@");
          return 0;
        }
      }
      else {
        eval {
          local $SIG{ALRM} = sub {die "Timeout calling Vim::find_entity_views"};
          my $maxSecs = $OInventory::configuration{'api.timeout'};
          alarm $maxSecs;
          $entityViews = Vim::find_entity_views(
            'view_type'  => $aEntityType,
            'properties' => ['name','parent']
          );
          alarm 0;
        };
        if ($@) {
          alarm 0;
          OInventory::log(3, "Vim::find_entity_views failed: $@");
          return 0;
        }
      }
    }

    if($@) {
      OInventory::log(3, "Errors getting $aEntityType list: $@");
      return 0;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OInventory::log(1, "Profiling: $aEntityType list took "
                          . sprintf("%.3f", $eTime) . " s");
  
    if (!@$entityViews) {
      OInventory::log(3, "Can't find ${aEntityType}s in the vCenter");
    }
  
    # load the entity object and push it to $inventory{$aEntityType}
    @{$inventory{$aEntityType}} = (); # Let's clean it before
    pushToInventory($entityViews, $aEntityType);
  }

  ###############################
  # print %inventory to CSV files
  ###############################
  return 0 if(inventory2Csv());
  return 1;
}

#
# Print inventory to stdOut.
# Just for debugging purposes
#
sub printInventoryForDebug {
  my $inventoryRef = shift;
  die "printInventoryForDebug: Missing parameter with inventory ref"
    if(! defined($inventoryRef));
  die "printInventoryForDebug: The parameter must be a inventory ref"
    if(ref($inventoryRef) ne 'HASH');
  my %inventHash   = %$inventoryRef;

  print "DEBUG: Let's print inventory contents:\n";
  foreach my $aEntityType (@entityTypes) {
    die "printInventoryForDebug: Each component of the hash must be an array"
      if (ref($inventHash{$aEntityType}) ne 'ARRAY');
    my @ents = @{$inventHash{$aEntityType}};
    print "DEBUG: " . ($#ents + 1) . " ${aEntityType}s:\n";
    foreach my $aCom (@ents) {
      print "DEBUG:   " . $aCom->toCsvRow() . "\n";
    }
  }
}

#
# Create some folders
#
# @return 1 (ok) | 0 (errors)
#
sub createFoldersIfNeeded {
  my ($folder, $vCenterFolder);

  ##############################
  # Folders for performance data
  ##############################
  $folder = $OInventory::configuration{'perfdata.root'};
  if(! -d $folder) {
    OInventory::log(1, "Creating perfdata.root folder $folder");
    if(! mkdir $folder) {
      warn "Failed to create $folder: $!";
      return 0;
    }
  }
  $vCenterFolder = "$folder/" . $OInventory::configuration{'vCenter.fqdn'};
  if(! -d $vCenterFolder) {
    OInventory::log(1, "Creating perfdata.root folder for "
                        . "the vCenter $vCenterFolder");
    if(! mkdir $vCenterFolder) {
      warn "Failed to create $vCenterFolder: $!";
      return 0;
    }
  }
  $folder = $vCenterFolder . "/HostSystem";
  if(! -d $folder) {
    OInventory::log(1, "Creating perfdata.root folder for hosts of "
                        . "the vCenter $folder");
    if(! mkdir $folder) {
      warn "Failed to create $folder: $!";
      return 0;
    }
  }
  $folder = $vCenterFolder . "/VirtualMachine";
  if(! -d $folder) {
    OInventory::log(1, "Creating perfdata.root folder for VMs of "
                        . "the vCenter $folder");
    if(! mkdir $folder) {
      warn "Failed to create $folder: $!";
      return 0;
    }
  }

  ##############################
  # Folders for inventory
  ##############################
  $folder = $OInventory::configuration{'inventory.export.root'};
  if(! -d $folder) {
    OInventory::log(1, "Creating inventory.export.root folder $folder");
    if(! mkdir $folder) {
      warn "Failed to create $folder: $!";
      return 0;
    }
  }
  $vCenterFolder = "$folder/" . $OInventory::configuration{'vCenter.fqdn'};
  if(! -d $vCenterFolder) {
    OInventory::log(1, "Creating inventory.export.root folder for "
                        . "the vCenter $vCenterFolder");
    if(! mkdir $vCenterFolder) {
      warn "Failed to create $vCenterFolder: $!";
      return 0;
    }
  }
  return 1;
}

#
# Open log files
#
# @return 1 (ok) | 0 (errors)
#
sub openLogFiles {
  #
  # Regular log
  #
  if( ! defined($OInventory::ovomGlobals{'pickerMainLogFile'})) {
    $OInventory::ovomGlobals{'pickerMainLogFile'} =
      $OInventory::configuration{'log.folder'}
      . "/"
      . $OInventory::configuration{'log.main.filename'};
  }
  if(! open($OInventory::ovomGlobals{'pickerMainLogHandle'},
            ">>:utf8",
            $OInventory::ovomGlobals{'pickerMainLogFile'})) {
    warn "Could not open picker main log file '"
         . $OInventory::ovomGlobals{'pickerMainLogFile'} . "': $!";
    return 0;
  }
  $OInventory::ovomGlobals{'pickerMainLogHandle'}->autoflush;

  #
  # Error log
  #
  if(! defined($OInventory::ovomGlobals{'pickerErrorLogFile'})) {
    $OInventory::ovomGlobals{'pickerErrorLogFile'} =
      $OInventory::configuration{'log.folder'}
      . "/"
      . $OInventory::configuration{'log.error.filename'};
  }
  if(! open($OInventory::ovomGlobals{'pickerErrorLogHandle'},
            ">>:utf8",
            $OInventory::ovomGlobals{'pickerErrorLogFile'})) {
    warn "Could not open picker error log file '"
         . $OInventory::ovomGlobals{'pickerErrorLogHandle'} . "': $!";
    return 0;
  }
  $OInventory::ovomGlobals{'pickerErrorLogHandle'}->autoflush;
  return 1;
}

#
# Read configuration, initialize log and open connections to vCenter and DB
#
# @return 1 (ok) | 0 (errors)
#
sub pickerInit {
  my ($timeBefore, $eTime);

  #
  # Read configuration
  #
  if( ! readConfiguration() ) {
    warn "Could not read configuration";
    return 0;
  }

  #
  # Open log files
  #
  if(! openLogFiles()) {
    warn "Could not open log files";
    return 0;
  }

  OInventory::log(1, "Init: Configuration read and log handlers open");
  if(! createFoldersIfNeeded() ){
    warn "Could not create folders";
    return 0;
  }


  #
  # Connect to vC:
  #
  OInventory::log(1, "Let's connect to vCenter");
  $timeBefore=Time::HiRes::time;
  if(! OInventory::connectToVcenter()) {
    OInventory::log(3, "Cannot connect to vCenter.");
    warn "Can't connect to vCenter";
    return 0;
  }
  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Connecting to vCenter took "
                        . sprintf("%.3f", $eTime) . " s");

  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    OInventory::log(3, "Cannot connect to DataBase.");
    warn "Can't connect to DataBase";
    return 0;
  }
  return 1;
}

#
# Close log files
#
# @return 1 (ok) | 0 (errors)
#
sub closeLogFiles {
  my $e = 0;
  if(! close($OInventory::ovomGlobals{'pickerMainLogHandle'})) {
    warn "Could not close picker main log file '"
         . $OInventory::ovomGlobals{'pickerMainLogFile'} . "': $!";
    $e++;
  }

  if(! close($OInventory::ovomGlobals{'pickerErrorLogHandle'})) {
    warn "Could not close picker error log file '"
         . $OInventory::ovomGlobals{'pickerErrorLogFile'} . "': $!";
    $e++;
  }

  if($e) {
    return 0;
  }
  return 1;
}

#
# Close connections to vCenter and DB and close log file descriptors
#
# @return 1 (ok) | 0 (errors)
#
sub pickerStop {
  my ($timeBefore, $eTime);
  my $e = 0;
  OInventory::log(1, "Stopping picker");

  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    OInventory::log(3, "Cannot disconnect from DataBase");
    $e++;
  }

  #
  # Let's disconnect from vC
  #
  OInventory::log(0, "Let's disconnect from vCenter");
  $timeBefore=Time::HiRes::time;
  if(! OInventory::disconnectFromVcenter()) {
    warn "Could not disconnect from vCenter";
    $e++;
  }
  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Disconnecting from vCenter took "
                        . sprintf("%.3f", $eTime) . " s");

  OInventory::log(1, "Closing log files");
  if(! closeLogFiles()) {
    warn "Could not close log files";
    $e++;
  }

  if($e) {
    return 0;
  }
  else {
    return 1;
  }
}



#
# Close connections to vCenter and DB and close log file descriptors
#
# @return 1 (ok) | 0 (errors)
#
sub readConfiguration {
  my $confFile = dirname(abs_path($0)) . '/ovom.conf';
  if(! open(CONFIG, '<:encoding(UTF-8)', $confFile)) {
    warn "Can't read the configuration file $confFile: $!";
    return 0;
  }
  while (my $line = <CONFIG>) {
      chomp $line;                # no newline
      $line =~s/#.*//;            # no comments
      $line =~s/^\s+//;           # no leading white spaces
      $line =~s/\s+$//;           # no trailing white spaces
      next unless length($line);  # anything left?
      my ($var, $value) = split(/\s*=\s*/, $line, 2);
      $configuration{$var} = $value;
  } 
  if( ! close(CONFIG) ) {
    warn "Can't close the configuration file $confFile: $!";
    return 0;
  }
  return 1;
}


#
# Rotate log files 
#
# No arguments, filenames and limits are set in configuration
#
# @return 1 (ok) | 0 (errors)
#
sub rotateLogFiles {
  # Main log
  my($mlf) = $OInventory::configuration{'log.main.filename'};
  my($clf) = $OInventory::configuration{'log.folder'} . "/$mlf";
  my($maxMainLogSizeBytes)
    = $OInventory::configuration{'log.main.maxSizeBytes'};

  if(! rotateFile($clf, $maxMainLogSizeBytes)) {
    warn "Can't rotate main log file";
    return 0;
  }

  # Error log
  my($elf)  = $OInventory::configuration{'log.error.filename'};
  my($celf) = $OInventory::configuration{'log.folder'} . "/$elf";
  my($maxErrLogSizeBytes)
    = $OInventory::configuration{'log.error.maxSizeBytes'};

  if(! rotateFile($celf, $maxErrLogSizeBytes)) {
    warn "Can't rotate error log file";
    return 0;
  }
  return 1;
} 

#
# Rotate file if needed
#
# @arg path to log file
# @arg max size in bytes
# @return 1 (ok) | 0 (errors)
#
sub rotateFile($$) {
  my $filename       = shift;
  my $maxSizeInBytes = shift;
  if(! defined($filename) || $filename eq '') {
    warn "rotateFile: Missing or empty 1st arg: filename ";
    return 0;
  }
  if(! defined($maxSizeInBytes) || ! looks_like_number($maxSizeInBytes)) {
    OInventory::log(3, "rotateFile: 2nd arg (maxSizeInBytes) doesn't seem a #");
    return 0;
  }

  my @statOut = stat $filename;
  if ($#statOut == -1) {
    warn "Can't 'stat' file $filename";
    return 0;
  }
  if ($#statOut < 7) {
    warn "Errors calling 'stat' on file $filename";
    return 0;
  }
  my $size   = $statOut[7];
  my $nowStr = strftime('%Y%m%d_%H%M%S', gmtime);
  my $newFilename = $filename . ".$nowStr";

  if($size > $maxSizeInBytes) {
    if(-e $newFilename) {
      warn "Can't rotate $filename because $newFilename already exists";
      return 0;
    }
    if(! move($filename, $newFilename)) {
      warn "Errors moving $filename into $newFilename: $!";
      return 0;
    }
#   warn "$filename rotated to $newFilename";
  }
  return 1;
}


#
# Print a log message
#
# @arg log level 
#        0 : debug
#        1 : info
#        2 : warning
#        3 : error
# @arg message
#
sub log ($$) {
  my ($logLevel, $msg) = @_;
  return if($OInventory::configuration{'log.level'} gt $logLevel);

  my $nowStr = strftime('%Y%m%d_%H%M%S', gmtime);
  # gmtime instead of localtime, we want ~UTC

  my $crit;
  if ($logLevel      == 0) {
    $crit = "DEBUG";
  } elsif ($logLevel == 1) {
    $crit = "INFO";
  } elsif ($logLevel == 2) {
    $crit = "WARNING";
  } elsif ($logLevel == 3) {
    $crit = "ERROR";
  } else {
    $crit = "UNKNOWN";
  }

  my $logHandle;
  my $duplicate = 0;
  if($logLevel == 3) {
    # Error !
    $logHandle = $OInventory::ovomGlobals{'pickerErrorLogHandle'};
    if($OInventory::configuration{'log.duplicateErrors'}) {
      $duplicate = 1;
    }
  }
  else {
    # Main log
    $logHandle = $OInventory::ovomGlobals{'pickerMainLogHandle'};
  }
  print $logHandle "${nowStr}Z: [$crit] $msg\n";

  if($duplicate) {
    $logHandle = $OInventory::ovomGlobals{'pickerMainLogHandle'};
    print $logHandle "${nowStr}Z: [$crit] $msg\n";
  }
}

sub watchOut {
  my @files = glob("GLOB*");
  if ($#files >= 0) {
    Carp::croak "found!";
  }
}

1;

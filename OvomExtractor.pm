package OvomExtractor;
use strict;
use warnings;

use Exporter;
use Cwd 'abs_path';
use File::Basename;
use POSIX qw/strftime/;
use Time::Piece;
use IO::Handle;  ## autoflush
use Time::HiRes; ## gettimeofday
use VMware::VIRuntime;

# Our packages
use OvomDao;

# Our entities:
use ODatacenter;
use OFolder;
use OCluster;
use OHost;
use OVirtualMachine;

# Mocking views to load entities:
use OMockVirtualMachineView;
use OMockClusterView;
use OMockHostView;
use OMockDatacenterView;
use OMockFolderView;
use OMockVirtualMachineView;


our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( updateInventory getLatestPerformance collectorInit collectorStop readConfiguration log );

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
our @entityTypes = ("Folder", "Datacenter", "ClusterComputeResource", "HostSystem", "VirtualMachine");

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

sub connect {

  if($configuration{'debug.mock.enabled'}) {
    OvomExtractor::log(1, "In mocking mode. Now we should be connecting to a vCenter...");
    return 0;
  }

  my $vCWSUrl = 'https://'
                . $OvomExtractor::configuration{'vCenter.fqdn'}
                . '/sdk/webService';
  my $user = $ENV{'OVOM_VC_USERNAME'};
  my $pass = $ENV{'OVOM_VC_PASSWORD'};
  if ( ! defined($user) || $user eq '' ||  ! defined($pass) || $pass eq '') {
    OvomExtractor::log(3, "Can't find username or password for vCenter "
                        . "in the environment. Read install instructions.");
    return 1;
  }
  eval {
    Util::connect($vCWSUrl, $user, $pass);
  };
  if($@) {
    OvomExtractor::log(3, "Errors connecting to $vCWSUrl: $@");
    return 1;
  }
  OvomExtractor::log(1, "Successfully connected to $vCWSUrl");
  return 0;
}


sub disconnect {

  if($configuration{'debug.mock.enabled'}) {
    OvomExtractor::log(1, "In mocking mode. Now we should be disconnecting from a vCenter...");
    return 0;
  }

  eval { Util::disconnect(); };
  if($@) {
    OvomExtractor::log(3, "Errors disconnecting from vCenter : $@");
    return 1;
  }
  OvomExtractor::log(1, "Successfully disconnected from vCenter");
  return 0;
}


#
# Insert, update or delete objects on database as needed.
#
# Inserts the new objects,
# updates the existing that have changes,
# noops on the existing objects that haven't changed,
# and deletes the ones that doesn't exist now in inventory
#
# It gets the current inventory from $OvomExtractor::inventory
#
# It gets the inventory that was stored on DataBase for the last time
#    from $OvomExtractor::inventDb
#
# @return How many kinds of entityTypes had changes (not how many objects),
#         -1 if errors.
#
sub updateAsNeeded {
  my $databaseHashRef    = OvomExtractor::getInventDb();

  #
  # Reference to the hash of refs to arrays of references
  # to objects (entities) found at vCenter.
  # The keys of the hash should be the entityTypes.
  #
  my $inventoryHashRef    = OvomExtractor::getInventory();
  my $entityTypesArrayRef = OvomExtractor::getEntityTypes();
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

  OvomExtractor::log(0, "Running updateAsNeeded");

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
      OvomExtractor::log(1, $msg);
#     return -1;
    }
    if ( ref($$databaseHashRef{$entityType}) ne 'ARRAY') {
      my $msg = "updateAsNeeded: database contents parameter "
                . "should be a hash of references to arrays "
                . "and its component $entityType "
                . "is not a reference to an array. "
                . "If it's not the first run then probably "
                . "there's a bug somewhere in this software";
      OvomExtractor::log(1, $msg);
#     return -1;
    }
  }

  ####################################
  # Preconditions for loaded inventory
  ####################################
# OvomExtractor::printInventoryForDebug();

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
      OvomExtractor::log(2, "updateAsNeeded: NOP for $entityType: "
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
    OvomExtractor::log(1, "updateAsNeeded: $str ");

    if($#{$toInsert{$entityType}} > -1 || $#{$toUpdate{$entityType}} > -1 || $#{$toDelete{$entityType}} > -1) {
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
    OvomExtractor::log(0, "updateAsNeeded: Inserting "
                          . ($#{$toInsert{$entityType}} + 1) . " ${entityType}s") if $#{$toInsert{$entityType}} >= 0;

    if($entityType eq 'Folder') {
      # Let's keep parental integrity
      while (my $aEntity = popNextFolderWithParent(\@{$toInsert{$entityType}})) {
        if( ! OvomDao::insert($aEntity) ) {
          OvomExtractor::log(3, "updateAsNeeded can't insert the entity "
                      . " with mo_ref '" . $aEntity->{mo_ref} . "'" );
          return -1;
        }
      }
      if($#{$toInsert{$entityType}} != -1) {
        my $s = "Something went wrong and couldn't get next "
              . "Folder with parent. Did you created "
              . "the initial root Folder? Read install instructions.";
        OvomExtractor::log(3, $s);
        return -1;
      }
    }
    else {
      foreach my $aEntity (@{$toInsert{$entityType}}) {
#  print "DEBUG: Let's insert the entity " . $aEntity->toCsvRow . "\n";
        if( ! OvomDao::insert($aEntity) ) {
          OvomExtractor::log(3, "updateAsNeeded can't insert the entity with mo_ref "
                      . $aEntity->{mo_ref} );
          return -1;
        }
      }
    }
  }
  
  foreach my $entityType (@$entityTypesArrayRef) {
    OvomExtractor::log(0, "updateAsNeeded: Updating "
                          . ($#{$toUpdate{$entityType}} + 1) . " ${entityType}s") if $#{$toUpdate{$entityType}} >= 0;
    foreach my $aEntity (@{$toUpdate{$entityType}}) {
#  print "DEBUG: Let's update the entity " . $aEntity->toCsvRow . "\n";
      if( ! OvomDao::update($aEntity) ) {
        OvomExtractor::log(3, "updateAsNeeded can't update the entity with mo_ref "
                    . $aEntity->{mo_ref} );
        return -1;
      }
    }
  }
  
  foreach my $entityType (@$entityTypesArrayRef) {
    OvomExtractor::log(0, "updateAsNeeded: Deleting "
                          . ($#{$toDelete{$entityType}} + 1) . " ${entityType}s") if $#{$toDelete{$entityType}} >= 0;
    foreach my $aEntity (@{$toDelete{$entityType}}) {
#  print "DEBUG: Let's delete the entity " . $aEntity->toCsvRow . "\n";
      if( ! OvomDao::delete($aEntity) ) {
        OvomExtractor::log(3, "updateAsNeeded can't delete the entity with mo_ref "
                    . $aEntity->{mo_ref} );
        return -1;
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
    if ( ! defined($$entities[$i]->{parent}) || $$entities[$i]->{parent} eq '' ) {
      Carp::croak("Got the entity with mo_ref " . $$entities[$i]->{mo_ref}
                . " and name " . $$entities[$i]->{name}
                . " but without parent at popNextFolderWithParent");
      return undef;
    }
    my $aParent = OvomDao::loadEntityByMoRef($$entities[$i]->{parent}, 'OFolder');
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
    OvomExtractor::log(3, "Must be previously connected to Database");
    return 0;
  }
 
  foreach my $entityType (@entityTypes) {
#   $OvomExtractor::inventDb{$entityType} = \();
    $OvomExtractor::inventDb{$entityType} = [];
    OvomExtractor::log(0, "Getting all ${entityType}s");
    my $entities = OvomDao::getAllEntitiesOfType($entityType);
    if (! defined($entities) ) {
      OvomDao::transactionRollback();
      OvomDao::disconnect();
      OvomExtractor::log(3, "Errors getting ${entityType}s from DataBase");
      return 0;
    }

    push @{$OvomExtractor::inventDb{$entityType}}, @$entities;
  }
  
  return 1;
}


#
# Updates the inventory DB according to the discovered inventory from vCenter.
#
# @arg 
#
sub updateInventoryDatabase {
  my $inventDb = shift;
  die "updateInventoryDatabase still unimplemented";
}


#
# Pushes entities to the inventory hash.
#
# First loads new Entity Objects from each view
# and then pushes new objects to the inventory hash.
#
# @param Array of Views from VIM API
# @param string specifying the type.
#               It can be: Datacenter | VirtualMachine | HostSystem | ClusterComputeResource | Folder
# @return none
#
sub pushToInventory {
  my $entityViews = shift;
  my $type    = shift;
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
      OvomExtractor::log(0, "Pushed a 'virtual' Folder for the Datacenter "
                            . $aEntityView->{name} . " with same mo_ref as a "
                            . "workaround for base Folders that have its "
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
      OvomExtractor::log(0, "Pushed a 'virtual' Folder for the Cluster "
                            . $aEntityView->{name} . " with same mo_ref as a "
                            . "workaround for hosts of a cluster that have its "
                            . "cluster as parent");
    }
    elsif($type eq 'Folder') {
      $aEntity = OFolder->newFromView($aEntityView);

      if(! defined($aEntity->{parent})
         && $aEntity->{name}
            eq $OvomExtractor::configuration{'root_folder.name'}
         && $aEntity->{mo_ref}
            eq $OvomExtractor::configuration{'root_folder.mo_ref'} ) {
        OvomExtractor::log(1, "pushToInventory: The $type with name '"
          . $aEntity->{name} . "' and mo_ref '" . $aEntity->{mo_ref}
          . "' hasn't parent and it seems to be the root for Datacenters. "
          . "It's a known problem for the parentage of our hierarchy. "
          . "Let's set itself as its parent as a workaround.");
        $aEntity->{parent} =
          $OvomExtractor::configuration{'root_folder.mo_ref'};
      }
    }
    else {
      OvomExtractor::log(3, "Unexpected type '$type' in pushToInventory");
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
  # %inventory keys = Datacenter, VirtualMachine, HostSystem, ClusterComputeResource, Folder

  my $entityType = shift;
  my @entities;
  my ($csv, $csvHandler);
  my $mockingCsvBaseFolder = $OvomExtractor::configuration{'debug.mock.inventExpRoot'}
                             . "/" . $OvomExtractor::configuration{'vCenter.fqdn'} ;

  if( $entityType eq "Datacenter"
   || $entityType eq "VirtualMachine"
   || $entityType eq "HostSystem"
   || $entityType eq "ClusterComputeResource"
   || $entityType eq "Folder") {
    $csv = "$mockingCsvBaseFolder/$entityType.csv";

    OvomExtractor::log(0, "Reading $entityType entities from inventory CSV file "
                          . $csv . " for mocking");

    if( ! open($csvHandler, "<", $csv) ) {
      OvomExtractor::log(3, "Could not open mocking CSV file '$csv': $!");
      return undef;
    }

    local $_;
    while (<$csvHandler>) {
      chomp;
      next if /^\s*$/;
      my @parts = split /$csvSep/;
      if ($#parts < 0) {
        OvomExtractor::log(3, "Can't parse this line '$_' on file '$csv': $!");
        if( ! close($csvHandler) ) {
          OvomExtractor::log(3, "Could not close mocking CSV file '$csv': $!");
        }
        return undef;
      }
      if( $entityType eq "Datacenter") {
        push @entities, OMockDatacenterView->new(@parts);
      }
      elsif( $entityType eq "VirtualMachine") {
        push @entities, OMockVirtualMachineView->new(@parts);
      }
      elsif( $entityType eq "HostSystem") {
        push @entities, OMockHostView->new(@parts);
      }
      elsif( $entityType eq "ClusterComputeResource") {
        push @entities, OMockClusterView->new(@parts);
      }
      elsif( $entityType eq "Folder") {
        push @entities, OMockFolderView->new(@parts);
      }
      else {
        OvomExtractor::log(3, "Unknown entity type '$entityType' "
                            . "passed to getViewsFromCsv");
        if( ! close($csvHandler) ) {
          OvomExtractor::log(3, "Could not close mocking CSV file '$csv': $!");
        }
        return undef;
      }
    }
    if( ! close($csvHandler) ) {
      OvomExtractor::log(3, "Could not close mocking CSV file '$csv': $!");
      return undef;
    }
  }
  else {
    OvomExtractor::log(3, "Unknown entity type '$entityType' "
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
  my($inventoryBaseFolder) = $OvomExtractor::configuration{'inventory.export.root'}
                             . "/" . $OvomExtractor::configuration{'vCenter.fqdn'} ;

  OvomExtractor::log(0, "Let's write inventory into CSV files on "
                        . $inventoryBaseFolder);

  # %inventory keys = Datacenter, VirtualMachine, HostSystem, ClusterComputeResource, Folder
  foreach my $aEntityType (@entityTypes) {
    $csv = "$inventoryBaseFolder/$aEntityType.csv";
    OvomExtractor::log(0, "Writing inventory for $aEntityType entities "
                        . "on CSV file '$csv'");
    if( ! open($csvHandler, ">", $csv) ) {
      OvomExtractor::log(3, "Could not open collector CSV file '$csv': $!");
      return 1;
    }
    foreach my $aEntity (@{$inventory{$aEntityType}}) {
      print $csvHandler $aEntity->toCsvRow() . "\n";
    }
    if( ! close($csvHandler) ) {
      OvomExtractor::log(3, "Could not close collector CSV file '$csv': $!");
      return 1;
    }
  }
  # Ok!
  return 0;
}


#
# Gets inventory from vCenter and updates globals @hostArray and @vmArray .
#
# @return 1 error, 0 ok
#
sub updateInventory {
  my @hosts = ();
  my @vms   = ();
  my ($timeBefore, $eTime);

  #
  # Let's connect to vC:
  #
  OvomExtractor::log(0, "Connecting to vCenter");
  $timeBefore=Time::HiRes::time;
  return 1 if(OvomExtractor::connect());
  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: Connecting to vCenter took "
                        . sprintf("%.3f", $eTime) . " s");

  ##############
  # Get entities
  ##############
  # Folder | HostSystem | ResourcePool | VirtualMachine | ComputeResource | Datacenter | ClusterComputeResource

  foreach my $aEntityType (@entityTypes) {
    OvomExtractor::log(0, "Getting $aEntityType list");
    my $entityViews;
    $timeBefore=Time::HiRes::time;

    if($configuration{'debug.mock.enabled'}) {
      $entityViews = getViewsFromCsv($aEntityType);
      if( ! defined($entityViews) ) {
        OvomExtractor::log(3, "Can't get $aEntityType list from CSV files");
        return 1;
      }
      OvomExtractor::log(0, "Found " . ($#$entityViews + 1)
                            . " ${aEntityType}s on CSV files");
    }
    else {
      if ($aEntityType eq 'Datacenter') {
        eval {
          $entityViews = Vim::find_entity_views(
            'view_type'  => $aEntityType,
#           'properties' => ['name','parent','datastoreFolder','vmFolder','datastore','hostFolder','network','networkFolder']
            'properties' => ['name','parent','datastoreFolder','vmFolder','hostFolder','networkFolder']
          );
        };
      }
      else {
        eval {
          $entityViews = Vim::find_entity_views(
            'view_type'  => $aEntityType,
            'properties' => ['name','parent']
          );
        };
      }
    }

    if($@) {
      OvomExtractor::log(3, "Errors getting $aEntityType list: $@");
      return 1;
    }
    $eTime=Time::HiRes::time - $timeBefore;
    OvomExtractor::log(1, "Profiling: $aEntityType list took "
                          . sprintf("%.3f", $eTime) . " s");
  
    if (!@$entityViews) {
      OvomExtractor::log(3, "Can't find ${aEntityType}s in the vCenter");
    }
  
    # load the entity object and push it to $inventory{$aEntityType}
    @{$inventory{$aEntityType}} = (); # Let's clean it before
    pushToInventory($entityViews, $aEntityType);
  }

  #
  # Let's disconnect to vC
  #
  OvomExtractor::log(0, "Disconnecting to vCenter");
  $timeBefore=Time::HiRes::time;
  return 1 if(OvomExtractor::disconnect());
  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: Disconnecting to vCenter took "
                        . sprintf("%.3f", $eTime) . " s");

  ###############################
  # print %inventory to CSV files
  ###############################
  return 1 if(inventory2Csv());
  return 0;
}

#
# Printt inventory to stdOut.
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
# Gets last performance data from hosts and VMs
#
# @return 0 ok, 1 errors
#
sub getLatestPerformance {
  OvomExtractor::log(1, "Updating performance");

  my($aHost, $aVM);
  foreach $aVM (@{$OvomExtractor::inventory{'VirtualMachine'}}) {
    if(getVmPerfs($aVM)) {
      OvomExtractor::log(3, "Errors getting performance from VM $aVM, "
                          . "moving to next");
      next;
    }
  }
  foreach $aHost (@{$OvomExtractor::inventory{'HostSystem'}}) {
    if(getHostPerfs($aHost)) {
      OvomExtractor::log(3, "Errors getting performance from Host $aHost, "
                          . "moving to next");
      next;
    }
  }
  return 0;
}


#
# Gets performance metrics for a VM
#
# @param VM name
# @return 0 ok, 1 errors (error running the command or data not available)
#
sub getVmPerfs {
#   my ($vm) = shift;
#   my ($counterType);
#   foreach $counterType (@OvomExtractor::counterTypes) {
#     my %vmPerfParams = ();
#     my $getVmPerfCommand = $configuration{'command.getPerf'} .
#                              " --server "      . $configuration{'vCenter.fqdn'} .
#                              " --countertype " . $counterType .
#                              " --vm "        . $vm;
#   
# print "DEBUG: ==== Let's get counter $counterType from vm $vm: ====\n";
#     OvomExtractor::log(0, "Getting counter '$counterType' from vm '$vm' running '$getVmPerfCommand'");
#     open CMD,'-|', $getVmPerfCommand or die "Can't run $getVmPerfCommand :" . $@;
#     my $line;
#     my ($counter, $instance, $description, $units, $sampleInfo);
#     my (@values) = ();
#     my ($previousSampleInfo) = ('');
#     my (@valuesRefArray)     = ();
#     my ($sampleInfoArrayRef);
#     my (@counterUnitsArray)  = ();
#     $sampleInfo = '';
#     while (defined($line=<CMD>)) {
#       my $value = '';
#       chomp $line;
#       next if($line =~ /^\s*$/);
# #print "DEBUG: $line\n";
#       if($line =~ /^\s*Counter\s*:\s*(.+)\s*$/) {
#         $counter = $1;
#       }
#       elsif($line =~ /^\s*Instance\s*:\s*(.+)\s*$/) {
#         $instance = $1;
#         $instance =~ s/^\s+//g;
#         $instance =~ s/\s+$//g;
#       }
#       elsif($line =~ /^\s*Description\s*:\s*(.+)\s*$/) {
#         $description = $1;
#       }
#       elsif($line =~ /^\s*Units\s*:\s*(.+)\s*$/) {
#         $units = $1;
#       }
#       elsif($line =~ /^\s*Sample info\s*:\s*(.+)\s*$/) {
#         $sampleInfo = $1;
#         if($previousSampleInfo ne '' && $previousSampleInfo ne $sampleInfo) {
#           OvomExtractor::log(3, "Different sampleInfo on two counters " . 
#                        "on same vm $vm, same counterType $counterType");
#           next;
#         }
#       }
#       elsif($line =~ /^\s*Value\s*:\s*(.+)\s*$/) {
#         my $valTmp = $1;
# #       OvomExtractor::log(0, "DEBUG.getVmPerfs(): Value pushed for $counter ($units): [" . $valTmp . "]\n");
#         push @valuesRefArray, \$valTmp;
#         push @counterUnitsArray, "$counter ($units)";
#       }
# #     else {
# #     }
# 
#     }
#     close CMD;
#     my $exit = $? >> 8;
#     if ($exit ne 0) {
#       OvomExtractor::log(3, "Bad exit status running $getVmPerfCommand to get vm performance");
#       return 1;
#     }
# 
#     if($#counterUnitsArray < 0 || $#valuesRefArray < 0) {
#       OvomExtractor::log(3, "Found no counter or no values on vm $vm, counterType $counterType");
#       return 1;
#     }
#     splice @counterUnitsArray, 0, 0, "epoch(s)"; # time in seconds since 1 Jan 1970 UTC
# 
#     $sampleInfoArrayRef = getSampleInfoArrayRefFromString($sampleInfo);
#     $vmPerfParams{'vm'}                 = $vm;
#     $vmPerfParams{'counterType'}          = $counterType;
#     $vmPerfParams{'counterUnitsRefArray'} = \@counterUnitsArray;
#     $vmPerfParams{'sampleInfoArrayRef'}   = $sampleInfoArrayRef;
#     $vmPerfParams{'valuesRefOfArrayOfArrayOfRefs'} = getValuesArrayOfArraysFromArrayOfStrings(\@valuesRefArray);
# # $instance, $description,
#     saveVmPerf(\%vmPerfParams);
#   }
  return 0;
}

#
# Gets performance metrics for a Host
#
# @param Host name
# @return 0 ok, 1 errors (error running the command or data not available)
#
sub getHostPerfs {
#   my ($host) = shift;
#   my ($counterType);
#   foreach $counterType (@OvomExtractor::counterTypes) {
#     my %hostPerfParams = ();
#     my $getHostPerfCommand = $configuration{'command.getPerf'} .
#                              " --server "      . $configuration{'vCenter.fqdn'} .
#                              " --countertype " . $counterType .
#                              " --host "        . $host;
#   
# print "DEBUG: ==== Let's get counter $counterType from host $host: ====\n";
#     OvomExtractor::log(0, "Getting counter '$counterType' from host '$host' running '$getHostPerfCommand'");
#     open CMD,'-|', $getHostPerfCommand or die "Can't run $getHostPerfCommand :" . $@;
#     my $line;
#     my ($counter, $instance, $description, $units, $sampleInfo);
#     my (@values) = ();
#     my ($previousSampleInfo) = ('');
#     my (@valuesRefArray)     = ();
#     my ($sampleInfoArrayRef);
#     my (@counterUnitsArray)  = ();
#     $sampleInfo = '';
#     while (defined($line=<CMD>)) {
#       my $value = '';
#       chomp $line;
#       next if($line =~ /^\s*$/);
# #print "DEBUG: $line\n";
#       if($line =~ /^\s*Counter\s*:\s*(.+)\s*$/) {
#         $counter = $1;
#       }
#       elsif($line =~ /^\s*Instance\s*:\s*(.+)\s*$/) {
#         $instance = $1;
#         $instance =~ s/^\s+//g;
#         $instance =~ s/\s+$//g;
#       }
#       elsif($line =~ /^\s*Description\s*:\s*(.+)\s*$/) {
#         $description = $1;
#       }
#       elsif($line =~ /^\s*Units\s*:\s*(.+)\s*$/) {
#         $units = $1;
#       }
#       elsif($line =~ /^\s*Sample info\s*:\s*(.+)\s*$/) {
#         $sampleInfo = $1;
#         if($previousSampleInfo ne '' && $previousSampleInfo ne $sampleInfo) {
#           OvomExtractor::log(3, "Different sampleInfo on two counters " . 
#                        "on same host $host, same counterType $counterType");
#           next;
#         }
#       }
#       elsif($line =~ /^\s*Value\s*:\s*(.+)\s*$/) {
#         my $valTmp = $1;
# #       OvomExtractor::log(0, "DEBUG.getHostPerfs(): Value pushed for $counter ($units): [" . $valTmp . "]\n");
#         push @valuesRefArray, \$valTmp;
#         push @counterUnitsArray, "$counter ($units)";
#       }
# #     else {
# #     }
# 
#     }
#     close CMD;
#     my $exit = $? >> 8;
#     if ($exit ne 0) {
#       OvomExtractor::log(3, "Bad exit status running $getHostPerfCommand to get host performance");
#       return 1;
#     }
# 
#     if($#counterUnitsArray < 0 || $#valuesRefArray < 0) {
#       OvomExtractor::log(3, "Found no counter or no values on host $host, counterType $counterType");
#       return 1;
#     }
#     splice @counterUnitsArray, 0, 0, "epoch(s)"; # time in seconds since 1 Jan 1970 UTC
# 
#     $sampleInfoArrayRef = getSampleInfoArrayRefFromString($sampleInfo);
#     $hostPerfParams{'host'}                 = $host;
#     $hostPerfParams{'counterType'}          = $counterType;
#     $hostPerfParams{'counterUnitsRefArray'} = \@counterUnitsArray;
#     $hostPerfParams{'sampleInfoArrayRef'}   = $sampleInfoArrayRef;
#     $hostPerfParams{'valuesRefOfArrayOfArrayOfRefs'} = getValuesArrayOfArraysFromArrayOfStrings(\@valuesRefArray);
# # $instance, $description,
#     saveHostPerf(\%hostPerfParams);
#   }
#   return 0;
}


sub saveVmPerf {
#   my ($vmPerfParamsRef) = shift;
#   my ($vm, $counterType, @counterUnitsArray, @sampleInfo, @valuesArrayOfArrayOfRefs);
#   my (@aValuesArray);
#   my ($fh);
#   $vm              = $vmPerfParamsRef->{'vm'};
#   $counterType       = $vmPerfParamsRef->{'counterType'};
#   @counterUnitsArray = @{$vmPerfParamsRef->{'counterUnitsRefArray'}};
#   @sampleInfo        = @{$vmPerfParamsRef->{'sampleInfoArrayRef'}};
#   @valuesArrayOfArrayOfRefs = @{$vmPerfParamsRef->{'valuesRefOfArrayOfArrayOfRefs'}};
#   OvomExtractor::log(0, "saveHostPerf: vm $vm , #counterUnitsArray=$#counterUnitsArray #sampleInfo=$#sampleInfo #valuesArrayOfArrayOfRefs=$#valuesArrayOfArrayOfRefs\n");
# 
#   foreach my $refToAnArrayOfValues (@valuesArrayOfArrayOfRefs) {
#     OvomExtractor::log(0, "saveHostPerf: A comp of rtaaov: $#{$refToAnArrayOfValues} comps, 0=${$refToAnArrayOfValues}[0],  1=${$refToAnArrayOfValues}[1], ${$refToAnArrayOfValues}[2] ...\n");
#   }
# 
#   my $outputFile = $OvomExtractor::configuration{'perfdata.root'} . "/" . $OvomExtractor::configuration{'vCenter.fqdn'} . "/vms/$vm/hour/$counterType.csv";
# 
#   my $headFile = $outputFile . ".head";
#   if (! -f $headFile) {
#     open($fh, ">", $headFile)
#       or die "Could not open file '$headFile': $!";
#     print $fh join (',', @counterUnitsArray) . "\n";
#     close($fh);
#   }
#   
#   open($fh, ">>", $outputFile)
#     or die "Could not open file '$outputFile': $!";
#   my $outputBuffer;
#   for my $i (0 .. $#sampleInfo) {
#     $outputBuffer = "$sampleInfo[$i]";
#     for my $j (0 .. $#valuesArrayOfArrayOfRefs) {
#       $outputBuffer .= ",${$valuesArrayOfArrayOfRefs[$j]}[$i]";
#     }
#     print $fh "$outputBuffer\n";
#   }
#   close($fh);
}


sub saveHostPerf {
#   my ($hostPerfParamsRef) = shift;
#   my ($host, $counterType, @counterUnitsArray, @sampleInfo, @valuesArrayOfArrayOfRefs);
#   my (@aValuesArray);
#   my ($fh);
#   $host              = $hostPerfParamsRef->{'host'};
#   $counterType       = $hostPerfParamsRef->{'counterType'};
#   @counterUnitsArray = @{$hostPerfParamsRef->{'counterUnitsRefArray'}};
#   @sampleInfo        = @{$hostPerfParamsRef->{'sampleInfoArrayRef'}};
#   @valuesArrayOfArrayOfRefs = @{$hostPerfParamsRef->{'valuesRefOfArrayOfArrayOfRefs'}};
#   OvomExtractor::log(0, "saveHostPerf: host $host , #counterUnitsArray=$#counterUnitsArray #sampleInfo=$#sampleInfo #valuesArrayOfArrayOfRefs=$#valuesArrayOfArrayOfRefs\n");
# 
#   foreach my $refToAnArrayOfValues (@valuesArrayOfArrayOfRefs) {
#     OvomExtractor::log(0, "saveHostPerf: A comp of rtaaov: $#{$refToAnArrayOfValues} comps, 0=${$refToAnArrayOfValues}[0],  1=${$refToAnArrayOfValues}[1], ${$refToAnArrayOfValues}[2] ...\n");
#   }
# 
#   my $outputFile = $OvomExtractor::configuration{'perfdata.root'} . "/" . $OvomExtractor::configuration{'vCenter.fqdn'} . "/hosts/$host/hour/$counterType.csv";
# 
#   my $headFile = $outputFile . ".head";
#   if (! -f $headFile) {
#     open($fh, ">", $headFile)
#       or die "Could not open file '$headFile': $!";
#     print $fh join (',', @counterUnitsArray) . "\n";
#     close($fh);
#   }
#   
#   open($fh, ">>", $outputFile)
#     or die "Could not open file '$outputFile': $!";
#   my $outputBuffer;
#   for my $i (0 .. $#sampleInfo) {
#     $outputBuffer = "$sampleInfo[$i]";
#     for my $j (0 .. $#valuesArrayOfArrayOfRefs) {
#       $outputBuffer .= ",${$valuesArrayOfArrayOfRefs[$j]}[$i]";
#     }
#     print $fh "$outputBuffer\n";
#   }
#   close($fh);
}

# sub getValuesArrayOfArraysFromArrayOfStrings {
#   my $valuesArrayOfStrings = shift;
#   my @arrayOfArrayRefs     = ();
#   foreach my $aValuesRefArray (@$valuesArrayOfStrings) {
#     my @aValuesArray = split /,/, $$aValuesRefArray;
# #   OvomExtractor::log(0, "DEBUG.getValuesArrayOfArraysFromArrayOfStrings(): $#aValuesArray values: [0]=$aValuesArray[0], [1]=$aValuesArray[1], [2]=$aValuesArray[2], ...\n");
#     push @arrayOfArrayRefs, \@aValuesArray;
#   }
#   return \@arrayOfArrayRefs;
# }

# sub getSampleInfoArrayRefFromString {
#   my $rawSampleInfoStrRef = shift;
#   my @sampleInfoArray = ();
#   my @tmpArray = split /,/, $rawSampleInfoStrRef;
#   my $z = 0;
# #print "DEBUG.gsiarfs: init\n";
#   for my $i (0 .. $#tmpArray) {
#     if ($i % 2) {
# #print "DEBUG:.gsiarfs: push = " . $tmpArray[$i] . "\n";
# 
#       # 2017-07-20T05:49:40Z
#       $tmpArray[$i] =~ s/Z$/\+0000/;
#       my $t = Time::Piece->strptime($tmpArray[$i], "%Y-%m-%dT%H:%M:%S%z");
# #     print $tmpArray[$i] . " = " . $t->epoch . "\n";
# 
#       push @sampleInfoArray, $t->epoch;
#     }
#   }
#   return \@sampleInfoArray;
# }

sub createFoldersIfNeeded {
  my ($folder, $vCenterFolder);

  ##############################
  # Folders for performance data
  ##############################
  $folder = $OvomExtractor::configuration{'perfdata.root'};
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfdata.root folder $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }
  $vCenterFolder = "$folder/" . $OvomExtractor::configuration{'vCenter.fqdn'};
  if(! -d $vCenterFolder) {
    OvomExtractor::log(1, "Creating perfdata.root folder for the vCenter $vCenterFolder");
    mkdir $vCenterFolder or die "Failed to create $vCenterFolder: $!";
  }
  $folder = $vCenterFolder . "/HostSystem";
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfdata.root folder for hosts of the vCenter $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }
  $folder = $vCenterFolder . "/VirtualMachine";
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfdata.root folder for VMs of the vCenter $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }

  ##############################
  # Folders for inventory
  ##############################
  $folder = $OvomExtractor::configuration{'inventory.export.root'};
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating inventory.export.root folder $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }
  $vCenterFolder = "$folder/" . $OvomExtractor::configuration{'vCenter.fqdn'};
  if(! -d $vCenterFolder) {
    OvomExtractor::log(1, "Creating inventory.export.root folder for the vCenter $vCenterFolder");
    mkdir $vCenterFolder or die "Failed to create $vCenterFolder: $!";
  }

}

sub collectorInit {
  readConfiguration();

  # Regular log
  my($clf) = $OvomExtractor::configuration{'log.folder'} . "/collector.main.log";
  $OvomExtractor::ovomGlobals{'collectorMainLogFile'} = $clf;

  open($OvomExtractor::ovomGlobals{'collectorMainLogHandle'}, ">>", $clf)
    or die "Could not open collector main log file '$clf': $!";

  $OvomExtractor::ovomGlobals{'collectorMainLogHandle'}->autoflush;

  # Error log
  my($celf) = $OvomExtractor::configuration{'log.folder'} . "/collector.error.log";
  $OvomExtractor::ovomGlobals{'collectorErrorLogFile'} = $celf;

  open($OvomExtractor::ovomGlobals{'collectorErrorLogHandle'}, ">>", $celf)
    or die "Could not open collector error log file '$celf': $!";

  $OvomExtractor::ovomGlobals{'collectorErrorLogHandle'}->autoflush;

  OvomExtractor::log(1, "Init: Configuration read and log handlers open");
  createFoldersIfNeeded();
}


sub collectorStop {
  OvomExtractor::log(1, "Stopping collector");

  close($OvomExtractor::ovomGlobals{'collectorMainLogHandle'})
    or die "Could not close collector main log file '" .
             $OvomExtractor::ovomGlobals{'collectorMainLogFile'} . "': $!";

  close($OvomExtractor::ovomGlobals{'collectorErrorLogHandle'})
    or die "Could not close collector error log file '" .
             $OvomExtractor::ovomGlobals{'collectorErrorLogFile'} . "': $!";
}


sub readConfiguration {
  my $confFile = dirname(abs_path($0)) . '/ovom.conf';
  open(CONFIG, '<:encoding(UTF-8)', $confFile)
    or die "Can't read the configuration file $confFile: $!";
  while (<CONFIG>) {
      chomp;              # no newline
      s/#.*//;            # no comments
      s/^\s+//;           # no leading white
      s/\s+$//;           # no trailing white
      next unless length; # anything left?
      my ($var, $value) = split(/\s*=\s*/, $_, 2);
      $configuration{$var} = $value;
  } 
  close(CONFIG) or die "Can't close the configuration file $confFile: $!";
} 


sub log ($$) {
  my ($logLevel, $msg) = @_;
  return if($OvomExtractor::configuration{'log.level'} gt $logLevel);

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
    $logHandle = $OvomExtractor::ovomGlobals{'collectorErrorLogHandle'};
    if($OvomExtractor::configuration{'log.duplicateErrors'}) {
      $duplicate = 1;
    }
  }
  else {
    # Main log
    $logHandle = $OvomExtractor::ovomGlobals{'collectorMainLogHandle'};
  }
  print $logHandle "${nowStr}Z: [$crit] $msg\n";

  if($duplicate) {
    $logHandle = $OvomExtractor::ovomGlobals{'collectorMainLogHandle'};
    print $logHandle "${nowStr}Z: [$crit] $msg\n";
  }
}

1;

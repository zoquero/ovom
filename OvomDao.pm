package OvomDao;
use strict;
use warnings;
use DBI;
use Time::HiRes; ## gettimeofday
use Carp;
use OInventory;


our $dbh;

###########################
# SQL Statements for Folder
###########################
our $sqlFolderSelectAll       = 'SELECT a.id, a.name, a.moref, b.moref '
                              . 'FROM folder as a '
                              . 'inner join folder as b where a.parent = b.id';
our $sqlFolderSelectByMoref   = 'SELECT a.id, a.name, a.moref, b.moref '
                              . 'FROM folder as a '
                              . 'inner join folder as b '
                              . 'where a.parent = b.id and a.moref = ?';
our $sqlFolderInsert          = 'INSERT INTO folder (name, moref, parent) '
                              . 'VALUES (?, ?, ?)';
                                                # moref is immutable
our $sqlFolderUpdate = 'UPDATE folder set name = ?, parent = ? where moref = ?';
our $sqlFolderDelete = 'DELETE FROM folder where moref = ?';

###############################
# SQL Statements for Datacenter
###############################
our $sqlDatacenterSelectAll   = 'SELECT a.id, a.name, a.moref, b.moref, '
                              . 'c.moref, d.moref, e.moref, f.moref '
                              . 'FROM datacenter as a  '
                              . 'inner join folder as b, folder as c, '
                              . 'folder as d, folder as e, folder as f '
                              . 'where a.parent = b.id '
                              . 'and a.datastore_folder = c.id '
                              . 'and a.vm_folder = d.id '
                              . 'and a.host_folder = e.id '
                              . 'and a.network_folder = f.id ';
our $sqlDatacenterSelectByMoref  = 'SELECT a.id, a.name, a.moref, b.moref, '
                                 . 'c.moref, d.moref, e.moref, f.moref '
                                 . 'FROM datacenter as a  '
                                 . 'inner join folder as b, folder as c, '
                                 . 'folder as d, folder as e, folder as f '
                                 . 'where a.parent = b.id and a.moref = ?'
                                 . 'and a.datastore_folder = c.id '
                                 . 'and a.vm_folder = d.id '
                                 . 'and a.host_folder = e.id '
                                 . 'and a.network_folder = f.id ';
our $sqlDatacenterInsert = 'INSERT INTO datacenter (name, moref, parent, '
                         . 'datastore_folder, vm_folder, '
                         . 'host_folder, network_folder) '
                         . 'VALUES (?, ?, ?, ?, ?, ?, ?)';
                                                # moref is immutable
our $sqlDatacenterUpdate = 'UPDATE datacenter '
                         . 'set name = ?, parent = ?, datastore_folder = ?, '
                         . 'vm_folder = ?, host_folder = ?, '
                         . 'network_folder = ? where moref = ?';
our $sqlDatacenterDelete = 'DELETE FROM datacenter where moref = ?';

#########################
# SQL Statements for Host
#########################
our $sqlHostSelectAll     = 'SELECT a.id, a.name, a.moref, b.moref '
                          . 'FROM host as a '
                          . 'inner join folder as b where a.parent = b.id';
our $sqlHostSelectByMoref = 'SELECT a.id, a.name, a.moref, b.moref '
                          . 'FROM host as a '
                          . 'inner join folder as b '
                          . 'where a.parent = b.id and a.moref = ?';
our $sqlHostInsert        = 'INSERT INTO host (name, moref, parent) '
                          . 'VALUES (?, ?, ?)';
                                                # moref is immutable
our $sqlHostUpdate = 'UPDATE host set name = ?, parent = ? where moref = ?';
our $sqlHostDelete = 'DELETE FROM host where moref = ?';

############################
# SQL Statements for Cluster
############################
our $sqlClusterSelectAll     = 'SELECT a.id, a.name, a.moref, b.moref '
                             . 'FROM cluster as a '
                             . 'inner join folder as b where a.parent = b.id';
our $sqlClusterSelectByMoref = 'SELECT a.id, a.name, a.moref, b.moref '
                             . 'FROM cluster as a '
                             . 'inner join folder as b '
                             . 'where a.parent = b.id and a.moref = ?';
our $sqlClusterInsert        = 'INSERT INTO cluster (name, moref, parent) '
                             . 'VALUES (?, ?, ?)';
                                                # moref is immutable
our $sqlClusterUpdate = 'UPDATE cluster '
                      . 'set name = ?, parent = ? where moref = ?';
our $sqlClusterDelete = 'DELETE FROM cluster where moref = ?';

###################################
# SQL Statements for VirtualMachine
###################################
our $sqlVirtualMachineSelectAll = 'SELECT a.id, a.name, a.moref, b.moref '
                                . 'FROM virtualmachine as a '
                                . 'inner join folder as b where a.parent = b.id';
our $sqlVirtualMachineSelectByMoref = 'SELECT a.id, a.name, a.moref, b.moref '
                                    . 'FROM virtualmachine as a '
                                    . 'inner join folder as b '
                                    . 'where a.parent = b.id and a.moref = ?';
our $sqlVirtualMachineInsert = 'INSERT INTO virtualmachine (name, moref, parent) '
                             . 'VALUES (?, ?, ?)';
                                                # moref is immutable
our $sqlVirtualMachineUpdate = 'UPDATE virtualmachine '
                             . 'set name = ?, parent = ? where moref = ?';
our $sqlVirtualMachineDelete = 'DELETE FROM virtualmachine where moref = ?';


#
# Connect to DataBase
#
# @return: 1 (ok), 0 (errors)
#
sub connect {
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $c = 0;

  ## Let's test before if this handle is already active:
  OInventory::log(0, "Testing if the db handle "
                      . "is already active before connecting to DB");
  eval {
    if($dbh && $dbh->{Active}) {
      $c = 1;
    }
  };
  if($@) {
    OInventory::log(3, "Errors checking if handle active "
                        . "before connecting to database: $@");
    return 0;
  }
  if($c == 1) {
    OInventory::log(3, "BUG! Handle already active before connecting to DB");
    return 0;
  }

  my $connStr  = "dbi:mysql:dbname=" . $OInventory::configuration{'db.name'}
               . ";host=" . $OInventory::configuration{'db.hostname'};
  my $username = $ENV{'OVOM_DB_USERNAME'}; 
  my $passwd   = $ENV{'OVOM_DB_PASSWORD'}; 
  if(  ! defined($username) || $username eq ''
    || ! defined($passwd)   || $passwd   eq '') {
    OInventory::log(3, "Can't get DB username or password (check environment "
                        . "variables OVOM_DB_USERNAME and OVOM_DB_PASSWORD)");
    return 0;
  }
  OInventory::log(0, "Connecting to database with connection string: '$connStr'");

  eval {
    $dbh = DBI->connect($connStr, $username, $passwd,
                        { AutoCommit => 0,
                          RaiseError=>1,
                          PrintError=>0,
                          ShowErrorStatement=>1
                        });
    if(! $dbh) {
      OInventory::log(3, "Errors connecting to Database: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors connecting to Database: $@");
    return 0
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: Connecting to DB "
                        . "with connection string: '$connStr' took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

#
# Disconnect to DataBase
#
# @return: 1 (ok), 0 (errors)
#
sub disconnect {
  OInventory::log(0, "Disconnecting from database");

  eval {
    if(! $dbh->disconnect() ) {
      OInventory::log(3, "Errors disconnecting from Database: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors disconnecting from Database: $@");
    return 0;
  }

  OInventory::log(1, "Successfully disconnected from database");
  return 1;
}

#
# Check if connected
#
# @return: 1 (connected), 0 (not connected), -1 (errors);
#
sub connected {
  my $r = -1;
  OInventory::log(0, "Checking if connected to database");

  eval {
    if($dbh && $dbh->{Active}) {
      $r = 1;
    }
    else {
      $r = 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors checking if connected to database: $@");
    return -1;
  }

  OInventory::log(1, "Successfully checked if connected to database ($r)");
  return $r;
}


#
# @deprecated We always use AutoCommit off
#
sub transactionBegin {
  OInventory::log(0, "Begining DB transaction");

  eval {
    $dbh->begin_work();
  };

  if($@) {
    OInventory::log(3, "Errors begining DB transaction: $@");
    return 1;
  }

  OInventory::log(1, "Successfully begined DB transaction");
  return 0;
}


#
# Commit transaction
#
# @return 1 if ok, 0 if errors.
#
sub transactionCommit {
  OInventory::log(0, "Commiting DB transaction");

  eval {
    if (! $dbh->commit() ) {
      OInventory::log(3, "Errors commiting DB transaction: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors commiting DB transaction: $@");
    return 0;
  }

  OInventory::log(1, "Successfully commited DB transaction");
  return 1;
}


sub transactionRollback {
  OInventory::log(0, "Rolling back DB transaction");

  eval {
    $dbh->commit();
  };

  if($@) {
    OInventory::log(3, "Errors rolling back DB transaction: $@");
    return 1;
  }

  OInventory::log(1, "Successfully rolled back DB transaction");
  return 0;
}

sub select {
die "deprecated method, must be deleted";
  OInventory::log(0, "Selecting from DB");

  eval {
    $dbh->commit();
    my $sth = $dbh->prepare('SELECT count(folder.id) FROM `folder`')
                or die "Couldn't prepare statement: " . $dbh->errstr;
    $sth->execute();

    # Read the matching records and print them out          
    my @data;
    while (@data = $sth->fetchrow_array()) {
      my $r = $data[0];
      print "\tHem llegit: $r\n";
    }

    if ($sth->rows == 0) {
      print "No names matched\n\n";
    }
  };

  if($@) {
    OInventory::log(3, "Errors getting from DB: $@");
    return 1;
  }

  OInventory::log(1, "Successfully selected from DB");
  return 0;
}


#
# Get all folders from DB.
#
# @return undef (if errors),
#         or a reference to array of references to entity objects (if ok)
#
sub getAllEntitiesOfType {
  my $entityType = shift;
  my @r = ();
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $stmt;
  my $sthRes;
  OInventory::log(0, "Getting all entities of type $entityType");

  if($entityType eq 'Folder') {
    $stmt = $sqlFolderSelectAll;
  }
  elsif($entityType eq 'Datacenter') {
    $stmt = $sqlDatacenterSelectAll;
  }
  elsif($entityType eq 'ClusterComputeResource') {
    $stmt = $sqlClusterSelectAll;
  }
  elsif($entityType eq 'HostSystem') {
    $stmt = $sqlHostSelectAll;
  }
  elsif($entityType eq 'VirtualMachine') {
    $stmt = $sqlVirtualMachineSelectAll;
  }
  else {
    Carp::croak("Not implemented in OvomDao.getAllEntitiesOfType");
    return undef;
  }

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement to get all ${entityType}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sthRes = $sth->execute();

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to get all ${entityType}s.");
      $sth->finish();
      return undef;
    }

    while (@data = $sth->fetchrow_array()) {
      my $e;
      if($entityType eq 'Folder') {
        $e = OFolder->new(\@data);
        push @r, $e;
      }
      elsif($entityType eq 'Datacenter') {
        $e = ODatacenter->new(\@data);
        push @r, $e;
      }
      elsif($entityType eq 'ClusterComputeResource') {
        $e = OCluster->new(\@data);
        push @r, $e;
      }
      elsif($entityType eq 'HostSystem') {
        $e = OHost->new(\@data);
        push @r, $e;
      }
      elsif($entityType eq 'VirtualMachine') {
        $e = OVirtualMachine->new(\@data);
        push @r, $e;
      }
      else {
        Carp::croak("Not implemented for $entityType "
                  . "in OvomDao.getAllEntitiesOfType");
        return undef;
      }
    }
  };

  if($@) {
    OInventory::log(3, "Errors getting all ${entityType}s from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: select all ${entityType}s took "
                        . sprintf("%.3f", $eTime) . " s "
                        . "and returned " . ($#r + 1) . " entities");
  return \@r;
}

#
# Update an entity
#
# @return 1 (if ok), or 0 (if errors)
#
sub update {
  my $entity = shift;

  # Pre-conditions
  if (! defined ($entity)) {
    Carp::croak("OvomDao.update needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croak("OvomDao.update: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODatacenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croak("OvomDao.update needs an entity");
    return 0;
  }

  if( ! defined($entity->{mo_ref}) || $entity->{mo_ref} eq '' ) {
    Carp::croak("Trying to update a $oClassName without mo_ref");
    return 0;
  }
  if( ! defined($entity->{name}) || $entity->{name} eq '' ) {
    Carp::croak("Trying to update a $oClassName without name");
    return 0;
  }
  if( ! defined($entity->{parent}) || $entity->{parent} eq '' ) {
    Carp::croak("Trying to update a $oClassName without parent");
    return 0;
  }

  my $stmt;
  if($oClassName eq 'OFolder') {
    $stmt = $sqlFolderUpdate;
  }
  elsif($oClassName eq 'ODatacenter') {
    $stmt = $sqlDatacenterUpdate;
  }
  elsif($oClassName eq 'OCluster') {
    $stmt = $sqlClusterUpdate;
  }
  elsif($oClassName eq 'OHost') {
    $stmt = $sqlHostUpdate;
  }
  elsif($oClassName eq 'OVirtualMachine') {
    $stmt = $sqlVirtualMachineUpdate;
  }
  else {
    Carp::croak("Statement unimplemented for $oClassName in OvomDao.update");
    return 0;
  }

  OInventory::log(1, "Updating into db the $oClassName: "
                        . $entity->toCsvRow());

  my $sthRes;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder   = OvomDao::loadEntityByMoRef($entity->{parent}, 'OFolder');
    if(! defined($parentFolder)) {
      Carp::croak("Can't load the parent of a $oClassName."
                 . " Child's  mo_ref = " . $entity->{mo_ref}
                 . " parent's id     = " . $entity->{parent});
      return 0;
    }
    my $loadedParentId = $parentFolder->{id};
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement for updating a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    if($oClassName eq 'OFolder' || $oClassName eq 'OHost' || $oClassName eq 'OCluster' || $oClassName eq 'OVirtualMachine') {
      $sthRes = $sth->execute($entity->{name}, $loadedParentId,
                              $entity->{mo_ref});
    }
    elsif($oClassName eq 'ODatacenter') {
      #
      # First have to extract the folder id
      # for datastoreFolder, vmFolder, hostFolder and networkFolder
      #
      my $e;
      my ($datastoreFolderPid, $vmFolderPid, $hostFolderPid, $networkFolderPid);
      $e   = OvomDao::loadEntityByMoRef($entity->{datastoreFolder}, 'OFolder');
      die "Can't load the datastoreFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $datastoreFolderPid = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{vmFolder},        'OFolder');
      die "Can't load the vmFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $vmFolderPid        = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{hostFolder},      'OFolder');
      die "Can't load the hostFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $hostFolderPid      = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{networkFolder},   'OFolder');
      die "Can't load the networkFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $networkFolderPid   = $e->{id};

      #
      # Now we can update
      #
      $sthRes = $sth->execute($entity->{name}, $loadedParentId,
                              $datastoreFolderPid, $vmFolderPid,
                              $hostFolderPid, $networkFolderPid,
                              $entity->{mo_ref});
    }
    else {
      Carp::croak("Statement execution stil unimplemented in OvomDao.update");
      return 0;
    }

    if(! $sthRes) {
      Carp::croak("Can't execute the statement for updating a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't updated any $oClassName, "
                . "trying to update the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors updating a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: updating " . $sthRes . " $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

#
# Delete an entity from DB
#
# @return 1 (if ok), or 0 (if errors)
#
sub delete {
  my $entity = shift;

  # Pre-conditions
  if (! defined ($entity)) {
    Carp::croak("OvomDao.delete needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croak("OvomDao.delete: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODatacenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croak("OvomDao.delete needs an entity");
    return 0;
  }

  my $stmt;
  if($oClassName eq 'OFolder') {
    $stmt = $sqlFolderDelete;
  }
  elsif($oClassName eq 'ODatacenter') {
    $stmt = $sqlDatacenterDelete;
  }
  elsif($oClassName eq 'OCluster') {
    $stmt = $sqlClusterDelete;
  }
  elsif($oClassName eq 'OHost') {
    $stmt = $sqlHostDelete;
  }
  elsif($oClassName eq 'OVirtualMachine') {
    $stmt = $sqlVirtualMachineDelete;
  }
  else {
    Carp::croak("Statement stil unimplemented in OvomDao.delete");
    return 0;
  }

  if(defined($entity->{name})) {
    OInventory::log(0, "Deleting from DB the $oClassName "
                          . $entity->toCsvRow());
  }
  else {
    OInventory::log(0, "Deleting from DB the $oClassName with mo_ref = '"
                          . $entity->{mo_ref} . "'");
  }
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement for deleting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    $sthRes = $sth->execute($entity->{mo_ref});

    if(! $sthRes) {
      Carp::croak("Can't execute the statement for deleting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't deleted any $oClassName, "
                . "trying to delete the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors deleting a $oClassName from DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: deleting a $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

#
# Get an Entity from DB by mo_ref.
#
# @arg mo_ref
# @arg entity type (OFolder | ODatacenter | OCluster | OHost | OVirtualMachine)
# @return undef (if errors), or a reference to an Entity object (if ok)
#
sub loadEntityByMoRef {
  my $moRef      = shift;
  my $entityType = shift;
  my $stmt;
  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  if (! defined ($moRef)) {
    Carp::croak("Got an undefined mo_ref trying to load a $entityType");
    return undef;
  }
  if ($moRef eq '') {
    Carp::croak("Got an empty mo_ref trying to load a $entityType");
    return undef;
  }
  if (! defined ($entityType)) {
    Carp::croak("Got an undefined entity type trying to load an entity");
    return undef;
  }
  if ($entityType eq '') {
    Carp::croak("Got an empty entity type trying to load an entity");
    return undef;
  }

  if ($entityType eq 'OFolder') {
    $stmt = $sqlFolderSelectByMoref;
  }
  elsif($entityType eq 'ODatacenter') {
    $stmt = $sqlDatacenterSelectByMoref;
  }
  elsif($entityType eq 'OCluster') {
    $stmt = $sqlClusterSelectByMoref;
  }
  elsif($entityType eq 'OHost') {
    $stmt = $sqlHostSelectByMoref;
  }
  elsif($entityType eq 'OVirtualMachine') {
    $stmt = $sqlVirtualMachineSelectByMoref;
  }
  else {
    Carp::croak("Not implemented in OvomDao.loadEntityByMoRef");
    return undef;
  }

  OInventory::log(0, "selecting from db a ${entityType} with mo_ref = " . $moRef);

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement for all ${entityType}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    my $sthRes = $sth->execute($moRef);

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to get the ${entityType} "
                . "with mo_ref = " . $moRef);
      $sth->finish();
      return undef;
    }

    my $found = 0;
    while (@data = $sth->fetchrow_array()) {
      if ($found++ > 0) {
        Carp::croak("Found more than one ${entityType} "
                   . "when looking for the one with mo_ref = $moRef");
        $sth->finish();
        return undef;
      }

      if ($entityType eq 'OFolder') {
        $r = OFolder->new(\@data);
      }
      elsif($entityType eq 'ODatacenter') {
        $r = ODatacenter->new(\@data);
      }
      elsif($entityType eq 'OCluster') {
        $r = OCluster->new(\@data);
      }
      elsif($entityType eq 'OHost') {
        $r = OHost->new(\@data);
      }
      elsif($entityType eq 'OVirtualMachine') {
        $r = OVirtualMachine->new(\@data);
      }
      else {
        Carp::croak("Not implemented for $entityType "
                  . "in OvomDao.loadEntityByMoRef");
        return undef;
      }
    }
  };

  if($@) {
    OInventory::log(3, "Errors getting a ${entityType} from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: select a ${entityType} took "
                        . sprintf("%.3f", $eTime) . " s");
  return $r;
}

#
# Insert an object into DB
#
# @return 1 (if ok), or 0 (if errors)
#
sub insert {
  my $entity = shift;

  # Pre-conditions
  if (! defined ($entity)) {
    Carp::croak("OvomDao.insert needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croak("OvomDao.insert: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODatacenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croak("OvomDao.insert needs an entity");
    return 0;
  }

  if( ! defined($entity->{mo_ref}) || $entity->{mo_ref} eq '' ) {
    Carp::croak("Trying to insert a $oClassName without mo_ref");
    return 0;
  }
  if( ! defined($entity->{name}) || $entity->{name} eq '' ) {
    Carp::croak("Trying to insert a $oClassName without name");
    return 0;
  }
  if( ! defined($entity->{parent}) || $entity->{parent} eq '' ) {
    Carp::croak("Trying to insert a $oClassName without parent");
    return 0;
  }

  my $stmt;
  if($oClassName    eq 'OFolder') {
    $stmt = $sqlFolderInsert;
  }
  elsif($oClassName eq 'ODatacenter') {
    $stmt = $sqlDatacenterInsert;
  }
  elsif($oClassName eq 'OHost') {
    $stmt = $sqlHostInsert;
  }
  elsif($oClassName eq 'OCluster') {
    $stmt = $sqlClusterInsert;
  }
  elsif($oClassName eq 'OVirtualMachine') {
    $stmt = $sqlVirtualMachineInsert;
  }
  else {
    Carp::croak("Statement unimplemented for $oClassName in OvomDao.insert");
    return 0;
  }

  OInventory::log(1, "Inserting into db the $oClassName: "
                        . $entity->toCsvRow());

  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder = OvomDao::loadEntityByMoRef($entity->{parent}, 'OFolder');
    if( ! defined($parentFolder) ) {
      Carp::croak("Can't find the parent for the $oClassName "
                . "with mo_ref " . $entity->{mo_ref});
      return 0;
    }
    my $loadedParentId = $parentFolder->{id};
    if( ! defined($loadedParentId) ) {
      Carp::croak("Can't get the id of the parent for the $oClassName "
                . "with mo_ref " . $entity->{mo_ref});
      return 0;
    }
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement for inserting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    if($oClassName eq 'OFolder' || $oClassName eq 'OHost' || $oClassName eq 'OCluster' || $oClassName eq 'OVirtualMachine') {
      $sthRes = $sth->execute($entity->{name}, $entity->{mo_ref}, $loadedParentId);
    }
    elsif($oClassName eq 'ODatacenter') {
      #
      # First have to extract the folder id
      # for datastoreFolder, vmFolder, hostFolder and networkFolder
      #
      my $e;
      my ($datastoreFolderPid, $vmFolderPid, $hostFolderPid, $networkFolderPid);

      if( ! defined($entity->{datastoreFolder}) || $entity->{datastoreFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert a $oClassName without datastoreFolder");
        return 0;
      }
      if( ! defined($entity->{vmFolder}) || $entity->{vmFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert a $oClassName without vmFolder");
        return 0;
      }
      if( ! defined($entity->{hostFolder}) || $entity->{hostFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert a $oClassName without hostFolder");
        return 0;
      }
      if( ! defined($entity->{networkFolder}) || $entity->{networkFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert a $oClassName without networkFolder");
        return 0;
      }

      # Let's go:
      $e   = OvomDao::loadEntityByMoRef($entity->{datastoreFolder}, 'OFolder');
      die "Can't load the datastoreFolder with id " . $entity->{datastoreFolder}
        . " when inserting $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $datastoreFolderPid = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{vmFolder},        'OFolder');
      die "Can't load the vmFolder with id " . $entity->{datastoreFolder}
        . " when inserting $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $vmFolderPid        = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{hostFolder},      'OFolder');
      die "Can't load the hostFolder with id " . $entity->{datastoreFolder}
        . " when inserting $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $hostFolderPid      = $e->{id};
      $e   = OvomDao::loadEntityByMoRef($entity->{networkFolder},   'OFolder');
      die "Can't load the networkFolder with id " . $entity->{datastoreFolder}
        . " when inserting $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $networkFolderPid   = $e->{id};

#print "DEBUG: insert: dataCenter has datastoreFolderPid=$datastoreFolderPid vmFolderPid=$vmFolderPid hostFolderPid=$hostFolderPid networkFolderPid=$networkFolderPid\n";

      #
      # Now we can update
      #
      $sthRes = $sth->execute($entity->{name}, $entity->{mo_ref},
                              $loadedParentId,
                              $datastoreFolderPid, $vmFolderPid,
                              $hostFolderPid, $networkFolderPid);
    }
    else {
      Carp::croak("Statement unimplemented for $oClassName in OvomDao.insert");
      return 0;
    }

    if(! $sthRes) {
      Carp::croak("Can't execute the statement for inserting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't inserted any $oClassName, "
                . "trying to insert the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors inserting a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: insert a $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

1;

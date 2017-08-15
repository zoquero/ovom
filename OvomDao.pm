package OvomDao;
use strict;
use warnings;
use DBI;
use Time::HiRes; ## gettimeofday
use Carp;


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
  OvomExtractor::log(0, "Testing if the db handle "
                      . "is already active before connecting to DB");
  eval {
    if($dbh && $dbh->{Active}) {
      $c = 1;
    }
  };
  if($@) {
    OvomExtractor::log(3, "Errors checking if handle active "
                        . "before connecting to database: $@");
    return 0;
  }
  if($c == 1) {
    OvomExtractor::log(3, "BUG! Handle already active before connecting to DB");
    return 0;
  }

  my $connStr  = "dbi:mysql:dbname=" . $OvomExtractor::configuration{'db.name'}
               . ";host=" . $OvomExtractor::configuration{'db.hostname'};
  my $username = $OvomExtractor::configuration{'db.username'};
  my $passwd   = $OvomExtractor::configuration{'db.password'};
  OvomExtractor::log(0, "Connecting to database with connection string: '$connStr'");

  eval {
    $dbh = DBI->connect($connStr, $username, $passwd,
                        { AutoCommit => 0,
                          RaiseError=>1,
                          PrintError=>0,
                          ShowErrorStatement=>1
                        });
  };

  if($@) {
    OvomExtractor::log(3, "Errors connecting to Database: $@");
    return 0
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: Connecting to DB "
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
  OvomExtractor::log(0, "Disconnecting from database");

  eval {
    $dbh->disconnect();
  };

  if($@) {
    OvomExtractor::log(3, "Errors disconnecting from Database: $@");
    return 0;
  }

  OvomExtractor::log(1, "Successfully disconnected from database");
  return 1;
}

#
# Check if connected
#
# @return: 1 (connected), 0 (not connected), -1 (errors);
#
sub connected {
  my $r = -1;
  OvomExtractor::log(0, "Checking if connected to database");

  eval {
    if($dbh && $dbh->{Active}) {
      $r = 1;
    }
    else {
      $r = 0;
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors checking if connected to database: $@");
    return -1;
  }

  OvomExtractor::log(1, "Successfully checked if connected to database ($r)");
  return $r;
}


#
# @deprecated We always use AutoCommit off
#
sub transactionBegin {
  OvomExtractor::log(0, "Begining DB transaction");

  eval {
    $dbh->begin_work();
  };

  if($@) {
    OvomExtractor::log(3, "Errors begining DB transaction: $@");
    return 1;
  }

  OvomExtractor::log(1, "Successfully begined DB transaction");
  return 0;
}


sub transactionCommit {
  OvomExtractor::log(0, "Commiting DB transaction");

  eval {
    $dbh->commit();
  };

  if($@) {
    OvomExtractor::log(3, "Errors commiting DB transaction: $@");
    return 1;
  }

  OvomExtractor::log(1, "Successfully commited DB transaction");
  return 0;
}


sub transactionRollback {
  OvomExtractor::log(0, "Rolling back DB transaction");

  eval {
    $dbh->commit();
  };

  if($@) {
    OvomExtractor::log(3, "Errors rolling back DB transaction: $@");
    return 1;
  }

  OvomExtractor::log(1, "Successfully rolled back DB transaction");
  return 0;
}

sub select {
die "deprecated method, must be deleted";
  OvomExtractor::log(0, "Selecting from DB");

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
    OvomExtractor::log(3, "Errors getting from DB: $@");
    return 1;
  }

  OvomExtractor::log(1, "Successfully selected from DB");
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
  my @r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $stmt;
  OvomExtractor::log(0, "Getting all entities of type $entityType");

  if($entityType eq 'OFolder') {
    $stmt = $sqlFolderSelectAll;
  }
  elsif($entityType eq 'ODatacenter') {
    $stmt = $sqlDatacenterSelectAll;
  }
  elsif($entityType eq 'OCluster') {
    $stmt = $sqlClusterSelectAll;
  }
  elsif($entityType eq 'OHost') {
    $stmt = $sqlHostSelectAll;
  }
  elsif($entityType eq 'OVirtualMachine') {
    $stmt = $sqlVirtualMachineSelectAll;
  }
  else {
    Carp::croak("Not implemented in OvomDao.getAllEntitiesOfType");
    return undef;
  }

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement for all ${entityType}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sth->execute();
    while (@data = $sth->fetchrow_array()) {
      my $e;
      if($entityType eq 'OFolder') {
        $e = OFolder->new(\@data);
        push @r, \$e;
      }
      elsif($entityType eq 'ODatacenter') {
        $e = ODatacenter->new(\@data);
        push @r, \$e;
      }
      elsif($entityType eq 'OCluster') {
        $e = OCluster->new(\@data);
        push @r, \$e;
      }
      elsif($entityType eq 'OHost') {
        $e = OHost->new(\@data);
        push @r, \$e;
      }
      elsif($entityType eq 'OVirtualMachine') {
        $e = OVirtualMachine->new(\@data);
        push @r, \$e;
      }
      else {
        Carp::croak("Not implemented for $entityType "
                  . "in OvomDao.getAllEntitiesOfType");
        return undef;
      }
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors getting all ${entityType}s from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: select all ${entityType}s took "
                        . sprintf("%.3f", $eTime) . " s");
  return \@r;
}

#
# Insert, update or delete objects on database as needed.
#
# Inserts the new objects,
# updates the existing with changes,
# noops on the unchanged existing
# and deletes the ones that aren't available.
#
# @arg ref to array of references to objects found on vCenter (source)
# @arg ref to array of references to objects read on database (destination)
# @return 1 if something changed, 0 if nothing changed, -1 if errors.
#
sub updateAsNeeded {
  my ($discovered, $loadedFromDb) = @_;
  my @toUpdate;
  my @toInsert;
  my @toDelete;
  my @loadedPositionsNotTobeDeleted;

  OvomExtractor::log(0, "Running updateAsNeeded");

  if( !defined($discovered) || !defined($loadedFromDb)) {
    Carp::croak("updateAsNeeded needs a reference to 2 entitiy arrays as argument");
    return -1;
  }

  if( $#$discovered == -1 && $#$loadedFromDb == -1 ) {
    OvomExtractor::log(2, "updateAsNeeded: NOP: "
                        . "Got 0 entities discovered (mem inventory) "
                        . "and 0 entities in inventory DB. "
                        . "Is there anybody out there?");
    return 0;
  }

  foreach my $aDiscovered (@$discovered) {
    my $found = 0;
    my $j = -1;
    foreach my $aLoadedFromDb (@$loadedFromDb) {
      $j++;
      my $r;
      $r = $$aDiscovered->compare($aLoadedFromDb);
#print "DEBUG: (j=$j) r=$r \tcomparing " . $$aDiscovered->toCsvRow() . " with " . $$aLoadedFromDb->toCsvRow() . "\n";
      if ($r == -2) {
        # Errors
        return -1;
      }
      elsif ($r == 1) {
#print "DEBUG: It's equal. It hasn't to change in DB. Pushed position $j NOT to be deleted\n";
        # Equal
        push @loadedPositionsNotTobeDeleted, $j;
        $found = 1;
        last;
      }
      elsif ($r == 0) {
        # Changed (same mo_ref but some other attribute differs)
#print "DEBUG: It has to be UPDATED into DB. Pushed position $j NOT to be deleted\n";
        push @toUpdate, $$aDiscovered;
        push @loadedPositionsNotTobeDeleted, $j;
        $found = 1;
        last;
      }
      else {
        # $r == -1  =>  differ
      }
    }

    if (! $found) {
#print "DEBUG: It has to be INSERTED into DB.\n";
      push @toInsert, $$aDiscovered;
    }
  }
  for (my $i = 0; $i <= $#$loadedFromDb; $i++) {
    if ( ! grep /^$i$/, @loadedPositionsNotTobeDeleted ) {
      push @toDelete, $$loadedFromDb[$i];
    }
  }

  my $str = ($#$discovered + 1)   . " entities discovered (mem inventory), "
          . ($#$loadedFromDb + 1) . " entities in inventory DB, "
          . ($#toInsert + 1)      . " entities toInsert, "
          . ($#toUpdate + 1)      . " entities toUpdate, "
          . ($#toDelete + 1)      . " entities toDelete";

  OvomExtractor::log(0, "updateAsNeeded: $str");

  # Let's work:
  OvomExtractor::log(0, "updateAsNeeded: Inserting") if $#toInsert >= 0;
  if(${$$discovered[0]}->{oclass_name} eq 'OFolder') {
    # Let's keep parental integrity
    while (my $aEntity = popNextFolderWithParent(\@toInsert)) {
      insert($aEntity);
    }
  }
  else {
    foreach my $aEntity (@toInsert) {
      OvomDao::insert($aEntity);
    }
  }

  OvomExtractor::log(0, "updateAsNeeded: Updating") if $#toUpdate >= 0;
  foreach my $aEntity (@toUpdate) {
    OvomDao::update($aEntity);
  }

  OvomExtractor::log(0, "updateAsNeeded: Deleting") if $#toDelete >= 0;
  foreach my $aEntity (@toDelete) {
    OvomDao::delete($aEntity);
  }

  return 1 if($#toInsert == -1 && $#toUpdate == -1 && $#toDelete == -1);
  return 0;
}

sub popNextFolderWithParent {
  my $entities = shift;
  for(my $i = 0; $i <= $#$entities; $i++) {
    my $aParent = OvomDao::loadEntityByMoRef($$entities[$i]->{parent}, 'OFolder');
    if (defined $aParent) {
      my $r = $$entities[$i];
      splice @$entities, $i, 1;
      return $r;
    }
  }
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

#print "DEBUG: Dao.update: updating a $oClassName : " . $entity->toCsvRow() . "\n";
  OvomExtractor::log(0, "Updating into db a $oClassName with mo_ref "
                        . $entity->{mo_ref});

  my $sthRes;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder   = OvomDao::loadEntityByMoRef($entity->{parent}, 'OFolder');
    if(! defined($parentFolder)) {
      Carp::croak("Can't load the parent of a $oClassName."
                 . " Child's  mo_ref = " . $entity->{mo_ref}
                 . " parent's mo_ref = " . $entity->{parent});
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
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't updated any $oClassName, "
                . "trying to update the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors updating a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: updating " . $sthRes . " $oClassName took "
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

  OvomExtractor::log(0, "deleting from db a $oClassName with mo_ref " . $entity->{mo_ref});
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
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't deleted any $oClassName, "
                . "trying to delete the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors deleting a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: deleting a $oClassName took "
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
    Carp::croak("Got an undefined mo_ref");
    return undef;
  }
  if (! defined ($entityType)) {
    Carp::croak("Got an undefined entity type");
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

  OvomExtractor::log(0, "selecting from db a ${entityType} with mo_ref = " . $moRef);

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement for all ${entityType}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sth->execute($moRef);
    my $found = 0;
    while (@data = $sth->fetchrow_array()) {
      if ($found++ > 0) {
        Carp::croak("Found more than one ${entityType} "
                   . "when looking for the one with mo_ref = $moRef");
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
    OvomExtractor::log(3, "Errors getting a ${entityType} from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: select a ${entityType} took "
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

  OvomExtractor::log(0, "inserting into db a $oClassName with mo_ref " . $entity->{mo_ref});
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder   = OvomDao::loadEntityByMoRef($entity->{parent}, 'OFolder');
    my $loadedParentId = $parentFolder->{id};
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
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't inserted any $oClassName, "
                . "trying to insert the one with mo_ref " . $entity->{mo_ref});
      return 0;
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors inserting a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: insert a $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

1;

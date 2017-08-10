package OvomDao;
use strict;
use warnings;
use DBI;
use Time::HiRes; ## gettimeofday
use Carp;


our $dbh;
our $sqlFolderSelectAll     = 'SELECT a.id, a.name, a.moref, b.moref '
                              . 'FROM folder as a '
                              . 'inner join folder as b where a.parent = b.id';
our $sqlFolderSelectByMoref = 'SELECT a.id, a.name, a.moref, b.moref '
                              . 'FROM folder as a '
                              . 'inner join folder as b '
                              . 'where a.parent = b.id and a.moref = ?';
our $sqlFolderInsert = 'INSERT INTO folder (name, moref, parent) '
                          . 'VALUES (?, ?, ?)';
                                                # moref is immutable
our $sqlFolderUpdate = 'UPDATE folder set name = ?, parent = ? where moref = ?';
our $sqlFolderDelete = 'DELETE FROM folder where moref = ?';

#
# Connect to DataBAse
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
    return -1;
  }
  if($c == 1) {
    OvomExtractor::log(3, "BUG! Handle already active before connecting to DB");
    return -1;
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
    return 1;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: Connecting to DB "
                        . "with connection string: '$connStr' took "
                        . sprintf("%.3f", $eTime) . " s");
  return 0;
}

sub disconnect {
  OvomExtractor::log(0, "Disconnecting from database");

  eval {
    $dbh->disconnect();
  };

  if($@) {
    OvomExtractor::log(3, "Errors disconnecting from Database: $@");
    return 1;
  }

  OvomExtractor::log(1, "Successfully disconnected from database");
  return 0;
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
# @return undef (if errors), or a reference to array of OFolder objects (if ok)
#
sub getAllFolders {
  my @r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $sth = $dbh->prepare_cached($sqlFolderSelectAll)
                or die "Can't prepare statement for all Folders: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sth->execute();
    while (@data = $sth->fetchrow_array()) {
      push @r, OFolder->newWithId(\@data);
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors getting all Folders from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: select all Folders took "
                        . sprintf("%.3f", $eTime) . " s");
  return \@r;
}

#
# Update objects on database if needed.
#
# Inserts the new objects,
# updates the existing with changes,
# noops on the unchanged existing
# and deletes the ones that aren't available.
#
# @arg ref to array of references to objects found on vCenter
# @arg ref to array of objects read on database
# @return 1 if something changed, 0 if nothing changed, -1 if errors.
#
sub updateAsNeeded {
  my ($discovered, $loadedFromDb) = @_;
  my @toUpdate;
  my @toInsert;
  my @toDelete;
  my @loadedPositionsNotTobeDeleted;

  if( !defined($discovered) || !defined($loadedFromDb)) {
    Carp::croack("updateAsNeeded needs a reference to 2 entitiy arrays as argument");
    return -1;
  }

  if( $#$discovered == -1 || $#$loadedFromDb == -1 ) {
    OvomExtractor::log(2, "updateAsNeeded: Got 0 discovered and 0 loadedFromDb entities");
    return 0;
  }

  foreach my $aDiscovered (@$discovered) {
    my $j = -1;
    foreach my $aLoadedFromDb (@$loadedFromDb) {

my $oClassName = $aLoadedFromDb->{oclass_name};
if($oClassName ne 'OFolder') {
  die "By now just implmented for OFolder";
}

      $j++;
      my $r;
      $r = $$aDiscovered->compare($aLoadedFromDb);
#print "DEBUG: (j=$j) r=$r \tcomparing " . $$aDiscovered->toCsvRow() . " with " . $aLoadedFromDb->toCsvRow() . "\n";
      if ($r == -2) {
        # Errors
        return -1;
      }
      elsif ($r == 1) {
#print "DEBUG: It's equal. It hasn't to change in DB. Pushed position $j NOT to be deleted\n";
        # Equal
        push @loadedPositionsNotTobeDeleted, $j;
        last;
      }
      elsif ($r == 0) {
        # Changed (same mo_ref but some other attribute differs)
#print "DEBUG: It has to be UPDATED into DB. Pushed position $j NOT to be deleted\n";
        push @toUpdate, $$aDiscovered;
        push @loadedPositionsNotTobeDeleted, $j;
        last;
      }
      else {
        # $r == -1  =>  differ
        if ($j == $#$loadedFromDb) {
#print "DEBUG: It has to be INSERTED into DB.\n";
          push @toInsert, $$aDiscovered;
        }
      }
    }
  }
  for (my $i = 0; $i <= $#$loadedFromDb; $i++) {
    if ( ! grep /^$i$/, @loadedPositionsNotTobeDeleted ) {
      push @toDelete, $$loadedFromDb[$i];
    }
  }

  my $str = ($#$discovered + 1)   . " entities discovered, "
          . ($#$loadedFromDb + 1) . " entities loadedFromDb, "
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
    my $aParent = OvomDao::loadFolderByMoRef($$entities[$i]->{parent});
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
    Carp::croack("OvomDao.update needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croack("OvomDao.update: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODataCenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croack("OvomDao.update needs an entity");
    return 0;
  }


  my $stmt;
  if($oClassName eq 'OFolder') {
    $stmt = $sqlFolderUpdate;
  }
  else {
    Carp::croack("Statement stil unimplemente in OvomDao.update");
    return 0;
  }

#print "DEBUG: Dao.update: updating a $oClassName : " . $entity->toCsvRow() . "\n";
  OvomExtractor::log(0, "Updating into db a $oClassName with mo_ref " . $entity->{mo_ref});

  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder   = OvomDao::loadFolderByMoRef($entity->{parent});
    if(! defined($parentFolder)) {
      Carp::croack("Can't load the parent of a $oClassName."
                 . " Child's  mo_ref = " . $entity->{mo_ref}
                 . " parent's mo_ref = " . $entity->{parent});
      return 0;
    }
#print "DEBUG: Dao.update: after loading parent, parent = " . $parentFolder->toCsvRow() . "\n";
    my $loadedParentId = $parentFolder->{id};
#print "DEBUG: Dao.update: loadedParentId = $loadedParentId \n";
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croack("Can't prepare statement for updating a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    if($oClassName eq 'OFolder') {
      $sthRes = $sth->execute($entity->{name}, $loadedParentId, $entity->{mo_ref});
    }
    else {
      Carp::croack("Statement execution stil unimplemented in OvomDao.update");
      return 0;
    }

    if(! $sthRes) {
      Carp::croack("Can't execute the statement for updating a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors updating a $oClassName into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: updating a $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return $r;
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
    Carp::croack("OvomDao.delete needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croack("OvomDao.delete: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODataCenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croack("OvomDao.delete needs an entity");
    return 0;
  }

  my $stmt;
  if($oClassName eq 'OFolder') {
    $stmt = $sqlFolderDelete;
  }
  else {
    Carp::croack("Statement stil unimplemented in OvomDao.delete");
    return 0;
  }

  OvomExtractor::log(0, "deleting from db a $oClassName with mo_ref " . $entity->{mo_ref});
  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croack("Can't prepare statement for deleting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    if($oClassName eq 'OFolder') {
      $sthRes = $sth->execute($entity->{mo_ref});
    }
    else {
      Carp::croack("Statement execution stil unimplemented in OvomDao.delete");
      return 0;
    }

    if(! $sthRes) {
      Carp::croack("Can't execute the statement for deleting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
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
  return $r;
}


#
# Get a Folder from DB by mo_ref.
#
# @return undef (if errors), or a reference to OFolder object (if ok)
#
sub loadFolderByMoRef {
  my $folderMoRef = shift;
  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  if (! defined ($folderMoRef)) {
    Carp::croack("Got an undefined mo_ref");
    return undef;
  }

  my $entityName = "OFolder";
  OvomExtractor::log(0, "selecting from db a ${entityName} with mo_ref = " . $folderMoRef);

  eval {
    my $sth = $dbh->prepare_cached($sqlFolderSelectByMoref)
                or die "Can't prepare statement for all ${entityName}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sth->execute($folderMoRef);
    my $found = 0;
    while (@data = $sth->fetchrow_array()) {
      if ($found++ > 0) {
        Carp::croack("Found more than one ${entityName} "
                   . "when looking for the one with mo_ref $folderMoRef");
        return undef;
      }
      $r = OFolder->newWithId(\@data);
    }
  };

  if($@) {
    OvomExtractor::log(3, "Errors getting a ${entityName} from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OvomExtractor::log(1, "Profiling: select a ${entityName} took "
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
    Carp::croack("OvomDao.insert needs an entity");
    return 0;
  }
  if (! defined ($entity->{oclass_name})) {
    Carp::croack("OvomDao.insert: the parameter doesn't look like an entity");
    return 0;
  }
  my $oClassName = $entity->{oclass_name};
  if($oClassName ne 'OCluster'
  && $oClassName ne 'ODataCenter'
  && $oClassName ne 'OFolder'
  && $oClassName ne 'OHost'
  && $oClassName ne 'OVirtualMachine') {
    Carp::croack("OvomDao.insert needs an entity");
    return 0;
  }

  my $stmt;
  if($oClassName eq 'OFolder') {
    $stmt = $sqlFolderInsert;
  }
  else {
    Carp::croack("Statement stil unimplemente in OvomDao.insert");
    return 0;
  }

  OvomExtractor::log(0, "insert into db a $oClassName with name " . $entity->{name});
  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $parentFolder   = OvomDao::loadFolderByMoRef($entity->{parent});
    my $loadedParentId = $parentFolder->{id};
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croack("Can't prepare statement for inserting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    if($oClassName eq 'OFolder') {
      $sthRes = $sth->execute($entity->{name}, $entity->{mo_ref}, $loadedParentId);
    }
    else {
      Carp::croack("Statement execution stil unimplemente in OvomDao.insert");
      return 0;
    }


    if(! $sthRes) {
      Carp::croack("Can't execute the statement for inserting a $oClassName: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
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
  return $r;
}

1;

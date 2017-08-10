package OvomDao;
use strict;
use warnings;
use DBI;
use Time::HiRes; ## gettimeofday
use Carp;


our $dbh;
our $sqlFolderSelectAll = 'SELECT a.name, a.moref, b.moref, a.enabled '
                          . 'FROM folder as a '
                          . 'inner join folder as b where a.parent = b.id';

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

    $sth->finish;
  };

  if($@) {
    OvomExtractor::log(3, "Errors selecting from DB: $@");
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
    $dbh->commit();
    my $sth = $dbh->prepare($sqlFolderSelectAll)
                or die "Can't prepare statement for all Folders: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    $sth->execute();
    while (@data = $sth->fetchrow_array()) {
      push @r, OFolder->new(\@data);
    }
    $sth->finish;
  };

  if($@) {
    OvomExtractor::log(3, "Errors selecting all Folders from DB: $@");
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
# @arg ref to array of objects found on vCenter
# @arg ref to array of objects read on database
# @return 1 if something changed, 0 if nothing changed, -1 if errors.
#
sub updateAsNeeded {
  my ($discovered, $loadedFromDb) = @_;
  my @toUpdate;
  my @toInsert;
  my @toDelete;
  my @loadedPositionsNotTobeDeleted;
## splice @toDelete, $j, 1;
  if( !defined($discovered) || !defined($loadedFromDb)) {
    Carp::croack("updateAsNeeded needs a reference to 2 entities as argument");
    return -1;
  }

  print "INITIALLY:\n";
  print "DEBUG: discovered   = " . $#$discovered . "\n";
  print "DEBUG: loadedFromDb = " . $#$loadedFromDb . "\n";
  print "DEBUG: to insert    = " . $#toInsert . "\n";
  print "DEBUG: to update    = " . $#toUpdate . "\n";

  foreach my $aDiscovered (@$discovered) {
    my $j = -1;
    foreach my $aLoadedFromDb (@$loadedFromDb) {
      $j++;
      my $r = $aDiscovered->compare($aLoadedFromDb);
      print "DEBUG: (j=$j) r=$r \tcomparing " . $aDiscovered->toCsvRow() . " with " . $aLoadedFromDb->toCsvRow() . "\n";
      if ($r == -2) {
        # Errors
        return -1;
      }
      elsif ($r == 1) {
        # Equal
        push @loadedPositionsNotTobeDeleted, $j;
        last;
      }
      elsif ($r == 0) {
        # Changed (same mo_ref but some other attribute differs)
        push @toUpdate, $aDiscovered;
        push @loadedPositionsNotTobeDeleted, $j;
        last;
      }
      else {
        # $r == -1  =>  differ
        if ($j == $#$loadedFromDb) {
print "DEBUG: Differs and $j looks like last component. Has to be inserted into DB.\n";
          push @toInsert, $aDiscovered;
          push @loadedPositionsNotTobeDeleted, $j;
        }
      }
    }
  }
  for (my $i = 0; $i <= $#$loadedFromDb; $i++) {
    if ( grep /^$i$/, @loadedPositionsNotTobeDeleted ) {
      push @toDelete, $$loadedFromDb[$i];
    }
  }

  print "DEBUG: discovered   = " . $#$discovered . "\n";
  print "DEBUG: loadedFromDb = " . $#$loadedFromDb . "\n";
  print "DEBUG: to insert    = " . $#toInsert . "\n";
  print "DEBUG: to update    = " . $#toUpdate . "\n";
  print "DEBUG: to delete    = " . $#toDelete . "\n";

  return 1 if($#toInsert == -1 && $#toUpdate == -1 && $#toDelete == -1);
  return 0;
}

1;

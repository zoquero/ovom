package OvomDao;
use strict;
use warnings;
use DBI;

our $dbh;

#
# Connect to DataBAse
#
#
#
sub connect {
  my $driver   = "mysql";
  my $connStr  = "dbi:$driver:dbname=" . $OvomExtractor::configuration{'db.name'} . ";host=" . $OvomExtractor::configuration{'db.hostname'};
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

  OvomExtractor::log(1, "Successfully connected to database "
                      . "with connection string: '$connStr'");
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
  OvomExtractor::log(0, "Checking if connecte to database");

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


1;

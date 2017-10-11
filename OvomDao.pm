package OvomDao;
use strict;
use warnings;
use DBI;
use Time::HiRes; ## gettimeofday
use Carp;
use OInventory;
use Data::Dumper;


our $dbh;

###########################
# SQL Statements for Folder
###########################
our $sqlFolderSelectAll       = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                              . 'FROM folder as a '
                              . 'inner join folder as b where a.parent = b.id';
our $sqlFolderSelectAllChild  = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                              . 'FROM folder as a '
                              . 'inner join folder as b where a.parent = b.id '
                              . 'and b.mo_ref = ?';
our $sqlFolderSelectByMoref   = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                              . 'FROM folder as a '
                              . 'inner join folder as b '
                              . 'where a.parent = b.id and a.mo_ref = ?';
our $sqlFolderInsert          = 'INSERT INTO folder (name, mo_ref, parent) '
                              . 'VALUES (?, ?, ?)';
                                                # mo_ref is immutable
our $sqlFolderUpdate = 'UPDATE folder set name = ?, parent = ? where mo_ref = ?';
our $sqlFolderDelete = 'DELETE FROM folder where mo_ref = ?';

###############################
# SQL Statements for Datacenter
###############################
our $sqlDatacenterSelectAll   = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref, '
                              . 'c.mo_ref, d.mo_ref, e.mo_ref, f.mo_ref '
                              . 'FROM datacenter as a  '
                              . 'inner join folder as b, folder as c, '
                              . 'folder as d, folder as e, folder as f '
                              . 'where a.parent = b.id '
                              . 'and a.datastore_folder = c.id '
                              . 'and a.vm_folder = d.id '
                              . 'and a.host_folder = e.id '
                              . 'and a.network_folder = f.id ';
our $sqlDatacenterSelectByMoref  = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref, '
                                 . 'c.mo_ref, d.mo_ref, e.mo_ref, f.mo_ref '
                                 . 'FROM datacenter as a  '
                                 . 'inner join folder as b, folder as c, '
                                 . 'folder as d, folder as e, folder as f '
                                 . 'where a.parent = b.id and a.mo_ref = ?'
                                 . 'and a.datastore_folder = c.id '
                                 . 'and a.vm_folder = d.id '
                                 . 'and a.host_folder = e.id '
                                 . 'and a.network_folder = f.id ';
our $sqlDatacenterInsert = 'INSERT INTO datacenter (name, mo_ref, parent, '
                         . 'datastore_folder, vm_folder, '
                         . 'host_folder, network_folder) '
                         . 'VALUES (?, ?, ?, ?, ?, ?, ?)';
                                                # mo_ref is immutable
our $sqlDatacenterUpdate = 'UPDATE datacenter '
                         . 'set name = ?, parent = ?, datastore_folder = ?, '
                         . 'vm_folder = ?, host_folder = ?, '
                         . 'network_folder = ? where mo_ref = ?';
our $sqlDatacenterDelete = 'DELETE FROM datacenter where mo_ref = ?';

#########################
# SQL Statements for Host
#########################
our $sqlHostSelectAll     = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                          . 'FROM host as a '
                          . 'inner join folder as b where a.parent = b.id';
our $sqlHostSelectByMoref = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                          . 'FROM host as a '
                          . 'inner join folder as b '
                          . 'where a.parent = b.id and a.mo_ref = ?';
our $sqlHostInsert        = 'INSERT INTO host (name, mo_ref, parent) '
                          . 'VALUES (?, ?, ?)';
                                                # mo_ref is immutable
our $sqlHostUpdate = 'UPDATE host set name = ?, parent = ? where mo_ref = ?';
our $sqlHostDelete = 'DELETE FROM host where mo_ref = ?';

############################
# SQL Statements for Cluster
############################
our $sqlClusterSelectAll     = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                             . 'FROM cluster as a '
                             . 'inner join folder as b where a.parent = b.id';
our $sqlClusterSelectByMoref = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                             . 'FROM cluster as a '
                             . 'inner join folder as b '
                             . 'where a.parent = b.id and a.mo_ref = ?';
our $sqlClusterInsert        = 'INSERT INTO cluster (name, mo_ref, parent) '
                             . 'VALUES (?, ?, ?)';
                                                # mo_ref is immutable
our $sqlClusterUpdate = 'UPDATE cluster '
                      . 'set name = ?, parent = ? where mo_ref = ?';
our $sqlClusterDelete = 'DELETE FROM cluster where mo_ref = ?';

###################################
# SQL Statements for VirtualMachine
###################################
our $sqlVirtualMachineSelectAll = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                                . 'FROM virtualmachine as a '
                                . 'inner join folder as b where a.parent = b.id';
our $sqlVirtualMachineSelectAllChild = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                                     . 'FROM virtualmachine as a '
                                     . 'inner join folder as b where a.parent = b.id '
                                     . 'and b.mo_ref = ?';
our $sqlVirtualMachineSelectByMoref = 'SELECT a.id, a.name, a.mo_ref, b.mo_ref '
                                    . 'FROM virtualmachine as a '
                                    . 'inner join folder as b '
                                    . 'where a.parent = b.id and a.mo_ref = ?';
our $sqlVirtualMachineInsert = 'INSERT INTO virtualmachine (name, mo_ref, parent) '
                             . 'VALUES (?, ?, ?)';
                                                # mo_ref is immutable
our $sqlVirtualMachineUpdate = 'UPDATE virtualmachine '
                             . 'set name = ?, parent = ? where mo_ref = ?';
our $sqlVirtualMachineDelete = 'DELETE FROM virtualmachine where mo_ref = ?';

####################################
# SQL Statements for PerfCounterInfo
####################################
our $sqlPerfCounterInfoSelectAll 
                             = 'SELECT a.stats_type, a.per_device_level, a.name_info_key, a.name_info_label, a.name_info_summary, a.group_info_key, a.group_info_label, a.group_info_summary, a.pci_key, a.pci_level, a.rollup_type, a.unit_info_key, a.unit_info_label, a.unit_info_summary '
                             . 'FROM perf_counter_info as a';
our $sqlPerfCounterInfoSelectByKey     = 'SELECT a.stats_type, a.per_device_level, a.name_info_key, a.name_info_label, a.name_info_summary, a.group_info_key, a.group_info_label, a.group_info_summary, a.pci_key, a.pci_level, a.rollup_type, a.unit_info_key, a.unit_info_label, a.unit_info_summary '
                             . 'FROM perf_counter_info as a '
                             . 'where a.pci_key = ?';
our $sqlPerfCounterInfoInsert
                             = 'INSERT INTO perf_counter_info (pci_key, name_info_key, name_info_label, name_info_summary, group_info_key, group_info_label, group_info_summary, unit_info_key, unit_info_label, unit_info_summary, rollup_type, stats_type, pci_level, per_device_level) '
                             . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
our $sqlPerfCounterInfoUpdate
                             = 'UPDATE perf_counter_info set name_info_key = ?, name_info_label = ?, name_info_summary = ?, group_info_key = ?, group_info_label = ?, group_info_summary = ?, unit_info_key = ?, unit_info_label = ?, unit_info_summary = ?, rollup_type = ?, stats_type = ?, pci_level = ?, per_device_level = ? where pci_key = ?';
our $sqlPerfCounterInfoDelete
                             = 'DELETE FROM perf_counter_info where mo_ref = ?';

####################################
# SQL Statements for PerfMetric
####################################
our $sqlPerfMetricSelectAll 
                              = 'SELECT a.mo_ref, a.counter_id, a.instance, a.last_collection '
                              . 'FROM perf_metric as a';
our $sqlPerfMetricSelectByKey = 'SELECT a.mo_ref, a.counter_id, a.instance, a.last_collection '
                              . 'FROM perf_metric as a '
                              . 'where counter_id = ? and instance = ? and mo_ref = ? ';
our $sqlPerfMetricSelectEntityPMs = 'SELECT a.mo_ref, a.counter_id, a.instance, a.last_collection '
                                  . 'FROM perf_metric as a '
                                  . 'where mo_ref = ? ';
our $sqlPerfMetricInsert
                              = 'INSERT INTO perf_metric (mo_ref, counter_id, instance) '
                              . 'VALUES (?, ?, ?)';
                             # Nop update just to update timestamp
our $sqlPerfMetricUpdate
                             = 'UPDATE perf_metric set last_collection = NOW() where counter_id = ? and instance = ? and mo_ref = ?   ';
our $sqlPerfMetricDelete
                             = 'DELETE FROM perf_metric where counter_id = ? and instance = ? and mo_ref = ? ';


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
    OInventory::log(3, "BUG! Trying to connect to db the DBI Handle was already "
                     . "active. Probably exited somewere on an error "
                     . "(like a connection timeout) without finishing "
                     . "DBI handle first. Don't worry, it's a minor bug.");
    return 1;
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
                          RaiseError => 1,
                          PrintError => 0,
                          ShowErrorStatement => 1,
                          mysql_enable_utf8 => 1
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

  if($r) {
    OInventory::log(1, "Successfully checked if connected to database: "
                     . "connected");
  }
  else {
    OInventory::log(1, "Successfully checked if connected to database: "
                     . "not connected");
  }
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


#
# Rollback transaction
#
# @return 1 if ok, 0 if errors.
#
sub transactionRollback {
  OInventory::log(0, "Rolling back DB transaction");

  eval {
    if(! $dbh->rollback()) {
      OInventory::log(3, "Errors rolling back DB transaction: "
                       . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors rolling back DB transaction: $@");
    return 0;
  }

  OInventory::log(1, "Successfully rolled back DB transaction");
  return 1;
}


#
# Get all entities of a type from DB that are son of an entity.
#
# @arg entityType (Folder | Datacenter | ClusterComputeResource
#                         | HostSystem | VirtualMachine | PerfCounterInfo)
# @arg mo_ref of the parent folder
# @return undef (if errors),
#         or a reference to array of references to entity objects (if ok)
#         : objects OFolder | ODatacenter | OCluster | OHost
#                           | OVirtualMachine | OPerfCounterInfo
#
sub getAllChildEntitiesOfType {
  my $entityType = shift;
  my $mo_ref     = shift;
  my @r = ();
  my @data;

  if(!defined($mo_ref) || $mo_ref eq '') {
    Carp::croak("OvomDao.getAllChildEntitiesOfType needs a mo_ref as 2nd arg");
    return undef;
  }

  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $stmt;
  my $sthRes;
  OInventory::log(0, "Getting entities of type $entityType son of $mo_ref");

  if($entityType eq 'Folder') {
    $stmt = $sqlFolderSelectAllChild;
  }
# elsif($entityType eq 'Datacenter') {
#   $stmt = $sqlDatacenterSelectAllChild;
# }
# elsif($entityType eq 'ClusterComputeResource') {
#   $stmt = $sqlClusterSelectAllChild;
# }
# elsif($entityType eq 'HostSystem') {
#   $stmt = $sqlHostSelectAllChild;
# }
  elsif($entityType eq 'VirtualMachine') {
    $stmt = $sqlVirtualMachineSelectAllChild;
  }
# elsif($entityType eq 'PerfCounterInfo') {
#   $stmt = $sqlPerfCounterInfoSelectAllChild;
# }
  else {
    Carp::croak("Not implemented for $entityType "
              . "in OvomDao.getAllChildEntitiesOfType");
    return undef;
  }

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement to get ${entityType}s: "
                     . "son of $mo_ref: (" . $dbh->err . ") :" . $dbh->errstr;
    $sthRes = $sth->execute($mo_ref);

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to get ${entityType}s "
                  . "son of $mo_ref");
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
      elsif($entityType eq 'PerfCounterInfo') {
        $e = OPerfCounterInfo->new(\@data);
        push @r, $e;
      }
      else {
        Carp::croak("Not implemented for $entityType "
                  . "in OvomDao.getAllChildEntitiesOfType");
        return undef;
      }
    }
  };
  if($@) {
    OInventory::log(3, "Errors getting ${entityType}s from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: select child ${entityType}s took "
                        . sprintf("%.3f", $eTime) . " s "
                        . "and returned " . ($#r + 1) . " entities");
  return \@r;
}


#
# Get all entities of a type from DB.
#
# @arg entityType (Folder | Datacenter | ClusterComputeResource
#                         | HostSystem | VirtualMachine | PerfCounterInfo)
# @return undef (if errors),
#         or a reference to array of references to entity objects (if ok)
#         : objects OFolder | ODatacenter | OCluster | OHost
#                           | OVirtualMachine | OPerfCounterInfo
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
  elsif($entityType eq 'PerfCounterInfo') {
    $stmt = $sqlPerfCounterInfoSelectAll;
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
      elsif($entityType eq 'PerfCounterInfo') {
        $e = OPerfCounterInfo->new(\@data);
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
# Get the child entities of certain folder 
#
# @arg folder mo_ref
# @return undef (if errors),
#         or a reference to a hash of arrays
#         of references to entity objects (if ok)
#         hash keys: OFolder | ODatacenter | OCluster | OHost | OVirtualMachine
#
sub getChildEntitiesOfFolder {
  my $folderMoRef = shift;
  my $r = {};
  my $p;

  if(!defined($folderMoRef)) {
    OInventory::log(3, "getChildEntitiesOfFolder needs a folder moRef");
    return undef;
  }

  # @arg entityType (Folder | Datacenter | ClusterComputeResource
  #                         | HostSystem | VirtualMachine | PerfCounterInfo)

  for my $type (('Folder', 'VirtualMachine')) {
    $p = getAllChildEntitiesOfType($type, $folderMoRef);
    if(!defined($p)) {
      OInventory::log(3, "getChildEntitiesOfFolder errors getting child $type");
      return undef;
    }
    $r->{$type} = $p;
  }

  return $r;
}



#
# Update an entity
#
# @return 1 (if ok), or 0 (if errors)
#
sub update {
  my $entity = shift;
  my $mor;

  # Pre-conditions
  if (! defined ($entity)) {
    Carp::croak("OvomDao.update missing entity parameter");
    return 0;
  }

  my $oClassName = ref($entity);

  # 0 = Datacenter           (entity with parent)
  # 1 = Entity no-Datacenter (entity with parent and has folder like networkF )
  # 2 = PerfCounterInfo      (hasn't parent, a regular update)
  # 3 = PerfMetric
  my $updateType = -1;
  my $stmt;
  my $desc;
  if(   $oClassName eq 'OFolder' 
     || $oClassName eq 'OMockView::OMockFolderView') {
    $stmt = $sqlFolderUpdate;
    $updateType = 1;
    $desc = $oClassName . ": " . $entity->toCsvRow();
  }
  elsif($oClassName eq 'ODatacenter'
     || $oClassName eq 'OMockView::OMockDatacenterView') {
    $stmt = $sqlDatacenterUpdate;
    $updateType = 0;
    $desc = $oClassName . ": " . $entity->toCsvRow();
  }
  elsif($oClassName eq 'OCluster'
     || $oClassName eq 'OMockView::OMockClusterView') {
    $stmt = $sqlClusterUpdate;
    $updateType = 1;
    $desc = $oClassName . ": " . $entity->toCsvRow();
  }
  elsif($oClassName eq 'OHost'
     || $oClassName eq 'OMockView::OMockHostView') {
    $stmt = $sqlHostUpdate;
    $updateType = 1;
    $desc = $oClassName . ": " . $entity->toCsvRow();
  }
  elsif($oClassName eq 'OVirtualMachine'
     || $oClassName eq 'OMockView::OMockVirtualMachineView') {
    $stmt = $sqlVirtualMachineUpdate;
    $updateType = 1;
    $desc = $oClassName . ": " . $entity->toCsvRow();
  }
  elsif($oClassName eq 'PerfCounterInfo'
     || $oClassName eq 'OPerfCounterInfo') {
    $stmt = $sqlPerfCounterInfoUpdate;
    $updateType = 2;
    $desc = $oClassName . ": key=" . $entity->key;
  }
  elsif($oClassName eq 'PerfMetricId'
     || $oClassName eq 'OMockView::OMockPerfMetricId') {
    $mor  = shift;
    if (! defined ($mor)) {
      Carp::croak("OvomDao.update missing mor (2nd extra) parameter");
      return 0;
    }

    $stmt = $sqlPerfMetricUpdate;
    $updateType = 3;
    $desc = $oClassName . ": counterId=" . $entity->counterId
            . ",instance=" . $entity->instance
            . " for entity with mo_ref='" . $mor->value . "'";
  }
  else {
    Carp::croak("Statement unimplemented for "
              . "unexpected class $oClassName in OvomDao.update");
    return 0;
  }

  #
  # Sanity check: Entities need mo_ref , name and parent
  #
  if($updateType == 0 || $updateType == 1) {
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
  }

  OInventory::log(1, "Updating into db the $desc");

  my $sthRes;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $sth;
    my $loadedParentId;

    if($updateType == 0 || $updateType == 1) {
      my $parentFolder   = OvomDao::loadEntity($entity->{parent}, 'Folder');
      if(! defined($parentFolder)) {
        Carp::croak("Can't load the parent of the $desc");
        return 0;
      }
      $loadedParentId = $parentFolder->{id};
    }
  
    $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement for updating the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

  # 0 = Datacenter           (entity with parent)
  # 1 = Entity no-Datacenter (entity with parent and has folder like networkF )
  # 2 = PerfCounterInfo      (hasn't parent, a regular update)
  # 3 = PerfMetric

    # PerfCounterInfo
    if($updateType == 2) {
      $sthRes = $sth->execute(
                  $entity->nameInfo->key ,
                  $entity->nameInfo->label ,
                  $entity->nameInfo->summary ,
                  $entity->groupInfo->key,
                  $entity->groupInfo->label,
                  $entity->groupInfo->summary,
                  $entity->unitInfo->key,
                  $entity->unitInfo->label,
                  $entity->unitInfo->summary,
                  $entity->rollupType->val,
                  $entity->statsType->val,
                  $entity->level,
                  $entity->perDeviceLevel,
                  $entity->key
                );
    }
    # PerfMetric
    elsif($updateType == 3) {
      $sthRes = $sth->execute($entity->counterId, $entity->instance, $mor->value);
    }
    # Host, Cluster, VirtualMachine, ...
    elsif($updateType == 1) {
      $sthRes = $sth->execute($entity->{name}, $loadedParentId,
                              $entity->{mo_ref});
    }
    # Datacenter
    elsif($updateType == 0) {
      #
      # First have to extract the folder id
      # for datastoreFolder, vmFolder, hostFolder and networkFolder
      #
      my $e;
      my ($datastoreFolderPid, $vmFolderPid, $hostFolderPid, $networkFolderPid);
      $e   = OvomDao::loadEntity($entity->{datastoreFolder}, 'Folder');
      die "Can't load the datastoreFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $datastoreFolderPid = $e->{id};
      $e   = OvomDao::loadEntity($entity->{vmFolder},        'Folder');
      die "Can't load the vmFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $vmFolderPid        = $e->{id};
      $e   = OvomDao::loadEntity($entity->{hostFolder},      'Folder');
      die "Can't load the hostFolder with id " . $entity->{datastoreFolder}
        . " when updating $oClassName with mo_ref " . $entity->{mo_ref}
        if (!defined($e));
      $hostFolderPid      = $e->{id};
      $e   = OvomDao::loadEntity($entity->{networkFolder},   'Folder');
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
      Carp::croak("Statement execution still unimplemented in OvomDao.update");
      return 0;
    }

    if(! $sthRes) {
      Carp::croak("Can't execute the statement for updating the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't updated any $oClassName trying to update the $desc");
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors updating the $desc into DB: $@");
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
  if (! defined($entity)) {
    Carp::croak("OvomDao.delete needs an object as argument");
    return 0;
  }
  my $oClassName = ref($entity);
  if ($oClassName eq '') {
    Carp::croak("OvomDao.delete needs an object");
    return 0;
  }

  my $desc;
  my $stmt;
  if(   $oClassName eq 'OFolder'
     || $oClassName eq 'OMockView::OMockFolderView') {
    $stmt = $sqlFolderDelete;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'ODatacenter'
     || $oClassName eq 'OMockView::OMockDatacenterView') {
    $stmt = $sqlDatacenterDelete;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OCluster'
     || $oClassName eq 'OMockView::OMockClusterView') {
    $stmt = $sqlClusterDelete;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OHost'
     || $oClassName eq 'OMockView::OMockHostView') {
    $stmt = $sqlHostDelete;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OVirtualMachine'
     || $oClassName eq 'OMockView::OMockVirtualMachineView') {
    $stmt = $sqlVirtualMachineDelete;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'PerfCounterInfo'
     || $oClassName eq 'OPerfCounterInfo') {
    $stmt = $sqlPerfCounterInfoDelete;
    $desc  = "$oClassName with key='" . $entity->key . "'";
  }
  else {
    Carp::croak("Statement stil unimplemented "
              . "for '$oClassName' in OvomDao.delete");
    return 0;
  }

  OInventory::log(0, "Deleting from DB the $desc");
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  eval {
    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement to delete the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    $sthRes = $sth->execute($entity->{mo_ref});

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to delete the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Didn't deleted any $oClassName, "
                . "trying to delete the $desc");
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors deleting the $desc from DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: deleting the $desc took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

#
# Convert from VMware's entity name to ovom object name
#
# @arg entity name
# @return undef (if errors), or the ovom's object name (if ok)
#
sub entityName2ObjectName {
  my $entityName = shift;
  return undef if(!defined($entityName));

  if($entityName eq 'Folder') {
    return 'OFolder';
  }
  elsif($entityName eq 'Datacenter') {
    return 'ODatacenter';
  }
  elsif($entityName eq 'ClusterComputeResource') {
    return 'OCluster';
  }
  elsif($entityName eq 'HostSystem') {
    return 'OHost';
  }
  elsif($entityName eq 'VirtualMachine') {
    return 'OVirtualMachine';
  }
  elsif($entityName eq 'PerfCounterInfo') {
    return 'OPerfCounterInfo';
  }
  else {
    return undef;
  }
}


#
# Convert from ovom object name to VMware's entity name
#
# @arg ovom's object name
# @return undef (if errors), or the entity name (if ok)
#
sub oClassName2EntityName {
  my $objectName = shift;
  return undef if(!defined($objectName));

  if($objectName eq 'OFolder') {
    return 'Folder';
  }
  elsif($objectName eq 'ODatacenter') {
    return 'Datacenter';
  }
  elsif($objectName eq 'OCluster') {
    return 'ClusterComputeResource';
  }
  elsif($objectName eq 'OHost') {
    return 'HostSystem';
  }
  elsif($objectName eq 'OVirtualMachine') {
    return 'VirtualMachine';
  }
  elsif($objectName eq 'OPerfCounterInfo') {
    return 'PerfCounterInfo';
  }
  else {
    return undef;
  }
}

#
# Get an Entity from DB by mo_ref.
#
# @arg mo_ref
# @arg entity type (  Folder | Datacenter | ClusterComputeResource
#                   | HostSystem | VirtualMachine | PerfCounterInfo | PerfMetric)
# @return undef (if errors), or a reference to an Entity object (if ok)
#
sub loadEntity {
  my $aId      = shift;
  my $entityType = shift;
  my $stmt;
  my $r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $pmiInstance;
  my $pmiMor;

  if (! defined ($aId)) {
    Carp::croak("Got an undefined id trying to load a $entityType");
    return undef;
  }
  if ($aId eq '') {
    Carp::croak("Got an empty id trying to load a $entityType");
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

  if ($entityType eq 'Folder') {
    $stmt = $sqlFolderSelectByMoref;
  }
  elsif($entityType eq 'Datacenter') {
    $stmt = $sqlDatacenterSelectByMoref;
  }
  elsif($entityType eq 'ClusterComputeResource') {
    $stmt = $sqlClusterSelectByMoref;
  }
  elsif($entityType eq 'HostSystem') {
    $stmt = $sqlHostSelectByMoref;
  }
  elsif($entityType eq 'VirtualMachine') {
    $stmt = $sqlVirtualMachineSelectByMoref;
  }
  elsif($entityType eq 'PerfCounterInfo') {
    $stmt = $sqlPerfCounterInfoSelectByKey;
  }
  #
  # 2 extra args if inserting PerfMetric :
  #
  # * counterId of PerfMetric object ($pMI->->counterId)
  # * className (regular 2nd parameter)
  # * instance of PerfMetric object ($pMI->instance)
  # * managedObjectReference ($managedObjectReference->type (VirtualMachine, ...),
  #                           $managedObjectReference->value (it's mo_ref))
  elsif($entityType eq 'PerfMetric') {
    $stmt = $sqlPerfMetricSelectByKey;
    $pmiInstance = shift;
    $pmiMor      = shift;

    if (! defined ($pmiInstance)) {
      Carp::croak("Got an undefined instance trying to load a $entityType");
      return undef;
    }
    if (! defined ($pmiMor)) {
      Carp::croak("Got an undefined mor trying to load a $entityType");
      return undef;
    }

  }
  else {
    Carp::croak("loadEntity not implemented for '$entityType'");
    return undef;
  }

  if($entityType eq 'PerfMetric') {
    OInventory::log(0, "selecting from db the ${entityType} metricId='$aId',"
                     . "instance='$pmiInstance',moRef='". $pmiMor->value . "'");
  }
  else {
    OInventory::log(0, "selecting from db the ${entityType} id/mo_ref='"
                     . $aId . "'");
  }

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement for all ${entityType}s: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    my $sthRes;
    if($entityType eq 'PerfMetric') {
      $sthRes = $sth->execute($aId, $pmiInstance, $pmiMor->value);
    }
    else {
      $sthRes = $sth->execute($aId);
    }

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to get the ${entityType} "
                . "with id = " . $aId);
      $sth->finish();
      return undef;
    }

    my $found = 0;
    while (@data = $sth->fetchrow_array()) {
      if ($found++ > 0) {
        if($entityType eq 'PerfMetric') {
          Carp::croak("Found more than one ${entityType} when "
                    . "looking for the one with metricId='$aId',"
                    . "instance='$pmiInstance',moRef='". $pmiMor->value . "'");
        }
        else {
          Carp::croak("Found more than one ${entityType} when "
                    . "looking for the one with id='$aId'");
        }
        $sth->finish();
        return undef;
      }

      if ($entityType eq 'Folder') {
        $r = OFolder->new(\@data);
      }
      elsif($entityType eq 'Datacenter') {
        $r = ODatacenter->new(\@data);
      }
      elsif($entityType eq 'ClusterComputeResource') {
        $r = OCluster->new(\@data);
      }
      elsif($entityType eq 'HostSystem') {
        $r = OHost->new(\@data);
      }
      elsif($entityType eq 'VirtualMachine') {
        $r = OVirtualMachine->new(\@data);
      }
      elsif($entityType eq 'PerfCounterInfo') {
        $r = OPerfCounterInfo->new(\@data);
      }
      elsif($entityType eq 'PerfMetric') {
        $r = OMockView::OMockPerfMetricId->new(\@data);
      }
      else {
        Carp::croak("Not implemented for $entityType in OvomDao.loadEntity");
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
# Get the Perf Metrics saved for an entity by its mo_ref.
#
# @arg mo_ref
# @return undef (if errors), or a reference to an array of OMockView::OMockPerfMetricId objects (if ok)
#
sub loadPerfMetricIdsForEntity {
  my $mo_ref = shift;
  my $stmt;
  my @r;
  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;
  my $pmiInstance;
  my $pmiMor;

  if (! defined ($mo_ref)) {
    Carp::croak("Got an undefined mo_ref trying to load PerfMetricIds for $mo_ref");
    return undef;
  }
  $stmt = $sqlPerfMetricSelectEntityPMs;
  OInventory::log(0, "selecting from db the PerfMetrics for $mo_ref");

  eval {
    my $sth = $dbh->prepare_cached($stmt)
                or die "Can't prepare statement for PerfMetricIds of $mo_ref: "
                     . "(" . $dbh->err . ") :" . $dbh->errstr;
    my $sthRes;
    $sthRes = $sth->execute($mo_ref);

    if(! $sthRes) {
      Carp::croak("Can't execute the statement to get "
                . "the PerfMetricIds for ${mo_ref}");
      $sth->finish();
      return undef;
    }

    while (@data = $sth->fetchrow_array()) {
      my $e = OMockView::OMockPerfMetricId->new(\@data);
      push @r, $e;
    }
  };

  if($@) {
    OInventory::log(3, "Errors getting the PerfMetriIds of $mo_ref from DB: $@");
    return undef;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: select PerfMetricIds for $mo_ref took "
                        . sprintf("%.3f", $eTime) . " s");
  return \@r;
}


#
# Insert an object into DB
#
# @return 1 (if ok), or 0 (if errors)
#
sub insert {
  my $entity = shift;
  my $mor;

  # Pre-conditions
  if (! defined($entity)) {
    Carp::croak("OvomDao.insert needs an entity");
    return 0;
  }
  my $oClassName = ref($entity);

  # 0 = Datacenter           (entity with parent)
  # 1 = Entity no-Datacenter (entity with parent and has folder like networkF )
  # 2 = PerfCounterInfo      (hasn't parent, a regular update)
  my $desc;
  my $insertType = -1;
  my $stmt;
  if(   $oClassName    eq 'OFolder'
     || $oClassName eq 'OMockView::OMockFolderView') {
    $stmt = $sqlFolderInsert;
    $insertType = 1;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'ODatacenter'
     || $oClassName eq 'OMockView::OMockDatacenterView') {
    $stmt = $sqlDatacenterInsert;
    $insertType = 0;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OHost'
     || $oClassName eq 'OMockView::OMockHostView') {
    $stmt = $sqlHostInsert;
    $insertType = 1;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OCluster'
     || $oClassName eq 'OMockView::OMockClusterView') {
    $stmt = $sqlClusterInsert;
    $insertType = 1;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'OVirtualMachine'
     || $oClassName eq 'OMockView::OMockVirtualMachineView') {
    $stmt = $sqlVirtualMachineInsert;
    $insertType = 1;
    $desc  = "$oClassName with mo_ref='" . $entity->{mo_ref}
           . "',name='" . $entity->{name} . "'";
  }
  elsif($oClassName eq 'PerfCounterInfo'
     || $oClassName eq 'OPerfCounterInfo') {
    $stmt = $sqlPerfCounterInfoInsert;
    $insertType = 2;
    $desc  = "$oClassName with key='" . $entity->key . "'";
  }
  elsif($oClassName eq 'PerfMetricId'
     || $oClassName eq 'OMockView::OMockPerfMetricId') {
    $mor  = shift;
    $stmt = $sqlPerfMetricInsert;
    $insertType = 3;
    $desc  = "$oClassName with counterId='" . $entity->counterId
           . "',instanceId='" . $entity->instance . "'";
  }
  else {
    Carp::croak("Statement unimplemented for '$oClassName' in OvomDao.insert");
    return 0;
  }

  if($insertType == 0 || $insertType == 1) {
    if( ! defined($entity->{mo_ref}) || $entity->{mo_ref} eq '' ) {
      Carp::croak("Trying to insert a $desc without mo_ref");
      return 0;
    }
    if( ! defined($entity->{name}) || $entity->{name} eq '' ) {
      Carp::croak("Trying to insert a $desc without name");
      return 0;
    }
    if( ! defined($entity->{parent}) || $entity->{parent} eq '' ) {
      Carp::croak("Trying to insert a $desc without parent");
      return 0;
    }
  }

  if($insertType == 3) {
    if( ! defined($mor->value) || $mor->value eq '' ) {
      Carp::croak("Trying to insert a $desc without related mo_ref");
      return 0;
    }
    $desc  = "$oClassName with counterId='" . $entity->counterId
           . "',instanceId='" . $entity->instance
           . "' for entity with mo_ref='" . $mor->value . "'";
  }
 

  OInventory::log(1, "Inserting into db the $desc");

  my @data;
  my ($timeBefore, $eTime);
  $timeBefore=Time::HiRes::time;

  my $loadedParentId;
  eval {

    if($insertType == 0 || $insertType == 1) {
      my $parentFolder = OvomDao::loadEntity($entity->{parent}, 'Folder');
      if( ! defined($parentFolder) ) {
        Carp::croak("Can't find the parent for the $desc");
        return 0;
      }
      $loadedParentId = $parentFolder->{id};
      if( ! defined($loadedParentId) ) {
        Carp::croak("Can't get the id of the parent for the $desc");
        return 0;
      }
    }

    my $sth = $dbh->prepare_cached($stmt);
    if(! $sth) {
      Carp::croak("Can't prepare statement for inserting the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      return 0;
    }

    my $sthRes;
    if($insertType == 1) {
      $sthRes = $sth->execute($entity->{name}, $entity->{mo_ref}, $loadedParentId);
    }
    elsif($insertType == 2) {
      $sthRes = $sth->execute(
        $entity->key,
        $entity->nameInfo->key ,
        $entity->nameInfo->label ,
        $entity->nameInfo->summary ,
        $entity->groupInfo->key,
        $entity->groupInfo->label,
        $entity->groupInfo->summary,
        $entity->unitInfo->key,
        $entity->unitInfo->label,
        $entity->unitInfo->summary,
        $entity->rollupType->val,
        $entity->statsType->val,
        $entity->level,
        $entity->perDeviceLevel
      );
    }
    elsif($insertType == 3) {
      $sthRes = $sth->execute(
                               $mor->value,
                               $entity->counterId ,
                               $entity->instance
                             );
    }
    elsif($insertType == 0) {
      #
      # First have to extract the folder id
      # for datastoreFolder, vmFolder, hostFolder and networkFolder
      #
      my $e;
      my ($datastoreFolderPid, $vmFolderPid, $hostFolderPid, $networkFolderPid);

      if( ! defined($entity->{datastoreFolder}) || $entity->{datastoreFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert the $desc but hasn't datastoreFolder");
        return 0;
      }
      if( ! defined($entity->{vmFolder}) || $entity->{vmFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert the $desc but hasn't vmFolder");
        return 0;
      }
      if( ! defined($entity->{hostFolder}) || $entity->{hostFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert the $desc but hasn't hostFolder");
        return 0;
      }
      if( ! defined($entity->{networkFolder}) || $entity->{networkFolder} eq '' ) {
        $sth->finish();
        Carp::croak("Trying to insert the $desc but hasn't networkFolder");
        return 0;
      }

      # Let's go:
      $e   = OvomDao::loadEntity($entity->{datastoreFolder}, 'Folder');
      die "Can't load the datastoreFolder with id " . $entity->{datastoreFolder}
        . " when inserting the $desc"
        if (!defined($e));
      $datastoreFolderPid = $e->{id};
      $e   = OvomDao::loadEntity($entity->{vmFolder},        'Folder');
      die "Can't load the vmFolder with id " . $entity->{datastoreFolder}
        . " when inserting the $desc"
        if (!defined($e));
      $vmFolderPid        = $e->{id};
      $e   = OvomDao::loadEntity($entity->{hostFolder},      'Folder');
      die "Can't load the hostFolder with id " . $entity->{datastoreFolder}
        . " when inserting the $desc"
        if (!defined($e));
      $hostFolderPid      = $e->{id};
      $e   = OvomDao::loadEntity($entity->{networkFolder},   'Folder');
      die "Can't load the networkFolder with id " . $entity->{datastoreFolder}
        . " when inserting the $desc"
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
      Carp::croak("Insert statement unimplemented for $oClassName");
      return 0;
    }

    if(! $sthRes) {
      Carp::croak("Can't execute the statement for inserting the $desc: "
                 . "(" . $dbh->err . ") :" . $dbh->errstr);
      $sth->finish();
      return 0;
    }
    if(! $sthRes > 0 || $sthRes eq "0E0") {
      Carp::croak("Couldn't insert the $desc");
      return 0;
    }
  };

  if($@) {
    OInventory::log(3, "Errors inserting the $desc into DB: $@");
    return 0;
  }

  $eTime=Time::HiRes::time - $timeBefore;
  OInventory::log(1, "Profiling: insert a $oClassName took "
                        . sprintf("%.3f", $eTime) . " s");
  return 1;
}

1;

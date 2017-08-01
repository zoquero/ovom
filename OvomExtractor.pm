package OvomExtractor;
use strict;
use warnings;
use Exporter;
use Cwd 'abs_path';
use File::Basename;
use POSIX qw/strftime/;
use Time::Piece;
use IO::Handle;  ## autoflush
use VMware::VIRuntime;


our @ISA= qw( Exporter );

# Functions that CAN be exported:
our @EXPORT_OK = qw( updateInventory getLatestPerformance collectorInit collectorStop readConfiguration log );

# # Functions that are exported by default:
# our @EXPORT = qw( getLatestPerformance );

our %configuration;
our %ovomGlobals;
our %inventory; # keys = vDCs, vms, hosts, clusters, folders
our @counterTypes = ("cpu", "mem", "net", "disk", "sys");

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


sub connect {
  my $vCWSUrl = 'https://'
                . $OvomExtractor::configuration{'vCenterName'}
                . '/sdk/webService';
  eval { Util::connect($vCWSUrl,
                       $OvomExtractor::configuration{'vCUsername'},
                       $OvomExtractor::configuration{'vCPassword'}); };
  if($@) {
    OvomExtractor::log(3, "Errors connecting to $vCWSUrl: $@");
    return 1;
  }
  OvomExtractor::log(1, "Successfully connected to $vCWSUrl");
  return 0;
}


sub disconnect {
  eval { Util::disconnect(); };
  if($@) {
    OvomExtractor::log(3, "Errors disconnecting from vCenter : $@");
    return 1;
  }
  OvomExtractor::log(1, "Successfully disconnected from vCenter");
  return 0;
}


#
# Pushes entities to the inventory hash.
# The pushed object is a hash with data.
#
# @param Array of Views from VIM API
# @param string specifying the type.
#               It can be: vDCs | vms | hosts | clusters | folders
# @return none
#
sub pushToInventory {
  my $entityViews = shift;
  my $type    = shift;
  foreach my $aEntityView (@$entityViews) {
    my %aEntity = (); # keys = name, ... folders?
    # Common attributes
    $aEntity{'name'} = $aEntityView->name;
    # Specific attributes
    if($type eq 'vDCs') {
    }
    elsif($type eq 'vms') {
    }
    elsif($type eq 'hosts') {

# parent 
# runtime.standbyMode
# runtime.powerState
# runtime.inMaintenanceMode
# config.host | mo_ref
# summary.hardware.memorySize
# summary.hardware.numCpuCores
# summary.hardware.numCpuThreads

      $aEntity{'parent'}                         = $aEntityView->parent;
#     $aEntity{'mo_ref'}                         = $aEntityView->mo_ref;
      $aEntity{'summary.hardware.memorySize'}    = $aEntityView->summary->hardware->memorySize;
      $aEntity{'summary.hardware.numCpuCores'}   = $aEntityView->summary->hardware->numCpuCores;
      $aEntity{'summary.hardware.numCpuThreads'} = $aEntityView->summary->hardware->numCpuThreads;
    }
    elsif($type eq 'clusters') {
    }
    elsif($type eq 'folders') {
    }
    else {
      OvomExtractor::log(3, "Unexpected type '$type' in pushToInventory");
    }

    push @{$inventory{$type}}, \%aEntity;
  }
}


#
# Gets inventory from vCenter and updates globals @hostArray and @vmArray .
#
# @return 1 error, 0 ok
#
#
sub updateInventory {
  my @hosts = ();
  my @vms   = ();
  my ($timeBefore, $timeAfter);

  #
  # Let's connect to vC:
  #
  return 1 if(OvomExtractor::connect());

  #################
  # get datacenters
  #################
  # Folder | HostSystem | ResourcePool | VirtualMachine | ComputeResource | DataCenter | ClusterComputeResource
#  my $dcViews = Vim::find_entity_views(view_type => 'DataCenter',
#                                   properties => ['name']);
##                                  properties => ['name','summary']

  OvomExtractor::log(0, "Getting DataCenter list");
  my $dcViews;
  $timeBefore=time;
  eval {
    $dcViews = Vim::find_entity_views(
      'view_type'  => 'Datacenter',
#     'properties' => ['name','parent','datastoreFolder','vmFolder','datastore','hostFolder','network','networkFolder']
      'properties' => ['name'] # 1/10 data, faster if you just need the vDC name
    );
  };
  if($@) {
    OvomExtractor::log(3, "Errors getting DataCenters: $@");
    return 1;
  }
  $timeAfter=time;
  OvomExtractor::log(0, "Profiling: DataCenter list took " . ($timeAfter-$timeBefore));

  if (!@$dcViews) {
    OvomExtractor::log(3, "Can't find DataCenters in the vCenter");
  }


  @{$inventory{'vDCs'}} = ();
  foreach (@$dcViews) {
    print "DEBUG: DataCenter: " . $_->name . "\n";
#   print Dumper($_);
    pushToInventory($dcViews, 'vDCs'); ## pushes to $inventory{'vDCs'}
  }




  ###########
  # get hosts
  ###########
  OvomExtractor::log(0, "Getting host list");
  my $hostViews;
  $timeBefore=time;
  eval {
    $hostViews = Vim::find_entity_views(
      'view_type'  => 'HostSystem',
#     'properties' => ['name','runtime','config','summary']
      'properties' => ['name','summary']
    );
  };
  if($@) {
    OvomExtractor::log(3, "Errors getting hosts: $@");
    return 1;
  }
  $timeAfter=time;
  OvomExtractor::log(0, "Profiling: Host list took " . ($timeAfter-$timeBefore));

  if (!@$hostViews) {
    OvomExtractor::log(3, "Can't find hosts in the vCenter");
  }

  @{$inventory{'hosts'}} = ();
  foreach (@$hostViews) {
    print "DEBUG: Host: " . $_->name . "\n";
#   print Dumper($_);
    pushToInventory($hostViews, 'hosts'); ## pushes to $inventory{'hosts'}
  }



  #########
  # get VMs
  #########
  OvomExtractor::log(0, "Getting VM list");
  my $vmViews;
  $timeBefore=time;
  eval {
    $vmViews = Vim::find_entity_views(
      'view_type'  => 'VirtualMachine',
      'properties' => ['name']
    );
  };
  if($@) {
    OvomExtractor::log(3, "Errors getting VMs: $@");
    return 1;
  }
  $timeAfter=time;
  OvomExtractor::log(0, "Profiling: VM list took " . ($timeAfter-$timeBefore));

  if (!@$vmViews) {
    OvomExtractor::log(3, "Can't find VMs in the vCenter");
  }

  @{$inventory{'vms'}} = ();
  foreach (@$vmViews) {
    print "DEBUG: VM: " . $_->name . "\n";
#   print Dumper($_);
    pushToInventory($vmViews, 'vms'); ## pushes to $inventory{'vms'}
  }




#  print "DEBUG: Let's print vDC list:\n";
#  foreach my $aVdc (@{$inventory{'vDCs'}}) {
#    print "DEBUG: a vDC: " . $$aVdc{'name'} . "\n";
#  }
#  print "DEBUG: list printed\n";

  #
  # Let's disconnect to vC
  #
  return 1 if(OvomExtractor::disconnect());
  return 0;

#   my @hostArray = ();
#   my @vmArray   = ();
# 
#   my $parsingHosts = 0;
#   my $host  = '';
#   my $parsingVMs   = 0;
#   my $vm    = '';
#   my $line;


#   my $dcListCommand = $configuration{'command.dcList'} .
#                         " --datacenter " . $configuration{'vDataCenterName'} .
#                         " --server "     . $configuration{'vCenterName'};
# 
#   if($configuration{'debug.mock.enabled'}) {
#     @hostArray = split /;/, $configuration{'debug.mock.hosts'};
#     @vmArray   = split /;/, $configuration{'debug.mock.vms'};
#   }
#   else {
#     open CMD,'-|', $dcListCommand or die "Can't run $dcListCommand :" . $@;
#     while (defined($line=<CMD>)) {
#       if ( $line =~ /^Hosts found:$/ ) {
#         $parsingHosts = 1;
#         $parsingVMs   = 0;
#       }
#       elsif ( $line =~ /^VM's found:$/ ) {
#         $parsingHosts = 0;
#         $parsingVMs   = 1;
#       }
#       else {
#         next if $line =~ /^\s*$/;
#         $line =~ /^\d+: (.+)$/;
#         if($parsingHosts) {
#           $host = $1;
#           OvomExtractor::log(0, "updateInventory; host discovered = $host");
#           push @hostArray, $host;
#         }
#         elsif($parsingVMs) {
#           $vm = $1;
#           OvomExtractor::log(0, "updateInventory; vm discovered = $vm");
#           push @vmArray, $vm;
#         }
#       }
#     }
#     close CMD;
#     my $exit = $? >> 8;
#     if ($exit ne 0) {
#       OvomExtractor::log(3, "Bad exit status running $dcListCommand to get inventory");
#       return 1;
#     }
#   }
# 
#   $OvomExtractor::inventory{'hosts'} = \@hostArray;
#   $OvomExtractor::inventory{'vms'}   = \@vmArray;
# 
#   my($aHost, $aVM, $s);
#   $s = "Discovered hosts: ";
#   foreach $aHost (@{$OvomExtractor::inventory{'hosts'}}) {
#     $s .= "$aHost;";
#   }
#   OvomExtractor::log(0, $s);
#   
#   $s = "Discovered VMs: ";
#   foreach $aVM (@{$OvomExtractor::inventory{'vms'}}) {
#     $s .= "$aVM;";
#   }
#   OvomExtractor::log(0, $s);
# 
#   my($ch, $cv);
#   $ch = $#{$OvomExtractor::inventory{'hosts'}} + 1;
#   $cv = $#{$OvomExtractor::inventory{'vms'}}   + 1;
#   OvomExtractor::log(1, "Discovered $ch hosts and $cv VMs");
# 
#   # Let's create folders for performance
#   my $intervalNamesRef = getIntervalNames();
#   foreach $aHost (@{$OvomExtractor::inventory{'hosts'}}) {
#     my $folder = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/hosts/$aHost/";
#     if(! -d $folder) {
#       OvomExtractor::log(1, "Creating perfDataRoot folder for the host $aHost");
#       mkdir $folder or die "Failed to create folder for host $folder: $!";
#     }
#     foreach my $period (@$intervalNamesRef) {
#       $folder = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/hosts/" . $aHost . "/$period";
#       if(! -d $folder) {
#         OvomExtractor::log(1, "Creating perfDataRoot folder for the host $aHost, period $period");
#         mkdir $folder or die "Failed to create folder for host $folder: $!";
#       }
#     }
#   }
#   foreach $aVM (@{$OvomExtractor::inventory{'vms'}}) {
#     my $folder = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/vms/" . $aVM;
#     if(! -d $folder) {
#       OvomExtractor::log(1, "Creating perfDataRoot folder for the vm $aVM");
#       mkdir $folder or die "Failed to create folder for vm $folder: $!";
#     }
#     foreach my $period (@$intervalNamesRef) {
#       $folder = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/vms/" . $aVM . "/$period";
#       if(! -d $folder) {
#         OvomExtractor::log(1, "Creating perfDataRoot folder for the vm $aVM, period $period");
#         mkdir $folder or die "Failed to create folder for host $folder: $!";
#       }
#     }
#   }
}


#
# Gets last performance data from hosts and VMs
#
# @return 0 ok, 1 errors
#
sub getLatestPerformance {
  OvomExtractor::log(1, "Updating performance");

  my($aHost, $aVM);
  foreach $aVM (@{$OvomExtractor::inventory{'vms'}}) {
    if(getVmPerfs($aVM)) {
      OvomExtractor::log(3, "Errors getting performance from VM $aVM, moving to next");
      next;
    }
  }
  foreach $aHost (@{$OvomExtractor::inventory{'hosts'}}) {
    if(getHostPerfs($aHost)) {
      OvomExtractor::log(3, "Errors getting performance from Host $aHost, moving to next");
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
#                              " --server "      . $configuration{'vCenterName'} .
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
#                              " --server "      . $configuration{'vCenterName'} .
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
#   my $outputFile = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/vms/$vm/hour/$counterType.csv";
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
#   my $outputFile = $OvomExtractor::configuration{'perfDataRoot'} . "/" . $OvomExtractor::configuration{'vCenterName'} . "/hosts/$host/hour/$counterType.csv";
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

sub createDataFoldersIfNeeded {
  my $folder = $OvomExtractor::configuration{'perfDataRoot'};
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfDataRoot folder $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }
  my $vCenterFolder .= "$folder/" . $OvomExtractor::configuration{'vCenterName'};
  if(! -d $vCenterFolder) {
    OvomExtractor::log(1, "Creating perfDataRoot folder for the vCenter $vCenterFolder");
    mkdir $vCenterFolder or die "Failed to create $vCenterFolder: $!";
  }
  $folder = $vCenterFolder . "/hosts";
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfDataRoot folder for hosts of the vCenter $folder");
    mkdir $folder or die "Failed to create $folder: $!";
  }
  $folder = $vCenterFolder . "/vms";
  if(! -d $folder) {
    OvomExtractor::log(1, "Creating perfDataRoot folder for VMs of the vCenter $folder");
    mkdir $folder or die "Failed to create $folder: $!";
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

  OvomExtractor::log(1, "Configuration read");
  createDataFoldersIfNeeded();
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

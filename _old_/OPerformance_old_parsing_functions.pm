#
# Gets last performance data from hosts and VMs
#
# @return 1 ok, 0 errors
#
# sub getLatestPerformance {
#   OInventory::log(1, "Updating performance");
# 
#   OInventory::log(3, "The new version of getLatestPerformance is still in development ");
#   return 0;
# 
#   my($aHost, $aVM);
#   foreach $aVM (@{$OInventory::inventory{'VirtualMachine'}}) {
#     if(getVmPerfs($aVM)) {
#       OInventory::log(3, "Errors getting performance from VM $aVM, "
#                           . "moving to next");
#       next;
#     }
#   }
#   foreach $aHost (@{$OInventory::inventory{'HostSystem'}}) {
#     if(getHostPerfs($aHost)) {
#       OInventory::log(3, "Errors getting performance from Host $aHost, "
#                           . "moving to next");
#       next;
#     }
#   }
#   return 0;
# }


#
# Gets performance metrics for a VM
#
# @param VM name
# @return 0 ok, 1 errors (error running the command or data not available)
#
# sub getVmPerfs {
#   my ($vm) = shift;
#   my ($counterType);
#   foreach $counterType (@OInventory::counterTypes) {
#     my %vmPerfParams = ();
#     my $getVmPerfCommand = $configuration{'command.getPerf'} .
#                              " --server "      . $configuration{'vCenter.fqdn'} .
#                              " --countertype " . $counterType .
#                              " --vm "        . $vm;
#   
# print "DEBUG: ==== Let's get counter $counterType from vm $vm: ====\n";
#     OInventory::log(0, "Getting counter '$counterType' from vm '$vm' running '$getVmPerfCommand'");
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
#           OInventory::log(3, "Different sampleInfo on two counters " . 
#                        "on same vm $vm, same counterType $counterType");
#           next;
#         }
#       }
#       elsif($line =~ /^\s*Value\s*:\s*(.+)\s*$/) {
#         my $valTmp = $1;
# #       OInventory::log(0, "DEBUG.getVmPerfs(): Value pushed for $counter ($units): [" . $valTmp . "]\n");
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
#       OInventory::log(3, "Bad exit status running $getVmPerfCommand to get vm performance");
#       return 1;
#     }
# 
#     if($#counterUnitsArray < 0 || $#valuesRefArray < 0) {
#       OInventory::log(3, "Found no counter or no values on vm $vm, counterType $counterType");
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
#   return 0;
# }

#
# Gets performance metrics for a Host
#
# @param Host name
# @return 0 ok, 1 errors (error running the command or data not available)
#
# sub getHostPerfs {
#   my ($host) = shift;
#   my ($counterType);
#   foreach $counterType (@OInventory::counterTypes) {
#     my %hostPerfParams = ();
#     my $getHostPerfCommand = $configuration{'command.getPerf'} .
#                              " --server "      . $configuration{'vCenter.fqdn'} .
#                              " --countertype " . $counterType .
#                              " --host "        . $host;
#   
# print "DEBUG: ==== Let's get counter $counterType from host $host: ====\n";
#     OInventory::log(0, "Getting counter '$counterType' from host '$host' running '$getHostPerfCommand'");
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
#           OInventory::log(3, "Different sampleInfo on two counters " . 
#                        "on same host $host, same counterType $counterType");
#           next;
#         }
#       }
#       elsif($line =~ /^\s*Value\s*:\s*(.+)\s*$/) {
#         my $valTmp = $1;
# #       OInventory::log(0, "DEBUG.getHostPerfs(): Value pushed for $counter ($units): [" . $valTmp . "]\n");
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
#       OInventory::log(3, "Bad exit status running $getHostPerfCommand to get host performance");
#       return 1;
#     }
# 
#     if($#counterUnitsArray < 0 || $#valuesRefArray < 0) {
#       OInventory::log(3, "Found no counter or no values on host $host, counterType $counterType");
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
# }


# sub saveVmPerf {
#   my ($vmPerfParamsRef) = shift;
#   my ($vm, $counterType, @counterUnitsArray, @sampleInfo, @valuesArrayOfArrayOfRefs);
#   my (@aValuesArray);
#   my ($fh);
#   $vm              = $vmPerfParamsRef->{'vm'};
#   $counterType       = $vmPerfParamsRef->{'counterType'};
#   @counterUnitsArray = @{$vmPerfParamsRef->{'counterUnitsRefArray'}};
#   @sampleInfo        = @{$vmPerfParamsRef->{'sampleInfoArrayRef'}};
#   @valuesArrayOfArrayOfRefs = @{$vmPerfParamsRef->{'valuesRefOfArrayOfArrayOfRefs'}};
#   OInventory::log(0, "saveHostPerf: vm $vm , #counterUnitsArray=$#counterUnitsArray #sampleInfo=$#sampleInfo #valuesArrayOfArrayOfRefs=$#valuesArrayOfArrayOfRefs\n");
# 
#   foreach my $refToAnArrayOfValues (@valuesArrayOfArrayOfRefs) {
#     OInventory::log(0, "saveHostPerf: A comp of rtaaov: $#{$refToAnArrayOfValues} comps, 0=${$refToAnArrayOfValues}[0],  1=${$refToAnArrayOfValues}[1], ${$refToAnArrayOfValues}[2] ...\n");
#   }
# 
#   my $outputFile = $OInventory::configuration{'perfdata.root'} . "/" . $OInventory::configuration{'vCenter.fqdn'} . "/vms/$vm/hour/$counterType.csv";
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
# }


# sub saveHostPerf {
#   my ($hostPerfParamsRef) = shift;
#   my ($host, $counterType, @counterUnitsArray, @sampleInfo, @valuesArrayOfArrayOfRefs);
#   my (@aValuesArray);
#   my ($fh);
#   $host              = $hostPerfParamsRef->{'host'};
#   $counterType       = $hostPerfParamsRef->{'counterType'};
#   @counterUnitsArray = @{$hostPerfParamsRef->{'counterUnitsRefArray'}};
#   @sampleInfo        = @{$hostPerfParamsRef->{'sampleInfoArrayRef'}};
#   @valuesArrayOfArrayOfRefs = @{$hostPerfParamsRef->{'valuesRefOfArrayOfArrayOfRefs'}};
#   OInventory::log(0, "saveHostPerf: host $host , #counterUnitsArray=$#counterUnitsArray #sampleInfo=$#sampleInfo #valuesArrayOfArrayOfRefs=$#valuesArrayOfArrayOfRefs\n");
# 
#   foreach my $refToAnArrayOfValues (@valuesArrayOfArrayOfRefs) {
#     OInventory::log(0, "saveHostPerf: A comp of rtaaov: $#{$refToAnArrayOfValues} comps, 0=${$refToAnArrayOfValues}[0],  1=${$refToAnArrayOfValues}[1], ${$refToAnArrayOfValues}[2] ...\n");
#   }
# 
#   my $outputFile = $OInventory::configuration{'perfdata.root'} . "/" . $OInventory::configuration{'vCenter.fqdn'} . "/hosts/$host/hour/$counterType.csv";
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
# }

# sub getValuesArrayOfArraysFromArrayOfStrings {
#   my $valuesArrayOfStrings = shift;
#   my @arrayOfArrayRefs     = ();
#   foreach my $aValuesRefArray (@$valuesArrayOfStrings) {
#     my @aValuesArray = split /,/, $$aValuesRefArray;
# #   OInventory::log(0, "DEBUG.getValuesArrayOfArraysFromArrayOfStrings(): $#aValuesArray values: [0]=$aValuesArray[0], [1]=$aValuesArray[1], [2]=$aValuesArray[2], ...\n");
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


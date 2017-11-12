#!/usr/bin/perl -w

#
# Modified version of /usr/share/doc/vmware-vcli/samples/performance/performance.pl
#
# Sample run: $ ./extra/performancetest.pl vm yourvmname cpu vcenter.fqdn.yourdomain.com
#

use strict;
use warnings;
use VMware::VIRuntime;
use Data::Dumper;

use lib '../';
use OMockView::OMockPerfMetricId;
use OVirtualMachine;

# counter tables
my $all_counters;
my $cpu_counters;
my $memory_counters;
my $disk_counters;
my $system_counters;
my $net_counters;

# performance manager view
my $perfmgr_view;

# get vars
my $username = $ENV{'OVOM_VC_USERNAME'}; 
my $passwd   = $ENV{'OVOM_VC_PASSWORD'}; 
my $etype    = $ARGV[0]; # vm
my $ename    = $ARGV[1]; # vmname
my $stype    = $ARGV[2]; # cpu | mem | ...
my $server   = $ARGV[3]; # fqdn
my $vurl     ="https://$server/sdk";

print "Modified version of /usr/share/doc/vmware-vcli/samples/performance/performance.pl\n";
print "etype=$etype (vm|), ename=$ename (vmname...), stype=$stype (cpu | mem | ...), server=$server (vC fqdn), vurl=$vurl\n";

# connect to the server
Util::connect($vurl, $username, $passwd);

# initialize a table of counters for cpu, mem, etc.
#
# DEBUG: Vim::get_view(mo_ref => Vim::get_service_content()->perfManager) returns an object like this:
# PerformanceManager:
#   * perfCounter        : array of PerfCounterInfo objects, describing the perf counters available for that entity
#   * mo_ref             : its mo_ref (PerfMgr)
#   * description        : array of ElementDescription objects specifying what does mean 'maximum', 'summary', ...
#   * vim                : vim object describing the infrastrucuture
#   * historicalInterval : array of PerfInterval objects describint the perf intervals
#
# The PerfCounterInfo object keys can be more than cpu , mem , disk , sys and net:
# clusterServices cpu datastore disk gpu hbr managementAgent mem net pmem power rescpu
# storageAdapter storagePath sys vcDebugInfo vcResources vflashModule virtualDisk vmop vsanDomObj
#

# also initialices the $perfmgr_view object
init_perf_counter_info();


die "fill it with some of your entities to do it on a loop";
my @theEntities = ("myvm01", "myvm02", "myvm03", "myvm04");

# loop for each entity
foreach $ename (@theEntities) {
  print "ename=$ename\n";
  
  # find target virtual machine or host
  my $entity;
  if ($etype eq 'vm') {
     my $vm = $ename;
     $entity = Vim::find_entity_view(view_type => 'VirtualMachine',
  #           'properties' => ['name','parent'],
                                     filter => { name => $vm });
  } else {
     my $host = $ename;
     $entity = Vim::find_entity_view(view_type => 'HostSystem',
                                     filter => { name => $host });
  }
  
  
  my $myEntity = OVirtualMachine->newFromView($entity);
  
  
  if (!$myEntity->{view}) {
     die "Target entity not found\n";
  }
  
  #
  # $perfmgr_view->QueryAvailablePerfMetric(entity => $entity) returns a 
  # reference to an array of PerfMetricId objects like this:
  #          bless( {
  #                   'counterId' => '2',
  #                   'instance' => ''
  #                 }, 'PerfMetricId' ),
  #          bless( {
  #                   'instance' => '',
  #                   'counterId' => '6'
  #                 }, 'PerfMetricId' ),
  #          bless( {
  #                   'instance' => '',
  #                   'counterId' => '12'
  #                 }, 'PerfMetricId' ),
  #   ...
  #          bless( {
  #                   'instance' => 'DELTAFILE',
  #                   'counterId' => '240'
  #                 }, 'PerfMetricId' ),
  #          bless( {
  #                   'instance' => 'DISKFILE',
  #                   'counterId' => '240'
  #                 }, 'PerfMetricId' ),
  #          bless( {
  #                   'instance' => 'OTHERFILE',
  #                   'counterId' => '240'
  #                 }, 'PerfMetricId' ),
  #          bless( {
  #                   'counterId' => '240',
  #                   'instance' => 'SWAPFILE'
  #                 }, 'PerfMetricId' ),
  #
  my $availablePerfMetric = $perfmgr_view->QueryAvailablePerfMetric(entity => $myEntity->{view});
  
  # get all available metric id's for given counter_type
  # my $countertype = Opts::get_option('countertype');
  my $countertype = $stype; # cpu | mem | ...
  my $perf_metric_ids =
     filter_metric_ids($countertype,
                       $perfmgr_view->QueryAvailablePerfMetric(entity => $myEntity->{view}));
  
  
  
  
      # Just one PerfMetricId for debugging:
      print "DEBUG: Just counterId==2\n";
      my @reducedPerfMetricIds = ();
      foreach my $aPMI (@$perf_metric_ids) {
        if($aPMI->{counterId} == 2) {
  #       my $e = OMockView::OMockPerfMetricId->newFromPerfMetricId($aPMI);
  #print "e = " . Dumper($e) . "\n";
  # print "e = " . Dumper($aPMI) . "\n";
  #       push @reducedPerfMetricIds, $e;
          push @reducedPerfMetricIds, $aPMI;
          last;
        }
      }
      $perf_metric_ids = \@reducedPerfMetricIds;
  
  
  
  
  # make sure there is data available for this entity   
  if (!@$perf_metric_ids) {
     die "Performance data not available for " . $countertype . "\n";
  }
  
  # get all available perf intervals for this vm
  my $intervals = get_available_intervals($myEntity->{view});
  
  # performance data for the smallest interval in csv format
  #
  # more info on local file DUMP.perf_query_spec._vm_.out
  #
  my $perf_query_spec = PerfQuerySpec->new(entity => $myEntity->{view},
                                           metricId => $perf_metric_ids,
                                           format => 'csv',
                                           intervalId => shift @$intervals);
  
  # print "Printem el perfQuerySpec per depurar:\n";
  # print Dumper($perf_query_spec) . "\n";
  
  
  # get performance data
  #
  # more info on local file DUMP.QueryPerf._vm_.out
  #
  my $perf_data = $perfmgr_view->QueryPerf(querySpec => $perf_query_spec);
  
  # print "Printem el perf_data per depurar:\n";
  # print Dumper $perf_data;
  
  foreach (@$perf_data) {
     print "Performance data for: " . $myEntity->{view}->name . "\n\n";
     my $time_stamps = $_->sampleInfoCSV;
     my $values = $_->value;
     foreach (@$values) {
        print_counter_info($_->id->counterId, $_->id->instance);
        print "Sample info : " . $time_stamps . "\n";
        print "Value: " . $_->value . "\n\n";
     }
  }

}
## end of loop







# disconnect from the server
Util::disconnect();                                  



# initializes $perfmgr_view and sets up tables of cpu, mem, net, and disk
# counter info
sub init_perf_counter_info {
   $perfmgr_view = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);

# DEBUG: Vim::get_view(mo_ref => Vim::get_service_content()->perfManager) returns an object like this:
# PerformanceManager:
#   * perfCounter        : array of PerfCounterInfo objects, describing the perf counters available for that entity
#   * mo_ref             : its mo_ref (PerfMgr)
#   * description        : array of ElementDescription objects specifying what does mean 'maximum', 'summary', ...
#   * vim                : vim object describing the infrastrucuture
#   * historicalInterval : array of PerfInterval objects describint the perf intervals
#
# The PerfCounterInfo object keys can be more than cpu , mem , disk , sys and net:
# clusterServices cpu datastore disk gpu hbr managementAgent mem net pmem power rescpu
# storageAdapter storagePath sys vcDebugInfo vcResources vflashModule virtualDisk vmop vsanDomObj
#

   my $perfCounterInfo = $perfmgr_view->perfCounter;
   foreach (@$perfCounterInfo) {
      my $key = $_->key;
      $all_counters->{ $key } = $_;
      my $group_info = $_->groupInfo;
      if ($group_info->key eq 'cpu') {
         $cpu_counters->{ $key } = $_;
      } elsif ($group_info->key eq 'mem') {
         $memory_counters->{ $key } = $_;
      } elsif ($group_info->key eq 'disk') {
         $disk_counters->{ $key } = $_;
      } elsif ($group_info->key eq 'sys') {
         $system_counters->{ $key } = $_;
      } elsif ($group_info->key eq 'net') {
         $net_counters->{ $key } = $_;
      }
   }
}

# returns list of metric id's for cpu, mem, sys, disk, or net
sub filter_metric_ids {
   my ($type, $perf_metric_ids) = @_;
   if (! $all_counters) {
      init();
   }
   my $counters;
   if ($type eq 'cpu') {
      $counters = $cpu_counters;
   } elsif ($type eq 'mem') {
      $counters = $memory_counters;
   } elsif ($type eq 'sys') {
      $counters = $system_counters;
   } elsif ($type eq 'disk') {
      $counters = $disk_counters;
   } elsif ($type eq 'net') {
      $counters = $net_counters;
   } else {
      die 'Unknown counter type';
   }   
   my @filtered_list;
   foreach (@$perf_metric_ids) {
      if (exists $counters->{$_->counterId}) {
         push @filtered_list, $_;
      }
   }
   return \@filtered_list;   
}

# returns an array of available intervals for a VM
sub get_available_intervals {
   my $entity = shift;
   my $historical_intervals = $perfmgr_view->historicalInterval;
   my $provider_summary = $perfmgr_view->QueryPerfProviderSummary(entity => $entity);

#
# This provider_summary is a PerfProviderSummary object like this:
#
# $VAR1 = bless( {
#                  'entity' => bless( {
#                                       'value' => 'vm-42xxx',
#                                       'type' => 'VirtualMachine'
#                                     }, 'ManagedObjectReference' ),
#                  'currentSupported' => '1',
#                  'refreshRate' => '20',
#                  'summarySupported' => '1'
#                }, 'PerfProviderSummary' );
#

   my @intervals;
   if ($provider_summary->refreshRate) {
      push @intervals, $provider_summary->refreshRate;
   }
   foreach (@$historical_intervals) {
      push @intervals, $_->samplingPeriod;
   }
   return \@intervals;
}

# subroutine to print description of performance counter
sub print_counter_info {
   my ($counter_id, $instance) = @_;
   my $counter = $all_counters->{$counter_id};
   print "Counter: " . $counter->nameInfo->label . "\n";
   if (defined $instance) {
      print "Instance : " . $instance . "\n";
   }
   print "Description: " . $counter->nameInfo->summary . "\n";
   print "Units: " . $counter->unitInfo->label . "\n";   
}

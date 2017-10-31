#!/usr/bin/perl

#
# Script to troubleshoot this software,
# to find what's making that some perfData responses have empty data
#

use warnings;
use strict;

use FindBin;
use lib $FindBin::Bin;
use POSIX qw/strftime/;
use Time::HiRes; ## gettimeofday
use Data::Dumper;
use Cwd 'abs_path';
use File::Basename;
use Time::Piece;
use IO::Handle;          ## autoflush
use VMware::VIRuntime;
use Scalar::Util qw(looks_like_number);
use File::Copy qw(move); ## move to rotate logs

use OVirtualMachine;
use OPerfCounterInfo;
use OMockView::OMockStatsType;
use OMockView::OMockNameInfo;
use OMockView::OMockGroupInfo;
use OMockView::OMockRollupType;
use OMockView::OMockUnitInfo;

sub getPerfManager {
  my $maxSecs = shift;
  # Get Perf
  print "Get Perf Manager\n";
  my $perfManager;
  eval {
    local $SIG{ALRM} = sub { die "Timeout getting perfManager" };
    alarm $maxSecs;
    $perfManager = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
    alarm 0;
  };
  if($@) {
    alarm 0;
    if ($@ =~ /Timeout getting perfManager/) {
      die("Timeout! could not get perfManager from "
                       . "VIM service in a timely fashion: $@");
    }
    else {
      warn("Can't get perfManager from VIM service: $@");
      exit 1;
    }
  }
  if(! defined($perfManager)) {
    die("Can't get perfManager from VIM service.");
  }
  return $perfManager;
}

sub connectVCenter {
  my $vCWSUrl = shift;
  my $maxSecs = shift;
  my $user = $ENV{'OVOM_VC_USERNAME'};
  my $pass = $ENV{'OVOM_VC_PASSWORD'};
  eval {
    local $SIG{ALRM} = sub { die "Timeout connecting to vCenter" };
    warn("Connecting to vCenter, with ${maxSecs}s timeout");
    alarm $maxSecs;
    Util::connect($vCWSUrl, $user, $pass);
    alarm 0;
  };
  if($@) {
    alarm 0;
    die("Errors connecting to $vCWSUrl: $@");
  }
}

sub disconnectVCenter {
  my $maxSecs = shift;
  eval {
    local $SIG{ALRM} = sub { die "Timeout disconnecting from vCenter" };
    warn("Disconnecting from vCenter, with ${maxSecs}s timeout");
    alarm $maxSecs;
    Util::disconnect();
    alarm 0;
  };
  if($@) {
    die("Errors disconnecting from vCenter : $@");
  }
}


#
# VMware/VICommon.pm/SoapClient::request: response:
# 
# Returns a HTTP::Response object with '_content' field with an empty QueryPerfResponse:
# <QueryPerfResponse xmlns="urn:vim25"></QueryPerfResponse>
#
# Full Dumper:
# $VAR1 = bless( {
#                  '_protocol' => 'HTTP/1.1',
#                  '_rc' => '200',
#                  '_msg' => 'OK',
# ...
#                 '_content' => '<?xml version="1.0" encoding="UTF-8"?>
#<soapenv:Envelope xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
# xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# xmlns:xsd="http://www.w3.org/2001/XMLSchema"
# xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#<soapenv:Body>
#<QueryPerfResponse xmlns="urn:vim25"></QueryPerfResponse>
#</soapenv:Body>
#</soapenv:Envelope>'
#               }, 'HTTP::Response' );
#
# And the only difference in the requests compared to other exact corrct request
# done with a simplification of
# /usr/share/doc/vmware-vcli/samples/performance/performance.pl is the cookie:
#
# $VAR1 = bless( {
#                  '_headers' => bless( {
#                                         'soapaction' => '"urn:vim25/6.5"',
#                                         'cookie' => 'vmware_soap_session="f6bd44de3f277af4ffa51dc57XXXXXXXXXXXXXXX"',
#                  ...
#

  ## Connect to vC
  my $vCenterFqdn = $ARGV[0];
  if (!defined($vCenterFqdn) || $vCenterFqdn eq '') {
    die "missing vcenter fqdn arg";
  }
  my $vCWSUrl = "https://$vCenterFqdn" . '/sdk/webService';
  my $maxSecs = 20;
  my %inventory = ();
  my %allCounters        = ();
  my %allCountersByGIKey = ();

  connectVCenter($vCWSUrl, $maxSecs);

  ## Get VM List:
  print "Get VM List\n";
  my $aEntityType = 'VirtualMachine';
  my $entityViews;
  eval {
    local $SIG{ALRM} = sub {die "Timeout calling Vim::find_entity_views"};
    alarm $maxSecs;
    $entityViews = Vim::find_entity_views(
      'view_type'  => $aEntityType,
      'properties' => ['name','parent']
    );
    alarm 0;
  };
  if ($@) {
    alarm 0;
    die ("Vim::find_entity_views failed: $@");
  }
  if (!@$entityViews) {
    die("Can't find ${aEntityType}s in the vCenter");
  }

  # Save VM list
  print "Save VM list\n";
  foreach my $aEntityView (@$entityViews) {
    my $aEntity;
    print "name=" . $aEntityView->{name} . ",mo_ref=" . $aEntityView->{mo_ref}->{value} . ",parent=" . $aEntityView->{parent}->{value} . "\n";
    $aEntity = OVirtualMachine->newFromView($aEntityView);


#   if($aEntity->{mo_ref} ne 'vm-10068') {
#     print "We don't push this entity, to concentrate in the only entity\n";
#     next;
#   }

    push @{$inventory{$aEntityType}}, $aEntity;
#die Dumper($aEntity);
  }

  # Get Perf
  print "Get Perf\n";
  print "Get Perf Manager\n";
  my $perfManager = getPerfManager($maxSecs);
  if(! defined($perfManager)) {
    die("Can't get perfManager from VIM service.");
  }


  # Init PerfCounterInfo
  print "Init PerfCounterInfo\n";
  my $perfCounterInfo;
  eval {
    $perfCounterInfo = $perfManager->perfCounter;
  };
  if($@) {
    die("Can't get perfCounter from perfManagerView: $@");
  }

  # Let's cache each PerfCounterInfo
  print "Let's cache each PerfCounterInfo\n";
  foreach my $pCI (@$perfCounterInfo) {
    my $oPCI = OPerfCounterInfo->newFromPerfCounterInfo($pCI);
    # Let's cache all PerfCounterInfo to accelerate posterior access:
    #
    $allCounters{$oPCI->key} = $oPCI;
    push @{$allCountersByGIKey{$oPCI->groupInfo->key}}, $oPCI;
    print "Pushed oPCI key=" . $oPCI->key . ",nameInfoLabel=" . $oPCI->nameInfo->label . "\n";
  }

  # Let's iterate foreach entity
  print "Let's iterate foreach entity\n";


  my $mustShuffle = 0;
  my $array=\@{$inventory{$aEntityType}};
  if($mustShuffle) {
    print "Let's shuffle the array of entities\n";
    for (my $i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
  }
  else {
    print "We'll no shuffle the array of entities\n";
  }

  foreach my $aEntity (@$array) {

#   disconnectVCenter($maxSecs);
#   connectVCenter($vCWSUrl, $maxSecs);

#   print "Get Perf Manager again\n";
#   $perfManager = getPerfManager($maxSecs);
#   if(! defined($perfManager)) {
#     die("Can't get perfManager from VIM service.");
#   }

    print "Getting performance for " . $aEntity->{name} . "\n";

    my $mustReloadEntity = 0;
    if($mustReloadEntity) {
      print "let's try to reload from vCenter this entity\n";
      my $reloadedEntity;
      eval {
        local $SIG{ALRM} = sub {die "Timeout calling Vim::find_entity_view"};
        alarm $maxSecs;
        $reloadedEntity = Vim::find_entity_view(view_type  => $aEntityType,
                                                properties => ['name','parent'],
                                                filter     => { name => $aEntity->{name} });
        alarm 0;
      };
      if ($@) {
        alarm 0;
        die ("Vim::find_entity_view failed: $@");
      }
      if (!defined($reloadedEntity)) {
        die("Can't find the ${aEntityType}s in the vCenter");
      }
  
      print "Loaded ${aEntityType}: " . $reloadedEntity->{name} . "\n";
      $aEntity->{view} = $reloadedEntity;
    }


    # Query available PerfMetrics
    print("Let's queryAvailablePerfMetric\n");
    my $availablePerfMetricIds;
    eval {
      local $SIG{ALRM} = sub { die "Timeout calling QueryAvailablePerfMetric" };
      alarm $maxSecs;
      $availablePerfMetricIds =
        $perfManager->QueryAvailablePerfMetric(entity => $aEntity->{view});
      alarm 0;
    };
    if ($@) {
      alarm 0;
      if ($@ =~ /Timeout calling QueryAvailablePerfMetric/) {
        die("Timeout! perfManager->QueryAvailablePerfMetric "
                         . "did not respond in a timely fashion: $@");
      } else {
        die("perfManager->QueryAvailablePerfMetric failed: $@");
      }
    }

    # Just one PerfMetricId for debugging:
    my @reducedPerfMetricIds = ();
    foreach my $aPMI (@$availablePerfMetricIds) {
      if($aPMI->{counterId} == 2) {
        push @reducedPerfMetricIds, $aPMI;
        last;
      }
    }

    print "Available PerfMetricIds for " . $aEntity->{name} . " = " . ($#$availablePerfMetricIds+1) . ". Finally used just " . ($#reducedPerfMetricIds+1) . "\n";

    my $perfQuerySpec = PerfQuerySpec->new(entity     => $aEntity->{view},
                                           metricId   => \@reducedPerfMetricIds,
                                           format     => 'csv',
                                           intervalId => 20);


    # Get PerfData
    print "Get PerfData\n";
    my $perfData;

    eval {
      local $SIG{ALRM} = sub { die "Timeout calling QueryPerf" };
      alarm $maxSecs;

      # /usr/share/perl/5.22.1/VMware/VIM25Runtime.pm :: QueryPerf 
      # => Util::check_fault($self->invoke('QueryPerf', %args))
      #     /usr/share/perl/5.22.1/VMware/VICommon.pm
      # ==> $runtime->$method(_this => $mo_ref, %args);  # runtime == VimService
      #     /usr/share/perl/5.22.1/VMware/VIM25Stub.pm QueryPerf , line 85729
      # ===> Call to $vim_soap->request('QueryPerf', $arg_string, $soap_action) returns empty result array
      # ===> /usr/share/perl/5.22.1/VMware/VICommon.pm VMware/VICommon.pm/SoapClient::request

      $perfData = $perfManager->QueryPerf(querySpec => $perfQuerySpec);
      alarm 0;
    };
    if ($@) {
      alarm 0;
      if ($@ =~ /Timeout calling QueryPerf/) {
        die("Timeout! perfManager->QueryPerf did not respond "
                         . "in a timely fashion: $@");
      } else {
        die("perfManager->QueryPerf failed: $@");
      }
    }

    if (! defined ($perfData)) {
      die("perfManager->QueryPerf returned undef");
    }
  
    if ($#$perfData == -1) {
      my $d = Dumper($perfData);
      chomp($d);
      print("perfManager->QueryPerf returned "
                       . "an empty array of PerfEntityMetricCSV: " . $d
                       . " for " . $aEntity->{name} . "\n");
      warn("perfManager->QueryPerf returned "
                       . "an empty array of PerfEntityMetricCSV: " . $d
                       . " for " . $aEntity->{name} . "\n");
    }
    else {
      print "Returned " . ($#$perfData+1) . " perfData\n";
      print "perf data length = " . length($perfData) . "for " . $aEntity->{name} . "\n";
    }

  }



  ## Disconnect vC
  print "Disconnect from vC\n";
  eval {
    local $SIG{ALRM} = sub { die "Timeout disconnecting from vCenter" };
    alarm $maxSecs;
    Util::disconnect();
    alarm 0;
  };
  if($@) {
    alarm 0;
    die("Errors disconnecting from vCenter : $@");
  }


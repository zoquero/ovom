#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );
use Data::Dumper;
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '..', '.');
# Our own libs:
use OInventory;
use OWwwLibs;

###############################################################################
#######                              Main                                 #####
###############################################################################

#
# Read configuration
#
if( ! OInventory::webuiInit() ) {
  die "Could not read configuration and open log files";
}

my $session   = CGI::Session->load();
my $cgiObject = new CGI;

if($session->is_expired) {
  OWwwLibs::respondSessionExpired($cgiObject);
}
elsif($session->is_empty) {
  OWwwLibs::respondSessionNotInitiated($cgiObject);
}
else {
  $session->expire($OInventory::configuration{'web.session.timeoutSecs'});
  my $actionId = $cgiObject->param('actionId');
  if(! defined($actionId) || $actionId eq ''
            || $actionId == $OWwwLibs::ACTION_ID_MENU_ENTRY) {
    my $menuEntryId = $cgiObject->param('menuEntryId');
    OWwwLibs::respondShowNavEntry($cgiObject, $menuEntryId);
  }
  elsif($actionId == $OWwwLibs::ACTION_ID_ON_MANAGED_OBJECT) {
    my $type   = $cgiObject->param('type');
    my $mo_ref = $cgiObject->param('mo_ref');
    OWwwLibs::respondShowEntity($cgiObject, $type, $mo_ref);
  }
  elsif($actionId == $OWwwLibs::ACTION_ID_ON_PERFORMANCE_OF_MANAGED_OBJECT) {
    my %args;
    $args{'type'}       = $cgiObject->param('type');
    $args{'mo_ref'}     = $cgiObject->param('mo_ref');
    $args{'fromYear'}   = $cgiObject->param('fromYear');
    $args{'fromMonth'}  = $cgiObject->param('fromMonth');
    $args{'fromDay'}    = $cgiObject->param('fromDay');
    $args{'fromHour'}   = $cgiObject->param('fromHour');
    $args{'fromMinute'} = $cgiObject->param('fromMinute');
    $args{'toYear'}     = $cgiObject->param('toYear');
    $args{'toMonth'}    = $cgiObject->param('toMonth');
    $args{'toDay'}      = $cgiObject->param('toDay');
    $args{'toHour'}     = $cgiObject->param('toHour');
    $args{'toMinute'}   = $cgiObject->param('toMinute');
    OWwwLibs::respondShowPerformance($cgiObject, \%args);
  }
  elsif($actionId == $OWwwLibs::ACTION_ID_SEARCH_FOR_ALARMS) {
    my %args;
    $args{'xxxxxx'}       = $cgiObject->param('xxxxxx');
    OWwwLibs::respondShowAlarmsReport($cgiObject, \%args);
  }
  else {
    OWwwLibs::triggerError($cgiObject, "Unknown actionId ($actionId)");
  }
}
exit(0);

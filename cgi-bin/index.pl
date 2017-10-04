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
  my $actionId = $cgiObject->url_param('actionId');
  if(! defined($actionId) || $actionId eq ''
            || $actionId == $OWwwLibs::ACTION_ID_MENU_ENTRY) {
    my $menuEntryId = $cgiObject->url_param('menuEntryId');
    OWwwLibs::respondShowNavEntry($cgiObject, $menuEntryId);
  }
  elsif($actionId == $OWwwLibs::ACTION_ID_ON_MANAGED_OBJECT) {
    my $type        = $cgiObject->url_param('type');
    my $moref       = $cgiObject->url_param('moref');
    OWwwLibs::respondShowEntity($cgiObject, $type, $moref);
  }
  else {
    OWwwLibs::triggerError($cgiObject, "Unknown actionId ($actionId)");
  }
}
exit(0);

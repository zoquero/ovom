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

#
# Read configuration
#
if( ! OInventory::readConfiguration() ) {
  die "Could not read configuration";
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
  OWwwLibs::respondContent($cgiObject);
}
exit(0);

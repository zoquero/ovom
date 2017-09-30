#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );
use Data::Dumper;
# Our own libs:
use OWwwLibs;

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

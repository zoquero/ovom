#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );
use FindBin;
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

my $adminUsername = $OInventory::configuration{'auth.admin.username'};
my $adminPassword = $OInventory::configuration{'auth.admin.password'};

my $cgiObject = new CGI;
my $username = $cgiObject->param('username');
my $password = $cgiObject->param('password');
my $session;

if($username ne '') {
  # process the form
  if($username eq $adminUsername and $password eq $adminPassword) {
    $session = new CGI::Session();
    print $session->header(-location=>'index.pl');
  }
  else {
    print $cgiObject->header(-type=>"text/html",-location=>"login.pl");
  }
}
elsif($cgiObject->param('action') eq 'logout') {
  $session = CGI::Session->load() or die CGI::Session->errstr;
  $session->delete();
  print $session->header(-location=>'login.pl');
}
else {
  OWwwLibs::respondAuthForm($cgiObject);
##   print $cgiObject->header;
##   print <<'HTML';
##     <form method="post">
##       Username: <input type="text"     name="usr"><br/>
##       Password: <input type="password" name="pwd"><br/>
##       <input type="submit" value="Authenticate"><br/>
##     </form>
## HTML
}

#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );

my $session = CGI::Session->load();
my $q = new CGI;

if($session->is_expired) {
    print $q->header(-cache_control=>"no-cache, no-store, must-revalidate");
    print "<html><body>\n";
    print "<p>Expired session</p>\n";
    print "<p>Please, <a href='login.pl>login</a> again</p>";
    print "</body></html>\n";
}
elsif($session->is_empty) {
    print $q->header(-cache_control=>"no-cache, no-store, must-revalidate");
    print "<html><body>\n";
    print "<p>You have not logged in</p>";
    print "<p>Please, <a href='login.pl'>login</a>.</p>";
    print "</body></html>\n";
}
else {
    print $q->header(-cache_control=>"no-cache, no-store, must-revalidate");
    print "<html><body>\n";
    print "<h2>Welcome</h2>";
    print "<p><a href='login.pl?action=logout'>Logout</a></p>";
    print "</body></html>\n";
}

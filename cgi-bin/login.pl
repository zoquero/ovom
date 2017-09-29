#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );

my $q = new CGI;
my $usr = $q->param('usr');
my $pwd = $q->param('pwd');
my $session;

if($usr ne '')
{
    # process the form
    if($usr eq "demo" and $pwd eq "demo")
    {
        $session = new CGI::Session();
        print $session->header(-location=>'index.pl');
    }
    else
    {
        print $q->header(-type=>"text/html",-location=>"login.pl");
    }
}
elsif($q->param('action') eq 'logout')
{
    $session = CGI::Session->load() or die CGI::Session->errstr;
    $session->delete();
    print $session->header(-location=>'login.pl');
}
else
{
    print $q->header;
    print <<'HTML';
        <form method="post">
        Username: <input type="text" name="usr">

        Password: <input type="password" name="pwd">


        <input type="submit">
        </form>
HTML
}

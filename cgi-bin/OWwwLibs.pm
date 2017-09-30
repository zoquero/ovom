package OWwwLibs;
use strict;
use warnings;
use Carp;
use HTML::Template;

#
# Return an HTTP response showing that the session is expired
#
sub respondSessionExpired {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.expired.tmpl'); 
  $template->param(TITLE => 'Open vCenter Operations Manager (pending to set it in configuration)' ); 
  print $template->output();

# print "<html><body>\n";
# print "<p>Expired session</p>\n";
# print "<p>Please, <a href='login.pl'>login</a> again</p>";
# print "</body></html>\n";
}

#
# Return an HTTP response showing that the session has not been initiated
#
sub respondSessionNotInitiated {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.not_initiated.tmpl'); 
  $template->param(TITLE => 'Open vCenter Operations Manager (pending to set it in configuration)' ); 
  print $template->output();

# print "<html><body>\n";
# print "<p>You are not logged in</p>";
# print "<p>Please, <a href='login.pl'>login</a>.</p>";
# print "</body></html>\n";
}


#
# Return an HTTP response showing the content
#
sub respondContent {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  print "<html><body>\n";
  print "<h2>Welcome</h2>";
  print "<p><a href='login.pl?action=logout'>Logout</a></p>";
  print "</body></html>\n";
}

1;

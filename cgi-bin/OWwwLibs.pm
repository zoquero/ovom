package OWwwLibs;
use strict;
use warnings;
use Carp;
use HTML::Template;

sub getHead {
  my $appTitle = $OInventory::configuration{'app.title'};
  my $h = <<"_HEAD_END_";

<meta http-equiv="Pragma"        content="no-cache">
<meta http-equiv="Cache-Control" content="private, no-store, no-cache, must-revalidate">
<meta http-equiv="Expires"       content="0">
<meta http-equiv="Content-Type"  content="text/html; charset=utf-8">
<meta name="viewport"            content="width=device-width, initial-scale=1.0">
<title>$appTitle</title>
<link rel="stylesheet" type="text/css" href="/css/style.css"> 
_HEAD_END_
  return $h;
}

#
# Return an HTTP response showing that the session is expired
#
sub respondSessionExpired {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.expired.tmpl'); 
  $template->param(HEAD => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  print $template->output();
}

#
# Return an HTTP response showing that the session has not been initiated
#
sub respondSessionNotInitiated {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.not_initiated.tmpl'); 
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  print $template->output();
}

#
# Return an HTTP response showing the authentication form
#
sub respondAuthForm {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/auth.form.tmpl'); 
  $template->param(HEAD => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  print $template->output();
}

#
# Return an HTTP response showing the content
#
sub respondContent {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.contents.tmpl'); 
  $template->param(HEAD => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  print $template->output();
}

1;

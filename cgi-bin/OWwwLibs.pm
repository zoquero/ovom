package OWwwLibs;
use strict;
use warnings;
use Carp;
use HTML::Template;

#
# Available action ids:
#
use constant ACTION_ID_MENU_ENTRY         => 0;
use constant ACTION_ID_ON_MANAGED_OBJECT  => 1;

#
# Navigation entries tree:
#
my $neMain =
  {
    'id'      => 0,
    'display' => 'Main menu',
    'parent'  => '',
    'childs'  => [ 1, 2, 3],
    'method'  => undef,
  };
my $neInventory =
  {
    'id'      => 1,
    'display' => 'Inventory',
    'parent'  => 0,
    'childs'  => undef,
    'method'  => \&OWwwLibs::respondShowInventory
  };
my $neAlerts =
  {
    'id'      => 2,
    'display' => 'Alerts',
    'parent'  => 0,
    'childs'  => undef,
    'method'  => \&OWwwLibs::respondShowAlerts
  };
my $neAbout =
  {
    'id'      => 3,
    'display' => 'About',
    'parent'  => 0,
    'childs'  => undef,
    'method'  => \&OWwwLibs::respondShowAbout
  };

my $navEntries =
  {
    0 => $neMain,
    1 => $neInventory,
    2 => $neAlerts,
    3 => $neAbout,
  };

#
# Get the child navigation entries of an entry
#
sub getChildNavEntries {
  my $id = shift;
  my @childIds;
  if (! defined($id)) {
    return undef;
  }
  if (!defined $$navEntries{$id}) {
    return undef;
  }
  return ${$$navEntries{$id}}{'childs'};
}


#
# Get the sibiling navigation entries of an entry
#
sub getSiblingNavEntries {
  my $id = shift;
  my @siblingIds;
  if (! defined($id)) {
    return undef;
  }
  if (!defined $$navEntries{$id}) {
    return undef;
  }
  my $parentId = ${$$navEntries{$id}}{'parent'};
# print "id = $id , parentId = $parentId\n";
  foreach my $anId (keys(%$navEntries)) {
#   print "a key = $anId\n";
#   if(   ${$$navEntries{$anId}}{'parent'} eq $parentId
#      && ${$$navEntries{$anId}}{'id'}     ne $id)
    if(${$$navEntries{$anId}}{'parent'} eq $parentId) {
      push @siblingIds, $anId;
    }
  }
  return \@siblingIds;
}

#
# Get a link to a meny entry
#
sub getLinkToMenuEntry {
  my $menuEntryId = shift;

  if (!defined $$navEntries{$menuEntryId}) {
    return '';
  }
  return "<a href='?actionId=" . ACTION_ID_MENU_ENTRY . "&menuEntryId=$menuEntryId'>" . $$navEntries{$menuEntryId}{'display'} . "</a>";
}
 
#
# Show a navigation entry
#
# @arg CGI object
# @arg menu entry id
#
sub respondShowNavEntry {
  my $cgiObject = shift;
  my $id        = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $menuBody      = '';
  my $contentsBody  = '';

  if (! defined($id) || $id eq '') {
    $id = 0;
  }
  if (!defined $$navEntries{$id}) {
    triggerError($cgiObject, "respondShowNavEntry: Can't find "
                           . "the navigation entry for $id");
    return;
  }
  my $attributes = $$navEntries{$id};
  my $siblings   = getSiblingNavEntries($id);

  if($$attributes{'parent'} eq '') {
    $menuBody .= "Choose an option, please<br/>";
  }
  else {
    $menuBody .= "^ '" . getLinkToMenuEntry($$attributes{'parent'}) . "'<br/>";
  }
  if(defined($siblings) && $#$siblings > -1) {
    $menuBody .= "<ul>\n";
#   $menuBody .= "<li><b>" . $$attributes{'display'} . "</b></li>\n";
    foreach my $aSibling (sort @$siblings) {
      $menuBody .= "<b>"  if($aSibling == $id);
      $menuBody .= "<li>" . getLinkToMenuEntry($aSibling);
      if($aSibling == $id) {
        $menuBody .= "</b> &ngt;</li>\n";
      }
      else {
        $menuBody .= "</li>\n";
      }
    }
    $menuBody .= "</ul>\n";
  }
  if(defined($$attributes{'method'})
     &&  ref($$attributes{'method'}) eq 'CODE') {
    $contentsBody = $$attributes{'method'}->($cgiObject);
  }
  else {
    my $childIds = getChildNavEntries($id);
  
    if($$attributes{'parent'} ne '') {
      $contentsBody .= "up: '" . $$attributes{'parent'} . "'<br/>";
    }
    if(defined($childIds) && $#$childIds > -1) {
      $contentsBody .= "<ul>\n";
      foreach my $aChildId (@$childIds) {
        $contentsBody .= "<li>" . getLinkToMenuEntry($aChildId) . "</li>\n";
      }
      $contentsBody .= "</ul>\n";
    }

  }
  respondContent($cgiObject, $menuBody, $contentsBody);
}

#
# Show a final error message
#
sub triggerError {
  my $cgiObject    = shift;
  my $errorMessage = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  if(! defined($errorMessage) ) {
    $errorMessage = "Undefined error message";
  }

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/error.tmpl'); 
  $template->param(HEAD          => getHead() ); 
  $template->param(APP_TITLE     => $OInventory::configuration{'app.title'} ); 
  $template->param(ERROR_MESSAGE => $errorMessage); 
  $template->param(FOOTER        => getFooter() ); 
  print $template->output();
}

#
# Show the inventory
#
sub respondShowInventory {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  return "Here we'll show the inventory body using the DAO of ovom core";
}

#
# Show the alerts
#
sub respondShowAlerts {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');

  return "Here we'll show the alerts body using the DAO of ovom core and the perfData files";
}

#
# Show the 'about' entry
#
sub respondShowAbout {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $appName  = $OInventory::configuration{'app.name'};
  my $appTitle = $OInventory::configuration{'app.title'};
  my $appSite  = $OInventory::configuration{'app.site'};

  my $t = <<"_ABOUT_";

<p><b>$appTitle</b> (<b>$appName</b>) is a free software tool<br/>
to facilitate some tasks of vSphere administrators.<br/>
The software and its documentation can be found<br/>
at <a href='$appSite' target='_blank'>$appSite</a></p>
_ABOUT_
  return $t;



}

#
# Return a string with the HTML HEAD contents
#
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
# Return a string with the footer, previous to the end of the body
#
sub getFooter {
  my $appName = $OInventory::configuration{'app.name'};
  my $appSite = $OInventory::configuration{'app.site'};
  my $h = <<"_FOOTER_";
<br/>
<p class="ofooter" align="center">Powered by <a href="$appSite" target="_blank">$appName: $appSite</a></p>
_FOOTER_
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
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
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
  $template->param(FOOTER    => getFooter() ); 
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
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
  print $template->output();
}

#
# Return an HTTP response showing the content
#
sub respondContent {
  my $cgiObject        = shift;
  my $navigationCanvas = shift;
  my $contentsCanvas   = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  die "Must get a navigation canvas param" if(! defined($navigationCanvas));
  die "Must get a contents canvas param"   if(! defined($contentsCanvas));

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.contents.tmpl'); 
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
  $template->param(NAVIGATION_CANVAS => $navigationCanvas ); 
  $template->param(CONTENTS_CANVAS   => $contentsCanvas ); 
  print $template->output();
}

1;

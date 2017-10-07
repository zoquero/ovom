package OWwwLibs;
use strict;
use warnings;
use Carp;
use HTML::Template;

#
# Naming convention for the main methods:
# * respond*        : These methods return the full HTTP Response
# * getMenuFor*     : These methods return string for the left ("menu") canvas
# * getContentsFor* : These methods return string for the right ("contents") canvas
#

#
# Available action ids:
#
our $ACTION_ID_MENU_ENTRY        = 0;
our $ACTION_ID_ON_MANAGED_OBJECT = 1;

#
# Navigation entries tree:
#
my $neMain =
  {
    'id'      => 0,
    'display' => 'Main menu',
    'parent'  => '',
    'childs'  => [1, 2, 3],
    'method'  => undef,
  };
my $neInventory =
  {
    'id'      => 1,
    'display' => 'Inventory',
    'parent'  => 0,
    'childs'  => [4, 5, 6, 7, 8],
    'method'  => undef
  };
my $neAlerts =
  {
    'id'      => 2,
    'display' => 'Alerts',
    'parent'  => 0,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAlerts
  };
my $neAbout =
  {
    'id'      => 3,
    'display' => 'About',
    'parent'  => 0,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAbout
  };
my $neAllFolders =
  {
    'id'      => 4,
    'display' => 'All folders',
    'parent'  => 1,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAllFolders
  };
my $neAllDatacenters =
  {
    'id'      => 5,
    'display' => 'All datacenters',
    'parent'  => 1,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAllDatacenters
  };

my $neAllVMs =
  {
    'id'      => 6,
    'display' => 'All virtual machines',
    'parent'  => 1,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAllVirtualMachines
  };
my $neAllHosts =
  {
    'id'      => 7,
    'display' => 'All hosts',
    'parent'  => 1,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAllHosts
  };
my $neAllClusters =
  {
    'id'      => 8,
    'display' => 'All clusters',
    'parent'  => 1,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAllClusters
  };


my $navEntries =
  {
    0 => $neMain,
    1 => $neInventory,
    2 => $neAlerts,
    3 => $neAbout,
    4 => $neAllFolders,
    5 => $neAllDatacenters,
    6 => $neAllVMs,
    7 => $neAllHosts,
    8 => $neAllClusters,
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
  return "<a href='?actionId=" . $ACTION_ID_MENU_ENTRY . "&menuEntryId=$menuEntryId'>" . $$navEntries{$menuEntryId}{'display'} . "</a>";
}
 
#
# Shows a navigation entry.
# It prints full HTTP response body, not just a canvas.
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
    foreach my $aSibling (sort @$siblings) {
      $menuBody .= "<b>"  if($aSibling == $id);
      $menuBody .= "<li>" . getLinkToMenuEntry($aSibling);
      if($aSibling == $id) {
        $menuBody .= "</b> &gt;</li>\n";
      }
      else {
        $menuBody .= "</li>\n";
      }
    }
    $menuBody .= "</ul>\n";
  }
  if(defined($$attributes{'method'})
     &&  ref($$attributes{'method'}) eq 'CODE') {
    my $r = $$attributes{'method'}->($cgiObject);
    if( ${$r}{retval} ) {
      $contentsBody = ${$r}{output};
    }
    else {
      triggerError($cgiObject, "respondShowNavEntry: Errors running method for "
                             . "the navigation entry with $id");
      return;
    }
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
  $errorMessage = "Undefined error message" if(! defined($errorMessage));

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/error.tmpl'); 
  $template->param(HEAD          => getHead() ); 
  $template->param(APP_TITLE     => $OInventory::configuration{'app.title'} ); 
  $template->param(ERROR_MESSAGE => $errorMessage); 
  $template->param(FOOTER        => getFooter() ); 
  print $template->output();
}

#
# Gets the string to show the contents for "All folders"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllEntitiesOfType {
  my $cgiObject = shift;
  my $entType   = shift;
  my $retval = 0;
  my $output = '';
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  die "Must get a entType param"    if(!defined($entType) || $entType eq '');

  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    $output .= "Can't connect to DataBase. ";
    $retval  = 0;
    goto _SHOW_INVENTORY_END_;
  }

  # @arg entityType (Folder | Datacenter | ClusterComputeResource
  #                         | HostSystem | VirtualMachine | PerfCounterInfo)
  my $entities = OvomDao::getAllEntitiesOfType($entType);
  if(! defined($entities)) {
    $output .= "There were errors trying to get the list of ${entType}s. ";
    $retval  = 0;
    goto _SHOW_INVENTORY_DISCONNECT_;
  }

  _SHOW_INVENTORY_DISCONNECT_:
  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    $output .= "Cannot disconnect from DataBase. ";
    $retval  = 0;
  }

  $output .= ($#$entities + 1) . " ${entType}s:<br/>\n";
  $output .= "<ul>\n";
  foreach my $aEntity (@$entities) {
    $output .= "<li>" . getLinkToEntity($aEntity) . "</li>\n";
  }
  $output .= "</ul>\n";

  $retval  = 1;

  _SHOW_INVENTORY_END_:
  return { retval => $retval, output => $output };
}

#
# Gets the string to show the contents for "All folders"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllFolders {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  return getContentsForShowAllEntitiesOfType($cgiObject, 'Folder');
}

#
# Gets the string to show the contents for "All Datacenters"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllDatacenters {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  return getContentsForShowAllEntitiesOfType($cgiObject, 'Datacenter');
}

#
# Gets the string to show the contents for "All Hosts"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllHosts {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  return getContentsForShowAllEntitiesOfType($cgiObject, 'HostSystem');
}

#
# Gets the string to show the contents for "All VirtualMachines"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllVirtualMachines {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  return getContentsForShowAllEntitiesOfType($cgiObject, 'VirtualMachine');
}

#
# Gets the string to show the contents for "All Clusters"
#
# @param cgiObject
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAllClusters {
  my $cgiObject = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  return getContentsForShowAllEntitiesOfType($cgiObject, 'ClusterComputeResource');
}

#
# Gets the string with a link to a managed object
#
# @param reference to the managed object
# @return String with the html anchor
#
sub getLinkToEntity {
  my $mObject = shift;
  my $type    = ref($mObject);
  die "Must get an object param" if(!defined($mObject));
  return "<a href='?actionId=$ACTION_ID_ON_MANAGED_OBJECT&type=$type&mo_ref=" . $mObject->{mo_ref} . "'>" . $mObject->{name} . "</a>";
}

#
# Gets the string to show the contents for "Alerts"
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAlerts {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $retval = 1;
  my $output = "Here we'll show the alerts body using the DAO of ovom core and the perfData files";
  return { retval => $retval, output => $output };
}

#
# Gets the string to show the contents for "Alerts"
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForUnimplemented {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $output = "This feature is still not implemented.";
  my $retval = 1;
  return { retval => $retval, output => $output };
}

#
# Gets the string to show the contents for "About" menu entry
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAbout {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $appName  = $OInventory::configuration{'app.name'};
  my $appTitle = $OInventory::configuration{'app.title'};
  my $appSite  = $OInventory::configuration{'app.site'};
  my $retval = 1;
  my $t = <<"_ABOUT_";

<p><b>$appTitle</b> (<b>$appName</b>) is a free software tool<br/>
to facilitate some tasks of vSphere administrators.<br/>
The software and its documentation can be found<br/>
at <a href='$appSite' target='_blank'>$appSite</a></p>
_ABOUT_

  return { retval => $retval, output => $t };
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
# Return an HTTP response showing that the session is expired.
# It prints full HTTP response body, not just a canvas.
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
# Return an HTTP response showing that the session has not been initiated.
# It prints full HTTP response body, not just a canvas.
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
# Return an HTTP response showing the authentication form.
# It prints full HTTP response body, not just a canvas.
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
# based on a the template with a table.
# It prints full HTTP response body, not just a canvas.
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

#
# Gets the string to show the contents for an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'   : entity type
#      * 'mo_ref' : entity's mo_ref
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForEntity {
  my $cgiObject  = shift;
  die "Must get a CGI object param"   if(ref($cgiObject) ne 'CGI');
  my $args       = shift;
  die "Must get an args object param"
    if(ref($args) ne 'HASH'
       || !defined($args->{'type'})
       || !defined($args->{'mo_ref'}));
  my $type   = $args->{'type'};
  my $mo_ref = $args->{'mo_ref'};

  my $retval;
  my $output;
  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    $output = "Can't connect to DataBase. ";
    $retval = 0;
    goto _SHOW_ENTITIES_END_;
  }

  #
  # Let's load the entity from our inventory DB
  #
# @arg entity type (  Folder | Datacenter | ClusterComputeResource
#                   | HostSystem | VirtualMachine | PerfCounterInfo | PerfMetric)
  my $oEntityName = OvomDao::objectName2EntityName($type);
  if(! defined($oEntityName) || $oEntityName eq '') {
      $output = "Can't get the entity name for the object name $type";
      $retval = 0;
      goto _SHOW_ENTITIES_DISCONNECT_;
  }
  my $entity     = OvomDao::loadEntity($mo_ref, $oEntityName);
  if (! defined($entity)) {
      $output = "Can't find the $type $mo_ref in the Inventory DB. ";
      $retval = 0;
      goto _SHOW_ENTITIES_DISCONNECT_;
  }

  $output = "<h2>$oEntityName: " . $entity->{name} . "</h2>\n";
  $output .= "<h3>Description</h3>\n";
  $output .= "<p>$oEntityName with mo_ref=$mo_ref</p>\n";
  if($type eq 'OFolder') {
    my $entities = OvomDao::getChildEntitiesOfFolder($mo_ref);
    if(! defined($entities)) {
      $output = "There were errors trying to get the list of entities. ";
      $retval = 0;
      goto _SHOW_ENTITIES_DISCONNECT_;
    }
    #
    # Sub-folders
    #
    $retval  = 1;
    $output .= "<h3>Related entities</h3>\n";
    $output .= "<h4>Sub-Folders</h4>\n";
    if($#{$entities->{Folder}} > -1) {
      $output .= "<ul>";
      foreach my $aFolder (@{$entities->{Folder}}) {
        $output .= "<li>" . getLinkToEntity($aFolder) . "</li>\n";
      }
      $output .= "</ul>";
    }
    else {
      $output .= "None";
    }

    #
    # Contained VirtualMachines
    #
    $output  .= "<h4>VirtualMachines</h4>\n";
    if($#{$entities->{VirtualMachine}} > -1) {
      $output .= "<ul>";
      foreach my $aFolder (@{$entities->{VirtualMachine}}) {
        $output .= "<li>" . getLinkToEntity($aFolder) . "</li>\n";
      }
      $output .= "</ul>";
    }
    else {
      $output .= "None";
    }
  }
  else {
    $retval = 0;
    $output = "<p>Now it's just implemented showing Folders ($type). Job to do...</p>";
  }

  _SHOW_ENTITIES_DISCONNECT_:
  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    $output .= "Cannot disconnect from DataBase. ";
    $retval  = 0;
  }
  _SHOW_ENTITIES_END_:
  return { retval => $retval, output => $output };
}

#
# Gets the string to show the left menu for an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'  : entity type
#      * 'mo_ref' : entity's mo_ref
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getMenuForEntity {
  my $cgiObject  = shift;
  die "Must get a CGI object param"   if(ref($cgiObject) ne 'CGI');
  my $args       = shift;
  die "Must get an args object param"
    if(ref($args) ne 'HASH'
       || !defined($args->{'type'})
       || !defined($args->{'mo_ref'}));
  my $type   = $args->{'type'};
  my $mo_ref = $args->{'mo_ref'};

  my $retval = 1;
  my $output = <<"_ENTITY_CONTENTS_";

<p>Here we'll show the menu for the entity of type $type and mo_ref $mo_ref</p>
_ENTITY_CONTENTS_

  return { retval => $retval, output => $output };
}

#
# Return an HTTP response showing the contents for an Entity
# It prints full HTTP response body, not just a canvas.
#
sub respondShowEntity {
  my $cgiObject = shift;
  my $type      = shift;
  my $mo_ref     = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  die "Must get a type param"       if(! defined($type));
  die "Must get a mo_ref param"      if(! defined($mo_ref));
  my $menuCanvasRet     = "menu per type $type i mo_ref $mo_ref";
  my $contentsCanvasRet = getContentsForEntity($cgiObject, { type => $type, mo_ref => $mo_ref });

  if(! $contentsCanvasRet->{retval}) {
    triggerError($cgiObject, "Errors getting the entity: "
                           . $contentsCanvasRet->{output});
    return;
  }

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.contents.tmpl'); 
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
  $template->param(NAVIGATION_CANVAS => $menuCanvasRet ); 
  $template->param(CONTENTS_CANVAS   => $contentsCanvasRet->{output} ); 
  print $template->output();
}

1;

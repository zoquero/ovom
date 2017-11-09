package OWwwLibs;
use strict;
use warnings;
use Carp;
use HTML::Template;
use Data::Dumper;
use Time::Local;
# Our modules:
use OPerformance;

#
# Naming convention for the main methods:
# * respond*        : These methods return the full HTTP Response
# * getMenuFor*     : These methods return string for the left ("menu") canvas
# * getContentsFor* : These methods return string for the right ("contents") canvas
#

#
# Available action ids:
#
our $ACTION_ID_MENU_ENTRY                       = 0;
our $ACTION_ID_ON_MANAGED_OBJECT                = 1;
our $ACTION_ID_ON_PERFORMANCE_OF_MANAGED_OBJECT = 2;
our $ACTION_ID_SEARCH_FOR_ALARMS                = 3;
our $ACTION_ID_SHOW_THRESHOLDS                  = 4;

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
my $neMonitoring =
  {
    'id'      => 2,
    'display' => 'Monitoring',
    'parent'  => 0,
    'childs'  => [9, 10, 11],
    'method'  => undef
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
my $neAllActiveAlarms =
  {
    'id'      => 9,
    'display' => 'Alarms',
    'parent'  => 2,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForAlarms
  };
my $neThresholds =
  {
    'id'      => 10,
    'display' => 'Thresholds',
    'parent'  => 2,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowThresholds
  };
my $neAboutMonitoring =
  {
    'id'      => 11,
    'display' => 'About monitoring',
    'parent'  => 2,
    'childs'  => undef,
    'method'  => \&OWwwLibs::getContentsForShowAboutMonitoring
  };


my $navEntries =
  {
    0 => $neMain,
    1 => $neInventory,
    2 => $neMonitoring,
    3 => $neAbout,
    4 => $neAllFolders,
    5 => $neAllDatacenters,
    6 => $neAllVMs,
    7 => $neAllHosts,
    8 => $neAllClusters,
    9 => $neAllActiveAlarms,
   10 => $neThresholds,
   11 => $neAboutMonitoring,
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
    die "Menu entry not defined for $menuEntryId"
  }
  return "<a href='?actionId=" . $ACTION_ID_MENU_ENTRY . "&menuEntryId=$menuEntryId'>" . $$navEntries{$menuEntryId}{'display'} . "</a>";
}

sub getNavMenuBody {
  my $attributes = shift;
  my $id         = shift;
  my $menuBody;
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
  $menuBody = getNavMenuBody($attributes, $id);

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
  
#   if($$attributes{'parent'} ne '') {
#     $contentsBody .= "up: '" . $$attributes{'parent'} . "'<br/>";
#   }
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
  if(ref($mObject) eq 'OAlarm') {
    return "<b>Pending</b> to manage it in OWwwLibs::getLinkToEntity" . $mObject;
  }
  else {
    return "<a href='?actionId=$ACTION_ID_ON_MANAGED_OBJECT&type=$type&mo_ref=" . $mObject->{mo_ref} . "'>" . $mObject->{name} . "</a>";
  }
}

#
# Gets the string with a link to latest performance graphs of a managed object
#
# @param reference to the managed object
# @return String with the html anchor
#
sub getLinkToLatestPerformanceGraphs {
  my $type   = shift;
  my $mo_ref = shift;
  die "Must get a type param"   if(!defined($type));
  die "Must get a mo_ref param" if(!defined($mo_ref));
  die "Empty type param"        if($type eq '');
  die "Empty mo_ref param"      if($mo_ref eq '');
  return "<a href='?actionId=$ACTION_ID_ON_PERFORMANCE_OF_MANAGED_OBJECT&type=$type&mo_ref=$mo_ref'>Latest performance</a>";
}

#
# Gets the HTML for a select tag with numerical options
#
# @param name of the form input
# @param min val
# @param max val
# @return String with the html 
#
sub getHtmlFormSelectNumerical {
  my $name = shift;
  my $min  = shift;
  my $max  = shift;
  my $sel  = shift;
  die "getHtmlFormSelectNumerical: missing name"
    if(!defined($name) || $name eq '');
  die "getHtmlFormSelectNumerical: missing min"      if(!defined($min));
  die "getHtmlFormSelectNumerical: missing max"      if(!defined($max));
  die "getHtmlFormSelectNumerical: missing selected" if(!defined($sel));

  my $t = "<select name=\"$name\">\n";
  my $selected;
  for (my $i = $min; $i <= $max; $i++) {
    if ($i == $sel) {
      $selected = "selected";
    }
    else {
      $selected = "";
    }
    $t .= "<option value=\"$i\" $selected>$i</option>\n";
  }
  $t .= "</select>\n";
  return $t;
}

#
# Gets the HTML for the form to ask for custom interval performance graphs
#
# @param type of entity, used in OvomDao to look for it
# @param entity's mo_ref
# @return String with the html form
#
sub getFormForCustomPerfGraphsInterval {
  my $type   = shift;
  my $mo_ref = shift;
  die "Must get a type param"   if(!defined($type));
  die "Must get a mo_ref param" if(!defined($mo_ref));
  die "Empty type param"        if($type eq '');
  die "Empty mo_ref param"      if($mo_ref eq '');

  my $now = time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now-3600);
  my $currYear = $year + 1900;
  my $fromYear   = getHtmlFormSelectNumerical('fromYear',  2016, $currYear, $currYear);
  my $fromMonth  = getHtmlFormSelectNumerical('fromMonth',    1, 12, $mon+1);
  my $fromDay    = getHtmlFormSelectNumerical('fromDay',      1, 31, $mday);
  my $fromHour   = getHtmlFormSelectNumerical('fromHour',     0, 23, $hour);
  my $fromMinute = getHtmlFormSelectNumerical('fromMinute',   0, 59, $min);

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
  $currYear = $year + 1900;
  my $toYear   = getHtmlFormSelectNumerical('toYear',  2016, $currYear, $currYear);
  my $toMonth  = getHtmlFormSelectNumerical('toMonth',    1, 12, $mon+1);
  my $toDay    = getHtmlFormSelectNumerical('toDay',      1, 31, $mday);
  my $toHour   = getHtmlFormSelectNumerical('toHour',     0, 23, $hour);
  my $toMinute = getHtmlFormSelectNumerical('toMinute',   0, 59, $min);

  my $t = <<"_FFCPGI_";

<form action="?" method="post" accept-charset="utf-8">
  <input type="hidden" name="actionId" value="$ACTION_ID_ON_PERFORMANCE_OF_MANAGED_OBJECT"/>
  <input type="hidden" name="type"     value="$type"/>
  <input type="hidden" name="mo_ref"   value="$mo_ref"/>
_FFCPGI_

  $t .= <<"_FFCPGI2_";
<table border="1">
  <tr align="center">
    <td>&nbsp;</td>
    <td>Year</td>
    <td>Month</td>
    <td>Day</td>
    <td>Hour</td>
    <td>Minute</td>
  </tr>

  <tr>
    <td valign="middle">From:</td>
    <td>$fromYear</td>
    <td>$fromMonth</td>
    <td>$fromDay</td>
    <td>$fromHour</td>
    <td>$fromMinute</td>
  </tr>

  <tr>
    <td valign="middle">To: 
    <td>$toYear</td>
    <td>$toMonth</td>
    <td>$toDay</td>
    <td>$toHour</td>
    <td>$toMinute</td>
  </tr>
  <tr>
  <td colspan=6 align="center">
    <input type="submit" name="Get perf" value="Get perf" />
  </td>
  </tr>
</table>
</form>
_FFCPGI2_

  return $t;
}

#
# Gets the string to show the contents for "Alarms"
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForAlarms {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $retval = 1;
  my $groupInfoKeys;
  my $output;

  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    OInventory::log(3, "Can't connect to DataBase.");
    goto _GROUPINFO_KEYS_SEARCHED_;
  }

  $groupInfoKeys = OvomDao::getAllGroupInfoKeys();
  if(! defined($groupInfoKeys)) {
    OInventory::log(3, "There were errors trying to get the list of groupInfo keys.");
  }

  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    OInventory::log(3, "Cannot disconnect from DataBase.");
  }
  _GROUPINFO_KEYS_SEARCHED_:

  my $groupInfoCheckboxesHtml = '';
  foreach my $aGIKey (@$groupInfoKeys) {
    $groupInfoCheckboxesHtml .= "<input type='checkbox' name='groupInfoKey' value='$aGIKey' checked>$aGIKey</input>\n";
  }

  $output = <<"_ALARMS_SEARCH_FORM_";

<h2>Alarms</h2>
  <h3> Alarm reporting </h3>
    <p> Here you can search for alarms based on criteria: </p>

    <form action="?" method="post" accept-charset="utf-8">
      <input type="hidden" name="actionId" value="$ACTION_ID_SEARCH_FOR_ALARMS"/>

      <table border="1">
        <tr align="center">
          <th valign="middle">Active</th>
          <td>
            <select name="is_active" id="is_active"> 
              <option value="2"         >All</option> 
              <option value="1" selected>Just active alerts</option> 
              <option value="0"         >Just inactive alerts</option> 
            </select>
          </td>
        </tr>
      
        <tr>
          <th valign="middle">Created after of<br/>(date in <em>epoch</em>)</th>
          <td>
            Just alerts created after.<br/>
            You can leave it blank.
            <input type="text" name="alarm_time_lower" width="10" size="10"/>
          </td>
        </tr>

         <tr>
          <th valign="middle">Created before of<br/>(date in <em>epoch</em>)</th>
          <td>
            Just alerts created before.<br/>
            You can leave it blank.
            <input type="text" name="alarm_time_upper" width="10" size="10"/>
          </td>
        </tr>

        <tr>
          <th>&nbsp;</th>
          <td align="center">
            Tip: You can generate epoch timestamps with this command:<br/>
            <em>`date --date "\${Y}\${M}\${D} \${H}\${m}" +%s`</em>
          </td>
        </tr>
 
        <tr>
          <th valign="middle">GroupInfo</th>
          <td>
            $groupInfoCheckboxesHtml
          </td>
        </tr>
      
        <tr>
          <th valign="middle">Entity's mo_ref</th>
          <td>
            <input type="text" name="mo_ref" width="10" size="10"/> <br/>
            Leave it blank to search for alarms on all entities
          </td>
        </tr>
      
        <tr>
          <th valign="middle">Criticality</th>
          <td>
            <select name="is_critical" id="is_critical"> 
              <option value="2"         >Any</option> 
              <option value="1" selected>Just critical alerts</option> 
              <option value="0"         >Just warning  alerts</option> 
            </select>
          </td>
        </tr>
      
        <tr>
          <th valign="middle">Acknowledgement</th>
          <td>
            <select name="is_acknowledged" id="is_acknowledged"> 
              <option value="2"         >Any</option> 
              <option value="1"         >Just acknowledged alerts</option> 
              <option value="0" selected>Just non-acknowledged alerts</option> 
            </select>
          </td>
        </tr>

        <tr>
          <td colspan=2 align="center">
            <input type="submit" name="Search" value="Search" />
          </td>
        </tr>
      </table>
    </form>

_ALARMS_SEARCH_FORM_

  return { retval => $retval, output => $output };
}

#
# Gets the string to show the contents for "Alarms"
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
# Gets the string to show the contents for "About Monitoring" menu entry
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowAboutMonitoring {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $appName  = $OInventory::configuration{'app.name'};
  my $appTitle = $OInventory::configuration{'app.title'};
  my $appSite  = $OInventory::configuration{'app.site'};
  my $retval = 1;
  my $output = <<"_ALARMS_ABOUT_";

<h2>Alarms</h2>
  <h3> About thresholds and alarms </h3>
    <p>You can specify <b>generic warning and critical thresholds</b> for each <b>performance counter</b> (<em>PerfCounterInfo</em> objects). Those thresholds will be the same for all its instances in all the entities of your infraestructure. You can also specify <b>concrete thresholds for each instance</b> of those counters of your entities (<em>PerfMetricId</em> objects).</p>
    <p> Both kinds of thresholds (generic and concrete) can be specified the first time that a <em>PerfCounterInfo</em> or <em>PerfMetricId</em> object is loaded in the file <em><b>thresholds/PerfMetricId.thresholds.csv</b></em>. After that you'll be able to change those thresholds on database through this web interface. </p>
    <p> When a perfData (value of a counter) exceeds a generic or a concrete threshold an <b>active alarm</b> is launched. This alarm can be <em>warning</em> o <em>critical</em>. On the next iterations of picker's loop the new perfData will be compared again agains those thresholds, but just will be compared the perfData after the last data collected for that <em>PerfMetricId</em>. After each loop the state of the alarm is re-evaluated. When there's no critical or warning value in a complete loop then that alarm is <b>deactivated</b> (<em>active=false</em>). An active alarm can be <b>acknowledged</b> so that it will not appear in alarm reports that just show non-acknowledged active alarms. </p>

_ALARMS_ABOUT_

  return { retval => $retval, output => $output };
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
  my $snippetRet;
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
  my $oEntityName = OvomDao::oClassName2EntityName($type);
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

  if($type eq 'OFolder') {
    $snippetRet = getContentsSnippetForFolder($cgiObject, { type => $type, mo_ref => $mo_ref, entity => $entity, oEntityName => $oEntityName });
  }
  elsif($type eq 'OVirtualMachine') {
    $snippetRet = getContentsSnippetForVirtualMachine($cgiObject, { type => $type, mo_ref => $mo_ref, entity => $entity, oEntityName => $oEntityName });
  }
  else {
    $retval = 0;
    $output = "<p>We still haven't implemented showing $type</p>";
    goto _SHOW_ENTITIES_DISCONNECT_;
  }

  if(! $snippetRet->{retval}) {
    $output = "There were errors trying to get the contents for the $type: " . $snippetRet->{output};
    $retval = 0;
    goto _SHOW_ENTITIES_DISCONNECT_;
  }
  else {
    $output = $snippetRet->{output};
    $retval = 1;
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
# Gets the string to show the contents for latest performance of an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'   : entity type
#      * 'mo_ref' : entity's mo_ref
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForPerformance {
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
  my $snippetRet;
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
  my $oEntityName = OvomDao::oClassName2EntityName($type);
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

  #
  # Let's load the PerfMetricIds from our inventory DB
  #
  my $perfMetricIds = OvomDao::loadPerfMetricIdsForEntity($mo_ref);
  if(!defined($perfMetricIds)) {
    $output = "Could not get PerfMetricIds for $mo_ref";
    $retval = 0;
    goto _SHOW_ENTITIES_DISCONNECT_;
  }
  #
  # Let's load the OPerfCounterInfo from our inventory DB
  #
  my %perfCounterInfos;
  foreach my $aPMI (@$perfMetricIds) {
    my $aPCI     = OvomDao::loadEntity($aPMI->counterId, 'PerfCounterInfo');
    if (! defined($aPCI)) {
        $output = "Can't get the PerfCounterInfo for the PerfMetric with id "
                 . $aPMI->counterId . " in the Inventory DB. ";
        $retval = 0;
        goto _SHOW_ENTITIES_DISCONNECT_;
    }
    $perfCounterInfos{$aPMI->counterId} = $aPCI;
  }

  $args->{entity}           = $entity;
  $args->{oEntityName}      = $oEntityName;
  $args->{perfMetricIds}    = $perfMetricIds;
  $args->{perfCounterInfos} = \%perfCounterInfos;
  $snippetRet = getContentsSnippetForPerformance($cgiObject, $args);
  if(! $snippetRet->{retval}) {
    $output = "There were errors trying to get the performance for the $type: " . $snippetRet->{output};
    $retval = 0;
    goto _SHOW_ENTITIES_DISCONNECT_;
  }
  else {
    $output = $snippetRet->{output};
    $retval = 1;
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
# Gets the string to show the snippet of contents for an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'        : entity type      (repetitive ...)
#      * 'mo_ref'      : entity's mo_ref  (repetitive ...)
#      * 'entity'      : entity
#      * 'oEntityName' : Classname of its ovom class
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsSnippetForFolder {
  my $cgiObject  = shift;
  die "Must get a CGI object param"   if(ref($cgiObject) ne 'CGI');
  my $args       = shift;
  my $retval;
  my $output;

  if(ref($args) ne 'HASH') {
    return { retval => 0, output => "Missing args hash param." };
  }
  if(   !defined($args->{'type'})
     || !defined($args->{'mo_ref'})
     || !defined($args->{'entity'})
     || !defined($args->{'oEntityName'})) {
    return { retval => 0, output => "Some keys are missing in hash arg" };
  }

  my $type        = $args->{'type'};
  my $mo_ref      = $args->{'mo_ref'};
  my $entity      = $args->{'entity'};
  my $oEntityName = $args->{'oEntityName'};

  if (! defined($type) || $type eq '') {
    return { retval => 0, output => "Missing type arg." };
  }
  if ($type ne 'OFolder') {
    return { retval => 0, output => "This method is just for OFolder." };
  }
  if (! defined($mo_ref) || $mo_ref eq '') {
    return { retval => 0, output => "Missing mo_ref arg." };
  }
  if (! defined($oEntityName) || $oEntityName eq '') {
    return { retval => 0, output => "Missing oEntityName arg." };
  }
  if (! defined($entity)) {
    return { retval => 0, output => "Missing $type arg." };
  }

  my $entities = OvomDao::getChildEntitiesOfFolder($mo_ref);
  if(! defined($entities)) {
    $output = "There were errors trying to get the list of entities. ";
    $retval = 0;
    # We'll disconnect from DB in the caller
    return { retval => $retval, output => $output };
  }

  #
  # Summary
  #
  $output = "<h2>$oEntityName: " . $entity->{name} . "</h2>\n";
  $output .= "<h3>Description</h3>\n";
  $output .= "<p>$oEntityName with mo_ref='<b><em>$mo_ref</em></b>'</p>\n";
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

  return { retval => $retval, output => $output };
}

sub time2str {
  my $Y = shift;
  my $M = shift;
  my $D = shift;
  my $h = shift;
  my $m = shift;
  my $s = shift;
  return sprintf("%04d/%02d/%02d %02d:%02d:%02d", $Y, $M, $D, $h, $m, $s);
}

#
# Gets the string to show the snippet of contents for performance for an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'        : entity type      (repetitive ...)
#      * 'mo_ref'      : entity's mo_ref  (repetitive ...)
#      * 'entity'      : entity
#      * 'oEntityName' : Classname of its ovom class
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsSnippetForPerformance {
  my $cgiObject  = shift;
  die "Must get a CGI object param"   if(ref($cgiObject) ne 'CGI');
  my $args       = shift;
  my $retval;
  my $output;

  if(ref($args) ne 'HASH') {
    return { retval => 0, output => "Missing args hash param." };
  }
  if(   !defined($args->{'type'})
     || !defined($args->{'mo_ref'})
     || !defined($args->{'entity'})
     || !defined($args->{'oEntityName'})
     || !defined($args->{'perfMetricIds'})
     || !defined($args->{'perfCounterInfos'})) {
    return { retval => 0, output => "Some keys are missing in hash arg" };
  }

  my $type             = $args->{'type'};
  my $mo_ref           = $args->{'mo_ref'};
  my $entity           = $args->{'entity'};
  my $oEntityName      = $args->{'oEntityName'};
  my $perfMetricIds    = $args->{'perfMetricIds'};
  my $perfCounterInfos = $args->{'perfCounterInfos'};

  if (! defined($type) || $type eq '') {
    return { retval => 0, output => "Missing type arg." };
  }
  if (! defined($mo_ref) || $mo_ref eq '') {
    return { retval => 0, output => "Missing mo_ref arg." };
  }
  if (! defined($oEntityName) || $oEntityName eq '') {
    return { retval => 0, output => "Missing oEntityName arg." };
  }
  if (! defined($entity)) {
    return { retval => 0, output => "Missing entity arg." };
  }
  if (! defined($perfMetricIds)) {
    return { retval => 0, output => "Missing perfMetricIds arg." };
  }
  if (! defined($perfCounterInfos)) {
    return { retval => 0, output => "Missing perfCounterInfos arg." };
  }
  if ($#$perfMetricIds < 0) {
    return { retval => 0, output => "There are no perfMetricIds for $oEntityName " . $entity->{name} };
  }

  #
  # Month conversion:
  # * $args->{fromMonth} comes from webUI and belongs to [1..12]
  # * 5th parameter ("month") in Time::Loca::timelocal and belongs to [0..11]
  #
  my $fromEpoch = timelocal(0, $args->{fromMinute}, $args->{fromHour},  $args->{fromDay}, $args->{fromMonth} - 1, $args->{fromYear});
  my $toEpoch   = timelocal(0, $args->{toMinute},   $args->{toHour},    $args->{toDay},   $args->{toMonth} - 1,   $args->{toYear});
  my $fromStr   = time2str(    $args->{fromYear},   $args->{fromMonth}, $args->{fromDay}, $args->{fromHour},      $args->{fromMinute}, 0);
  my $toStr     = time2str(    $args->{toYear},     $args->{toMonth},   $args->{toDay},   $args->{toHour},        $args->{toMinute},   0);



  my $entityName = OvomDao::oClassName2EntityName($type);
  my $basenameSeparator = $OInventory::configuration{'perfpicker.basenameSep'};

  #
  # Folder for performance data
  #
  my $folder = $OInventory::configuration{'perfdata.root'}
             . "/"
             . $OInventory::configuration{'vCenter.fqdn'}
             . "/"
             . $entityName
             . "/"
             . $mo_ref;

  #
  # Let's load stage descriptors
  #
  my $sd = OPerformance::getStageDescriptors();
  if( ! defined ($sd) ) {
    OInventory::log(3, "Calling OPerformance::getStageDescriptors "
      . " from getContentsSnippetForPerformance returned errors");
    return { retval => 0, output => "Can't get the stage descriptors" };
  }

  my %countersByGroupId;
  foreach my $aPMI (@$perfMetricIds) {
    if(! defined($perfCounterInfos->{$aPMI->counterId})) {
      die "PerfCounterInfo not found for counterId=" . $aPMI->counterId;
    }
    my $pCI = $perfCounterInfos->{$aPMI->counterId};
    push @{$countersByGroupId{$pCI->groupInfo->key}}, $aPMI;
  }

  my $perfGraphs = '';
  my $contentsIndex  = "<p>Index of graphs:</p>\n";
  $contentsIndex .= "<ul>\n";
  foreach my $aGroupInfoKey (sort keys %countersByGroupId) {
    $perfGraphs    .= "<h4><a id=\"gik_$aGroupInfoKey\">$aGroupInfoKey group</a></h4>\n";
    $contentsIndex .= "<li><a href=\"#gik_$aGroupInfoKey\">$aGroupInfoKey</a></li>\n";
    $contentsIndex .= "<ul>\n";
    foreach my $pmi (@{$countersByGroupId{$aGroupInfoKey}}) {
      my $prefix = $args->{'mo_ref'} . $basenameSeparator . $pmi->counterId . $basenameSeparator . $pmi->instance;
      my @filenames;
      foreach my $aSD (@$sd) {
        my $filename = $folder . "/" . $prefix . "." . $aSD->{name} . ".csv";
        push @filenames, $filename;
      }
      OInventory::log(0, "Calling getOneCsvFromAllStages to generate a graph "
                       . "from $fromEpoch to $toEpoch with prefix $prefix");
      my $resultingCsvFile = OPerformance::getOneCsvFromAllStages($fromEpoch, $toEpoch, $prefix, \@filenames);
      if (! defined($resultingCsvFile)) {
        OInventory::log(3, "getOneCsvFromAllStages returned with errors");
        return { retval => 0, output => "Can't get the single csv for all stages. Is there data in that interval?" };
      }
      my $pCI = $perfCounterInfos->{$pmi->counterId};
      my $description = getGraphDescription($type, $entityName, $mo_ref, $pCI);
      my $g = OPerformance::csv2graph($fromEpoch, $toEpoch, $resultingCsvFile);
      if (! defined($g)) {
        OInventory::log(3, "Could not generate graphs");
        return { retval => 0, output => "Can't generate the graphs" };
      }

      my $gu = graphPath2uriPath($g);
      my $instanceStr;
      if($pmi->instance eq '') {
        $instanceStr = '';
      }
      else {
        $instanceStr = ", instance '" . $pmi->instance . "'";
      }
      $perfGraphs .= "<h5><a id=\"pci_" . $pmi->counterId . "_" . $pmi->instance . "\">" . $pCI->getShortDescription() . "$instanceStr</a></h5>\n";
      $perfGraphs .= "<p>" . $pCI->{_nameInfo}->{_summary} . "</p>\n";
      $perfGraphs .= "<p><img src=\"$gu\" alt=\"$description\" border='1'/></p><hr/>\n";
      $contentsIndex .= "<li><a href=\"#pci_" . $pmi->counterId . "_" . $pmi->instance . "\">" . $pCI->getShortDescription() . "$instanceStr</a></li>\n";
    }
    $contentsIndex .= "</ul>\n";
  }
  $contentsIndex .= "</ul>\n";

  $output = <<"_PERFORMANCE_HEADERS_";
<h2>Performance for $oEntityName $entity->{name}</h2>
<h3>Description</h3>
<p>$oEntityName with name <b><em>$entity->{name}</em></b> and mo_ref='<b><em>$mo_ref</em></b>'</p>
<p style="font-family:Courier New;">Interval choosen for graphs:<br/>
* from&nbsp;Y/M/D H:M:S $fromStr ($fromEpoch in <em>epoch</em>)<br/>
* to&nbsp;&nbsp;&nbsp;Y/M/D H:M:S $toStr ($toEpoch in <em>epoch</em>) </p>

<h3>Graphs</h3>
$contentsIndex
$perfGraphs
_PERFORMANCE_HEADERS_




  $retval = 1;
  return { retval => $retval, output => $output };
}

sub graphPath2uriPath {
  my $p = shift;
  return undef if (!defined($p));

  my $graphFolderUrl = $OInventory::configuration{'web.graphs.folder'};
  my $uriPath        = $OInventory::configuration{'web.graphs.uri_path'};

  substr($p, 0, length($graphFolderUrl), $uriPath);
  return $p;
}

sub getGraphDescription {
  my $type       = shift;
  my $entityName = shift;
  my $mo_ref     = shift;
  my $pCI = shift;

  return undef if(!defined $type || $type eq '');
  return undef if(!defined $entityName || $entityName eq '');
  return undef if(!defined $mo_ref || $mo_ref eq '');
  return undef if(!defined $pCI);
  return undef if(ref($pCI) eq 'OPerfCounterInfo');

  return "$type $entityName ($mo_ref): $pCI";
}

#
# Gets the string to show the snippet of contents for an entity
#
# @arg cgiObject
# @arg Reference to hash of arguments with keys:
#      * 'type'   : entity type
#      * 'mo_ref' : entity's mo_ref
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsSnippetForVirtualMachine {
  my $cgiObject  = shift;
  die "Must get a CGI object param"   if(ref($cgiObject) ne 'CGI');
  my $args       = shift;
  die "Must get an args object param"
    if(ref($args) ne 'HASH'
       || !defined($args->{'type'})
       || !defined($args->{'mo_ref'}));
  my $retval;
  my $output;
  my $type        = $args->{'type'};
  my $mo_ref      = $args->{'mo_ref'};
  my $entity      = $args->{'entity'};
  my $oEntityName = $args->{'oEntityName'};

  if (! defined($type) || $type eq '') {
      $output = "Missing type arg.";
      $retval = 0;
      return { retval => $retval, output => $output };
  }
  if ($type ne 'OVirtualMachine') {
      $output = "This method is just for OVirtualMachine.";
      $retval = 0;
      return { retval => $retval, output => $output };
  }
  if (! defined($mo_ref)) {
      $output = "Missing mo_ref arg.";
      $retval = 0;
      return { retval => $retval, output => $output };
  }
  if (! defined($oEntityName)) {
      $output = "Missing oEntityName arg.";
      $retval = 0;
      return { retval => $retval, output => $output };
  }
  if (! defined($entity)) {
      $output = "Missing $type arg.";
      $retval = 0;
      return { retval => $retval, output => $output };
  }

  my $latestPerfLink       = getLinkToLatestPerformanceGraphs($type, $mo_ref);
  my $custIntervalPerfForm = getFormForCustomPerfGraphsInterval($type, $mo_ref);
  $retval = 1;
  $output = <<"_ENTITY_CONTENTS_";
<h2>$oEntityName: $entity->{name}</h2>
<h3>Description</h3>
<p>$oEntityName with mo_ref='<b><em>$mo_ref</em></b>'</p>
<h3>Related entities</h3>
<p>Still in development.</p>
<h3>Performance</h3>
<p>Get $latestPerfLink.</p>
<p>Or get it on a custom interval:</p>
<p>$custIntervalPerfForm</p>
_ENTITY_CONTENTS_

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

sub getNavEntryIdForType {
  my $type = shift;
  my $id;
  if($type    eq 'OFolder') {
    $id = 4;
  }
  elsif($type eq 'ODatacenter') {
    $id = 5;
  }
  elsif($type eq 'OVirtualMachine') {
    $id = 6;
  }
  elsif($type eq 'OHost') {
    $id = 7;
  }
  elsif($type eq 'OCluster') {
    $id = 8;
  }
  elsif($type eq 'OAlarm') {
    $id = 9;
  }
  else {
    $id = 1;
  }
  return $id;
}

#
# Return an HTTP response showing the contents for an Entity
# It prints full HTTP response body, not just a canvas.
#
sub respondShowEntity {
  my $cgiObject = shift;
  my $type      = shift;
  my $mo_ref    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  die "Must get a type param"       if(! defined($type));
  die "Must get a mo_ref param"     if(! defined($mo_ref));

  my $id = getNavEntryIdForType($type);
  if (!defined $$navEntries{$id}) {
    die "respondShowEntity: Can't find the navigation entry for $id";
  }
  my $attributes = $$navEntries{$id};
  my $menuCanvasRet = getNavMenuBody($attributes, $id);

  my $contentsCanvasRet
     = getContentsForEntity($cgiObject, { type => $type, mo_ref => $mo_ref });

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

#
# Return an HTTP response showing the contents for an Entity
# It prints full HTTP response body, not just a canvas.
#
sub respondShowPerformance {
  my $cgiObject  = shift;
  my $args       = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  die "Must get args param"         if(!defined($args) || ref($args) ne 'HASH');

  foreach my $key ( ( "type", "mo_ref" ) ) {
    if(!defined($args->{$key})) {
      die "Missing arg key $key";
    }
  }
  if(!defined($args->{fromYear}) || $args->{fromYear} eq '') {
    my $now = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now-3600);
    my $currYear = $year + 1900;
    $args->{fromYear}   = $currYear;
    $args->{fromMonth}  = $mon+1;
    $args->{fromDay}    = $mday;
    $args->{fromHour}   = $hour;
    $args->{fromMinute} = $min;

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
    $currYear = $year + 1900;
    $args->{toYear}   = $currYear;
    $args->{toMonth}  = $mon+1;
    $args->{toDay}    = $mday;
    $args->{toHour}   = $hour;
    $args->{toMinute} = $min;
  }

  my $type   = $args->{type};
  my $mo_ref = $args->{mo_ref};
  die "empty type param"   if($type   eq '');
  die "empty mo_ref param" if($mo_ref eq '');


  my $id = getNavEntryIdForType($type);
  if (!defined $$navEntries{$id}) {
    die "respondShowPerformance: Can't find the navigation entry for $id";
  }
  my $attributes = $$navEntries{$id};
  my $menuCanvasRet = getNavMenuBody($attributes, $id);

  my $contentsCanvasRet
     = getContentsForPerformance($cgiObject, $args);

  if(! $contentsCanvasRet->{retval}) {
    triggerError($cgiObject, "Errors getting the performance of the entity:<br/>\n"
                           . "<b>" . $contentsCanvasRet->{output} . "</b>\n"
                           . ".<br/>You'll find more information in the logs.");
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

#
# Return an HTTP response showing the contents
# to show Thresholds and allow change them.
# It prints full HTTP response body, not just a canvas.
#
sub respondShowThresholds {
  my $cgiObject  = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $entType = 'OAlarm';
  my $entities;
  my $output = '';

  #
  # Navigation menu
  #
  my $id = getNavEntryIdForType('OAlarm');
  if (!defined $$navEntries{$id}) {
    die "respondShowPerformance: Can't find the navigation entry for $id";
  }
  my $attributes = $$navEntries{$id};
  my $menuCanvasRet = getNavMenuBody($attributes, $id);

  #
  # Contents
  #
  my $contentsCanvasRet = getContentsForShowThresholds($cgiObject);
  if(! $contentsCanvasRet->{retval}) {
    triggerError($cgiObject, "Errors generating the contents: "
                           . $contentsCanvasRet->{output} . "<br/>\n"
                           . "You'll find more information in the logs.");
    return;
  }

  #
  # Response
  #
  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.contents.tmpl'); 
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
  $template->param(NAVIGATION_CANVAS => $menuCanvasRet ); 
  $template->param(CONTENTS_CANVAS   => $contentsCanvasRet->{output} ); 
  print $template->output();
}


#
# Return an HTTP response showing the contents for a search of alerts
# It prints full HTTP response body, not just a canvas.
#
sub respondShowAlarmReport {
  my $cgiObject  = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $entType = 'OAlarm';
  my $entities;
  my $output = '';

  my $id = getNavEntryIdForType('OAlarm');
  if (!defined $$navEntries{$id}) {
    die "respondShowPerformance: Can't find the navigation entry for $id";
  }
  my $attributes = $$navEntries{$id};
  my $menuCanvasRet = getNavMenuBody($attributes, $id);
  my $contentsCanvasRet;
  my $errorInContentCanvas = 0;
  my %argsForAlarmsSqlSearch;

  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    $contentsCanvasRet = "Can't connect to DataBase.";
    $errorInContentCanvas = 1;
  }
  else {
    #
    # Let's get the report of alerts
    #
    my $aParam;

    $aParam = 'entity_type';
    if(defined($cgiObject->param($aParam))) {
      $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
    }
    $aParam = 'mo_ref';
    if(defined($cgiObject->param($aParam))) {
      $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
    }
    $aParam = 'is_critical';
    if(defined($cgiObject->param($aParam))) {
      my $v = $cgiObject->param($aParam);
      if($v == 0 || $v == 1) {
        $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
      }
      # else not selected, so sql will be 'value=*'
    }
    $aParam = 'perf_metric_id';
    if(defined($cgiObject->param($aParam))) {
      $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
    }
    $aParam = 'is_acknowledged';
    if(defined($cgiObject->param($aParam))) {
      my $v = $cgiObject->param($aParam);
      if($v == 0 || $v == 1) {
        $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
      }
      # else not selected, so sql will be 'value=*'
    }
    $aParam = 'is_active';
    if(defined($cgiObject->param($aParam))) {
      my $v = $cgiObject->param($aParam);
      if($v == 0 || $v == 1) {
        $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
      }
      # else not selected, so sql will be 'value=*'
    }
    $aParam = 'alarm_time_upper';
    if(defined($cgiObject->param($aParam))) {
      $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
    }
    $aParam = 'alarm_time_lower';
    if(defined($cgiObject->param($aParam))) {
      $argsForAlarmsSqlSearch{$aParam} = $cgiObject->param($aParam);
    }
    $aParam = 'groupInfoKey';
    if(defined($cgiObject->param($aParam))) {
      my @a = $cgiObject->param($aParam);
      $argsForAlarmsSqlSearch{$aParam} = \@a;
    }

    $entities = OvomDao::getAllEntitiesOfType('OAlarm', \%argsForAlarmsSqlSearch);
    if(! defined($entities)) {
      $contentsCanvasRet = "There were errors trying to get the list of ${entType}s from DB.";
      $errorInContentCanvas = 1;
    }
  }

  $output .= ($#$entities + 1) . " ${entType}s:<br/>\n";
  $output .= "<table>\n";
  $output .= getHtmlTableRowHeader('OAlarm') . "\n";
  foreach my $aEntity (@$entities) {
#   $output .= "<li>" . getLinkToEntity($aEntity) . "</li>\n";
    $output .= getHtmlTableRow($aEntity, $argsForAlarmsSqlSearch{'groupInfoKey'}) . "\n";
  }
  $output .= "</table>\n";

  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    $contentsCanvasRet = "Cannot disconnect from DataBase.";
    $errorInContentCanvas = 1;
  }

  if($errorInContentCanvas) {
    triggerError($cgiObject, "Errors getting alarm report:<br/>\n"
                           . "<b>" . $contentsCanvasRet . "</b>\n"
                           . ".<br/>You'll find more information in the logs.");
    return;
  }

  print $cgiObject->header(-cache_control=>"no-cache, no-store, must-revalidate");
  my $template = HTML::Template->new(filename => 'templates/session.contents.tmpl'); 
  $template->param(HEAD      => getHead() ); 
  $template->param(APP_TITLE => $OInventory::configuration{'app.title'} ); 
  $template->param(FOOTER    => getFooter() ); 
  $template->param(NAVIGATION_CANVAS => $menuCanvasRet ); 
  $template->param(CONTENTS_CANVAS   => $output ); 
  print $template->output();
}

sub getHtmlTableRow {
  my $entity      = shift;
  my $secondParam = shift;
  if(!defined($entity)) {
    OInventory::log(3, "getHtmlTableRow got a undef param");
    return '';
  }
  if(ref($entity) eq 'OAlarm') {
    my $groupInfoKeys = $secondParam;
    my $id;
    my $warnOrCrit;
    my $isActive;
    my $isAcknowledged;
    my $lastChange;
    my $name;

    my $entity_type=OInventory::entityId2entityType($entity->{entity_type});
    my $mo_ref=$entity->{mo_ref};
    my $perf_metric_id=$entity->{perf_metric_id};
    my $alarm_time=$entity->{alarm_time};
    my $counterName;
    my $instance;
    my $linkToSourceEntiy; # getLinkToEntity

    #
    # Let's get the source entity
    #
    my $sourceEntity = OvomDao::loadEntity($entity->{mo_ref}, $entity_type);
    if(! defined($sourceEntity)) {
      OInventory::log(3, "getHtmlTableRow can't load the source entity");
      $name = "Can't load it";
    }
    else {
      $name = $sourceEntity->{name};
      $linkToSourceEntiy = getLinkToEntity($sourceEntity);
      $name = $linkToSourceEntiy;
    }

    #
    # Let's load the PerfMetricId
    #
    my $pmi = OvomDao::loadEntity($entity->{perf_metric_id}, 'PerfMetric', '', '', 1);
    if(! defined($pmi)) {
      OInventory::log(3, "getHtmlTableRow can't load the PerfMetricId");
      $counterName = "Can't load it";
      $instance    = "Can't load it";
    }
    else {
      my $counterId = $pmi->counterId;
      my $pci = OvomDao::loadEntity($counterId, 'PerfCounterInfo');
      if(! defined($pci)) {
        OInventory::log(3, "getHtmlTableRow can't load the PerfCounterInfo");
        $counterName = "Can't load it";
      }
      else {
        if(defined($groupInfoKeys)) {
          my $found = 0;
          foreach my $aGIK (@$groupInfoKeys) {
            if($aGIK eq $pci->groupInfo->key) {
              $found = 1;
            }
          }
          if(!$found) {
            return '';
          }
        }
        $counterName = $pci->nameInfo->label;
        $instance    = $pmi->instance;
      }
    }
  
    if(defined($entity->{id})) {
      $id = $entity->{id};
    }
    else {
      $id = 'undef';
    }
    if($entity->{is_critical}) {
      $warnOrCrit = 'Critical';
    }
    else {
      $warnOrCrit = 'Warning';
    }
    if($entity->{is_active}) {
      $isActive = 'active';
    }
    else {
      $isActive = 'non-active';
    }
    if($entity->{is_acknowledged}) {
      $isAcknowledged = 'acknowledged';
    }
    else {
      $isAcknowledged = 'non-acknowledged';
    }
    if(defined($entity->{last_change})) {
      $lastChange = $entity->{last_change};
    }
    else {
      $lastChange = 'undef';
    }

    return <<"_ENTITY_CONTENTS_";
<tr>
  <td>$id</td>
  <td>$entity_type</td>
  <td>$name</td>
  <td>$mo_ref</td>
  <td>$warnOrCrit</td>
  <td>$perf_metric_id</td>
  <td>$counterName</td>
  <td>$instance</td>
  <td>$isAcknowledged</td>
  <td>$isActive</td>
  <td>$alarm_time</td>
  <td>$lastChange</td>
</tr>
_ENTITY_CONTENTS_

  }
  elsif(ref($entity) eq 'OPerfCounterInfo') {
    my $showAllFields = $secondParam;
    my $showAllFieldsSend = 0;
    if(defined($showAllFields) && $showAllFields == 1) {
      $showAllFieldsSend = 1;
    }
    return "<tr>\n" . $entity->toCsvRow($showAllFieldsSend) . "\n</tr>\n";
  }
  else {
    OInventory::log(3, "getHtmlTableRow got an unexpected "
                    . ref($entity) . " param");
    return '';
  }
}

sub getHtmlTableRowHeader {
  my $entity        = shift;
  my $showAllFields = shift;
  if(!defined($entity)) {
    OInventory::log(3, "getHtmlTableRow got a undef param");
    return '';
  }
  if($entity eq 'OAlarm') {

    return <<"_ENTITY_CONTENTS_";
<tr>
  <th>id</th>
  <th>entity_type</th>
  <th>mo_ref</th>
  <th>name</th>
  <th>warnOrCrit</th>
  <th>perf_metric_id</th>
  <th>counter</th>
  <th>instance</th>
  <th>isAcknowledged</th>
  <th>isActive</th>
  <th>alarm_time</th>
  <th>lastChange</th>
</tr>
_ENTITY_CONTENTS_

  }
  elsif($entity eq 'OPerfCounterInfo') {
    my $showAllFieldsSend = 0;
    if(defined($showAllFields) && $showAllFields == 1) {
      $showAllFieldsSend = 1;
    }
    return "<tr>\n" . $entity->getCsvRowHeader($showAllFieldsSend) . "\n</tr>\n";
  }
  else {
    OInventory::log(3, "getHtmlTableRowHeader got an unexpected "
                    . ref($entity) . " param");
    return '';
  }
}

#
# Gets the string to show the contents for "Thresholds"
#
# @return ref to hash with keys:
#         * retval : 1 (ok) | 0 (errors)
#         * output : html output to be returned
#
sub getContentsForShowThresholds {
  my $cgiObject    = shift;
  die "Must get a CGI object param" if(ref($cgiObject) ne 'CGI');
  my $retval = 1;
  my $errStr = '';
  my $groupInfoKeys;
  my $output;

  #
  # Connect to Database:
  #
  if(OvomDao::connect() != 1) {
    $retval = 0;
    $errStr         .= "Can't connect to DataBase. ";
    OInventory::log(3, "Can't connect to DataBase. ");
    goto _GROUPINFO_KEYS_SEARCHED_;
  }

  $groupInfoKeys = OvomDao::getAllGroupInfoKeys();
  if(! defined($groupInfoKeys)) {
    $retval = 0;
    $errStr         .= "Errors trying to get the list of PerfCounterInfos. ";
    OInventory::log(3, "Errors trying to get the list of PerfCounterInfos. ");
    goto _GROUPINFO_KEYS_SEARCHED_;
  }

  my $entType = 'groupInfoKey';
  my $doSearch = $cgiObject->param('doSearch');
  my $doUpdate = $cgiObject->param('doUpdate');
  my @groupInfoKeys = $cgiObject->param('groupInfoKey');
  my @pcis; # PerfCounterInfo objects

  if(defined($doSearch) && $doSearch == 1) {
    my $entities = OvomDao::getAllEntitiesOfType('PerfCounterInfo');
    if(! defined($entities)) {
      $retval = 0;
      $errStr         .= "There were errors trying to get the list of ${entType}s. ";
      OInventory::log(3, "There were errors trying to get the list of ${entType}s. ");
      goto _GROUPINFO_KEYS_SEARCHED_;
    }
    PCI_LABEL: foreach my $aPCI (@$entities) {
      GIK_LABEL: foreach my $aGIK (@groupInfoKeys) {
        if ($aGIK eq $aPCI->groupInfo->key) {
          push @pcis, $aPCI;
          last GIK_LABEL;
        }
        else {
          next;
        }

      }
    }
  }
  if(defined($doUpdate) && $doUpdate == 1) {
    my $t = '';
    foreach my $aParam ($cgiObject->param()) {
      $t .= "$aParam ";
    }
    die "Will continue here: must manage the params, parse 1) the PCI key 2) crit|warn 3) and the threshold value = $t";
  }

  #
  # Let's disconnect from DB
  #
  if( OvomDao::disconnect() != 1 ) {
    $retval = 0;
    $errStr         .= "Cannot disconnect from DataBase.";
    OInventory::log(3, "Cannot disconnect from DataBase.");
  }
  _GROUPINFO_KEYS_SEARCHED_:
  if(! $retval) {
    return { retval => $retval, output => $errStr };
  }

  #
  # Let's compose the search menu
  #
  my $groupInfoCheckboxesHtml = '';
  foreach my $aGIKey (@$groupInfoKeys) {
    $groupInfoCheckboxesHtml .= "<input type='checkbox' name='groupInfoKey' value='$aGIKey' checked>$aGIKey</input>\n";
  }

  my $showAllFieldsGot = $cgiObject->param('showAllFields');
  my $showAllFields = 0;
  if(defined($showAllFieldsGot) && $showAllFieldsGot ne '') {
    $showAllFields = 1;
  }

  #
  # Let's compose the table with the results of the search of PCIs
  #

  my $perfCounterInfosHtml = <<"_THRESHOLDS_INIT_TABLE_";
<form action="?" method="post" accept-charset="utf-8">
  <input type="hidden" name="actionId" value="$ACTION_ID_SHOW_THRESHOLDS"/>
  <input type="hidden" name="doUpdate" value="1"/>
  <table>
_THRESHOLDS_INIT_TABLE_

  if(defined($doSearch) && $doSearch == 1) {
    $perfCounterInfosHtml   .= getHtmlTableRowHeader('OPerfCounterInfo', $showAllFields) . "\n";
    foreach my $aPCI (@pcis) {
      $perfCounterInfosHtml .= getHtmlTableRow($aPCI, $showAllFields) . "\n";
    }
    my $colspan = 16;
    $perfCounterInfosHtml .= "<tr><td colspan=$colspan><input type='submit' name='Set thresholds' value='Set thresholds'/></td></td>\n";
    $perfCounterInfosHtml .= "</table>\n";
    $perfCounterInfosHtml .= "</form>\n";
  }

  #
  # Let's compose the output
  #
  $output = <<"_THRESHOLDS_";
<h2>Thresholds</h2>
  <h3> Show thresholds </h3>
    <p> Choose which counters and thresholds do you want to show: </p>
    <form action="?" method="post" accept-charset="utf-8">
      <input type="hidden" name="actionId" value="$ACTION_ID_SHOW_THRESHOLDS"/>
      <input type="hidden" name="doSearch" value="1"/>
      <table border="1">
        <tr>
          <th valign="middle">GroupInfo</th>
          <td>
            $groupInfoCheckboxesHtml
          </td>
        </tr>
        <tr>
          <td align="center">
            <input type="submit" name="Show" value="Show" />
          </td>
          <td align="center">
            <input type="checkbox" name="showAllFields" value="showAllFields" />
            Show all fields for Group Info objects
          </td>
        </tr>
      </table>
    </form>
_THRESHOLDS_

  if(defined($doSearch) && $doSearch == 1) {
  $output .= <<"_THRESHOLDS2_";
  <h3> PerfCounterInfo objects and its thresholds </h3>
    <p> Please remember that these are generic counter objects, its values apply to all the affected entities. Later, these thresholds can be overriden in each of those entity. </p>
    $perfCounterInfosHtml
_THRESHOLDS2_
  }

  return { retval => $retval, output => $output };
}


1;

package OPerfCounterInfo;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';
use Data::Dumper;

our $csvSep = ";";

sub new {
  my ($class, $args) = @_;

  if(! defined ($args) || ref($args) ne 'ARRAY') {
    Carp::croak("OPerfCounterInfo needs a ref to array of values");
  }
  if($#$args < 13) {
    Carp::croak("Array with few many values for OPerfCounterInfo");
  }

  my $__statsType      = OMockView::OMockStatsType->new(shift @$args),
  my $__perDeviceLevel = shift @$args,
  my $__nameInfo       = OMockView::OMockNameInfo->new([shift @$args,  shift @$args, shift @$args]),
  my $__groupInfo      = OMockView::OMockGroupInfo->new([shift @$args, shift @$args, shift @$args]),
  my $__key            = shift @$args,
  my $__level          = shift @$args,
  my $__rollupType     = OMockView::OMockRollupType->new(shift @$args),
  my $__unitInfo       = OMockView::OMockUnitInfo->new([shift @$args, shift @$args, shift @$args]),
  my $__critThreshold  = $#$args > -1 ? shift @$args : undef;
  my $__warnThreshold  = $#$args > -1 ? shift @$args : undef;

  my $self = bless {
    _statsType      => $__statsType,
    _perDeviceLevel => $__perDeviceLevel,
    _nameInfo       => $__nameInfo,
    _groupInfo      => $__groupInfo,
    _key            => $__key,
    _level          => $__level,
    _rollupType     => $__rollupType,
    _unitInfo       => $__unitInfo,
    _critThreshold => $__critThreshold,
    _warnThreshold => $__warnThreshold,
  }, $class;
  return $self;
}

#
# A kind of clone from VMware's PerfCounterInfo or from ovom's OPerfCounterInfo
#
sub newFromPerfCounterInfo {
  my ($class, $pci) = @_;

  if(! defined ($pci) || (ref($pci) ne 'PerfCounterInfo' && ref($pci) ne 'OPerfCounterInfo')) {
    Carp::croak("OPerfCounterInfo needs a PerfCounterInfo or OPerfCounterInfo and got a " . ref($pci));
  }

  my $__statsType      = OMockView::OMockStatsType->newFromPerfStatsType($pci->statsType);
  my $__perDeviceLevel = $pci->perDeviceLevel;
  my $__nameInfo       = OMockView::OMockNameInfo->newFromElementDescription($pci->nameInfo);
  my $__groupInfo      = OMockView::OMockGroupInfo->newFromElementDescription($pci->groupInfo);
  my $__key            = $pci->key;
  my $__level          = $pci->level;
  my $__rollupType     = OMockView::OMockRollupType->newFromPerfSummaryType($pci->rollupType);
  my $__unitInfo       = OMockView::OMockUnitInfo->newFromElementDescription($pci->unitInfo);
  my $__critThreshold  = defined($pci->{_critThreshold}) ?
                                 $pci->{_critThreshold} : undef;
  my $__warnThreshold  = defined($pci->{_warnThreshold}) ?
                                 $pci->{_warnThreshold} : undef;

  my $self = bless {
    _statsType      => $__statsType,
    _perDeviceLevel => $__perDeviceLevel,
    _nameInfo       => $__nameInfo,
    _groupInfo      => $__groupInfo,
    _key            => $__key,
    _level          => $__level,
    _rollupType     => $__rollupType,
    _unitInfo       => $__unitInfo,
    _critThreshold  => $__critThreshold,
    _warnThreshold  => $__warnThreshold,
  }, $class;
  return $self;
}

sub statsType {
  my ($self) = @_;
  return $self->{_statsType};
}

sub perDeviceLevel {
  my ($self) = @_;
  return $self->{_perDeviceLevel};
}

sub nameInfo {
  my ($self) = @_;
  return $self->{_nameInfo};
}

sub groupInfo {
  my ($self) = @_;
  return $self->{_groupInfo};
}

sub key {
  my ($self) = @_;
  return $self->{_key};
}

sub level {
  my ($self) = @_;
  return $self->{_level};
}

sub rollupType {
  my ($self) = @_;
  return $self->{_rollupType};
}

sub unitInfo {
  my ($self) = @_;
  return $self->{_unitInfo};
}

sub warnThreshold {
  my ($self) = @_;
  return $self->{_warnThreshold};
}

sub critThreshold {
  my ($self) = @_;
  return $self->{_critThreshold};
}

sub setWarnThreshold {
  my ($self, $t) = @_;
  $self->{_warnThreshold} = $t;
}

sub setCritThreshold {
  my ($self, $t) = @_;
  $self->{_critThreshold} = $t;
}

#
# Compare this object with other object of the same type.
#
# Be careful! We don't compare warnThreshold or critThreshold,
# we are just comparing the attributes specified by vCenter.
#
# @arg reference to the other object of the same type
# @return  1 (if equal),
#          0 (if different),
#         -1 if error
#
sub compare {
  my $self  = shift;
  my $other = shift;
  if(! defined($other)) {
    Carp::croak("Compare requires other entity of the same type as argument");
    return -2;
  }
  if(ref($other) ne 'PerfCounterInfo' && ref($other) ne 'OPerfCounterInfo' ) {
    Carp::croak("Compare requires other entity of the same type as argument,"
              . "self=" . ref($self) . "other=" . ref($other) );
    return -2;
  }
  elsif(
       $self->statsType->val     ne $other->statsType->val
    || $self->perDeviceLevel     ne $other->perDeviceLevel
    || $self->nameInfo->key      ne $other->nameInfo->key
    || $self->nameInfo->label    ne $other->nameInfo->label
    || $self->nameInfo->summary  ne $other->nameInfo->summary
    || $self->groupInfo->key     ne $other->groupInfo->key
    || $self->groupInfo->label   ne $other->groupInfo->label
    || $self->groupInfo->summary ne $other->groupInfo->summary
    || $self->key                ne $other->key
    || $self->level              ne $other->level
    || $self->rollupType->val    ne $other->rollupType->val
    || $self->unitInfo->key      ne $other->unitInfo->key
    || $self->unitInfo->label    ne $other->unitInfo->label
    || $self->unitInfo->summary  ne $other->unitInfo->summary
  ) {
    # Different folder (mo_ref differs)
    return 0;
  }
  else {
    # Equal object
    return 1;
  }
}

sub getShortDescription {
  my ($self) = @_;
  return $self->{_nameInfo}->{_label} . " (" . $self->{_unitInfo}->{_label} . ")";
}

sub toCsvRow {
  my ($self) = @_;

  my $cth = '';
  my $wth = '';
  if(defined($self->{_critThreshold})) {
    $cth = $self->{_critThreshold};
  }
  else {
    $cth = '';
  }
  if(defined($self->{_warnThreshold})) {
    $wth = $self->{_warnThreshold};
  }
  else {
    $wth = '';
  }

  my $r = 
    $self->{_key}                    . $csvSep .
    $self->{_groupInfo}->{_key}      . $csvSep .
    $self->{_groupInfo}->{_label}    . $csvSep .
    $self->{_groupInfo}->{_summary}  . $csvSep .
    $self->{_nameInfo}->{_key}       . $csvSep .
    $self->{_nameInfo}->{_label}     . $csvSep .
    $self->{_nameInfo}->{_summary}   . $csvSep .
    $self->{_unitInfo}->{_key}       . $csvSep .
    $self->{_unitInfo}->{_label}     . $csvSep .
    $self->{_unitInfo}->{_summary}   . $csvSep .
    $self->{_statsType}->{_val}      . $csvSep .
    $self->{_perDeviceLevel}         . $csvSep .
    $self->{_level}                  . $csvSep .
    $self->{_rollupType}->{_val}     . $csvSep .
    $cth                             . $csvSep .
    $wth;

  return $r;
}

sub toHtmlTableRow {
# my $self = shift;
# my $args = shift;
  my ($self, $args) = @_;

  my $showAllFields = $args->{'showAllFields'};
  my $showPmis      = $args->{'showPmis'};
  my $pmis          = $args->{'pmis'};

  if (defined($pmis) && ref($pmis) ne 'ARRAY') {
    Carp::croak("BUG: toCsvRow expected an array of PerfMetricIds");
    die "BUG: toCsvRow expected an array of PerfMetricIds";
  }

  my $cth = '';
  my $wth = '';
  if(defined($self->{_critThreshold})) {
    $cth = $self->{_critThreshold};
  }
  else {
    $cth = '';
  }
  if(defined($self->{_warnThreshold})) {
    $wth = $self->{_warnThreshold};
  }
  else {
    $wth = '';
  }

# key , gil , (gil) , (gis) , nil , (nil) , nis , uil , (uis) , (uik)
  my $r;
  my $fillMorefHtml;
  my $fillInstanceHtml;

  if(defined($showPmis) && $showPmis == 1) {
    $fillMorefHtml    = "<td> &nbsp; </td>\n ";
    $fillInstanceHtml = "<td> &nbsp; </td>\n ";
  }

  if(defined($showAllFields) && $showAllFields == 1) {
    my $keyInform = "<input type='hidden' name='keythressend_" . $self->{_key} . "' value='1'/>\n";
    $r = sprintf "<tr><td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n %s %s <td><input type='text' name='critthres_%s' value='%s'/></td>\n<td> <input type='text' name='warnthres_%s' value='%s'/>\n%s\n</td>\n</tr>\n" ,

      $self->{_key},
      $self->{_groupInfo}->{_key},
      $self->{_groupInfo}->{_label},
      $self->{_groupInfo}->{_summary},
      $self->{_nameInfo}->{_key},
      $self->{_nameInfo}->{_label},
      $self->{_nameInfo}->{_summary},
      $self->{_unitInfo}->{_key},
      $self->{_unitInfo}->{_label},
      $self->{_unitInfo}->{_summary},
      $self->{_statsType}->{_val},
      $self->{_perDeviceLevel},
      $self->{_level},
      $self->{_rollupType}->{_val},
      $fillMorefHtml,
      $fillInstanceHtml,
      $self->{_key},
      $cth,
      $self->{_key},
      $wth,
      $keyInform;

    if(defined($showPmis) && $showPmis == 1) {
      foreach my $aPmi (@$pmis) {

        my $moref    = $aPmi->entity_mo_ref;
        my $instance = $aPmi->instance;
        my $critThres = defined($aPmi->critThreshold) ? $aPmi->critThreshold : '';
        my $warnThres = defined($aPmi->warnThreshold) ? $aPmi->warnThreshold : '';
        my $pmiCritfHtml = "<input type='text' name='pmicritthres_" . $aPmi->id . "' value='" . $critThres . "'/>";
        my $pmiWarnfHtml = "<input type='text' name='pmiwarnthres_" . $aPmi->id . "' value='" . $warnThres . "'/>";

        my $pmiInform = "<input type='hidden' name='pmithressend_" . $aPmi->id . "' value='1'/>\n";

        $r .= sprintf "<tr>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n <td bgcolor='#ffffcc'> %s </td>\n<td bgcolor='#ffff99'> %s </td>\n<td bgcolor='ffcc66'> %s </td>\n<td bgcolor='ffff66'>\n%s\n%s\n</td>\n</tr>\n" , $moref, $instance, $pmiCritfHtml, $pmiWarnfHtml, $pmiInform;
      }
    }
    return $r;
  }
  else {
    my $keyInform = "<input type='hidden' name='keythressend_" . $self->{_key} . "' value='1'/>";
    $r = sprintf "<tr><td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n<td> %s </td>\n %s %s <td><input type='text' name='critthres_%s' value='%s'/></td>\n<td> <input type='text' name='warnthres_%s' value='%s'/>\n%s\n</td>\n</tr>\n" ,

      $self->{_key},
#     $self->{_groupInfo}->{_key},
      $self->{_groupInfo}->{_label},
#     $self->{_groupInfo}->{_summary},
#     $self->{_nameInfo}->{_key},
      $self->{_nameInfo}->{_label},
#     $self->{_nameInfo}->{_summary},
#     $self->{_unitInfo}->{_key},
      $self->{_unitInfo}->{_label},
#     $self->{_unitInfo}->{_summary},
      $self->{_statsType}->{_val},
      $self->{_perDeviceLevel},
      $self->{_level},
      $self->{_rollupType}->{_val},
      $fillMorefHtml,
      $fillInstanceHtml,
      $self->{_key},
      $cth,
      $self->{_key},
      $wth,
      $keyInform;

    if(defined($showPmis) && $showPmis == 1) {
      foreach my $aPmi (@$pmis) {
        my $moref    = $aPmi->entity_mo_ref;
        my $instance = $aPmi->instance;
        my $critThres = defined($aPmi->critThreshold) ? $aPmi->critThreshold : '';
        my $warnThres = defined($aPmi->warnThreshold) ? $aPmi->warnThreshold : '';
        my $pmiCritfHtml = "<input type='text' name='pmicritthres_" . $aPmi->id . "' value='" . $critThres . "'/>";
        my $pmiWarnfHtml = "<input type='text' name='pmiwarnthres_" . $aPmi->id . "' value='" . $warnThres . "'/>";

        my $pmiInform = "<input type='hidden' name='pmithressend_" . $aPmi->id . "' value='1'/>\n";

        $r .= sprintf "<tr>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n<td> &nbsp; </td>\n <td bgcolor='#ffffcc'> %s </td>\n<td bgcolor='#ffff99'> %s </td>\n<td bgcolor='ffcc66'> %s </td>\n<td bgcolor='ffff66'> %s\n%s\n</td>\n</tr>\n" , $moref, $instance, $pmiCritfHtml, $pmiWarnfHtml, $pmiInform;
      }
    }

    return $r;
  }
}


#
# Such a static method...
#
sub getCsvRowHeader {
  my $self          = shift;
  my $showAllFields = shift;
  my $showPmis      = shift;
  my $showPmisHtml  = '';

  if(defined($showPmis) && $showPmis == 1) {
    $showPmisHtml = "<th> mo_ref <br/>(PMI) </th>\n<th> instance <br/>(PMI) </th>\n";
  }

  if(defined($showAllFields) && $showAllFields == 1) {
    return sprintf "<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n$showPmisHtml<th> %s </th>\n<th> %s </th>\n" ,
      'Key',
      'Group info key',
      'Group info label',
      'Group info summary',
      'Name info key',
      'Name info label',
      'Name info summary',
      'Unit info key',
      'Unit info label',
      'Unit info summary',
      'Stats Type',
      'Per device level',
      'Level',
      'RollupType val',
      'Critical threshold',
      'Warning threshold';
  }
  else {
    return sprintf "\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n<th> %s </th>\n$showPmisHtml<th> %s </th>\n<th> %s </th>\n" ,
      'Key',
#     'Group info key',
      'Group info label',
#     'Group info summary',
#     'Name info key',
      'Name info label',
#     'Name info summary',
#     'Unit info key',
      'Unit info label',
#     'Unit info summary',
      'Stats Type',
      'Per device level',
      'Level',
      'RollupType val',
      'Critical threshold',
      'Warning threshold';
  }
}


sub stringify {
  my ($self) = @_;

  my $s = '';
  if(defined($self->{_critThreshold})) {
    $s .= ",critThreshold='" . $self->{_critThreshold} . "'";
  }
  else {
    $s .= ",no_critThreshold";
  }
  if(defined($self->{_warnThreshold})) {
    $s .= ",warnThreshold='" . $self->{_warnThreshold} . "'";
  }
  else {
    $s .= ",no_warnThreshold";
  }

  return sprintf "'%s' with statsType='%s', perDeviceLevel='%s', nameInfoKey='%s', nameInfoLabel='%s', nameInfoSummary='%s', groupInfoKey='%s', groupInfoLabel='%s', groupInfoSummary='%s', key='%s', level='%s', rollupType='%s', unitInfoKey='%s', unitInfoLabel='%s', unitInfoSummary='%s' %s", ref($self), $self->{_statsType}->{_val}, $self->{_perDeviceLevel}, $self->{_nameInfo}->{_key}, $self->{_nameInfo}->{_label}, $self->{_nameInfo}->{_summary}, $self->{_groupInfo}->{_key}, $self->{_groupInfo}->{_label}, $self->{_groupInfo}->{_summary}, $self->{_key}, $self->{_level}, $self->{_rollupType}->{_val}, $self->{_unitInfo}->{_key}, $self->{_unitInfo}->{_label}, $self->{_unitInfo}->{_summary}, $s;
}

1;

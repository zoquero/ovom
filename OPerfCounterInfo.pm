package OPerfCounterInfo;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';
use Data::Dumper;

sub new {
  my ($class, $args) = @_;

  if(! defined ($args) || ref($args) ne 'ARRAY') {
    Carp::croak("OPerfCounterInfo needs a ref to array of values");
  }
  if($#$args < 13) {
    Carp::croak("Array with few many values for OPerfCounterInfo");
  }

#  my $__entity_mo_ref   = shift @$args;
#  my $__counterId       = shift @$args;
#  my $__instance        = shift @$args;
#  my $__crit_threshold  = $#$args > -1 ? shift @$args : undef;
#  my $__warn_threshold  = $#$args > -1 ? shift @$args : undef;
#  my $__last_value      = $#$args > -1 ? shift @$args : undef;
#  my $__last_collection = $#$args > -1 ? shift @$args : undef;

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

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with statsType='%s', perDeviceLevel='%s', nameInfoKey='%s', nameInfoLabel='%s', nameInfoSummary='%s', groupInfoKey='%s', groupInfoLabel='%s', groupInfoSummary='%s', key='%s', level='%s', rollupType='%s', unitInfoKey='%s', unitInfoLabel='%s', unitInfoSummary='%s'", ref($self), $self->{_statsType}->{_val}, $self->{_perDeviceLevel}, $self->{_nameInfo}->{_key}, $self->{_nameInfo}->{_label}, $self->{_nameInfo}->{_summary}, $self->{_groupInfo}->{_key}, $self->{_groupInfo}->{_label}, $self->{_groupInfo}->{_summary}, $self->{_key}, $self->{_level}, $self->{_rollupType}->{_val}, $self->{_unitInfo}->{_key}, $self->{_unitInfo}->{_label}, $self->{_unitInfo}->{_summary};
}

1;

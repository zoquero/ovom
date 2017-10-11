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

  my $self = bless {
    _statsType        => OMockView::OMockStatsType->new($$args[0]),
    _perDeviceLevel   => $$args[1],
    _nameInfo         => OMockView::OMockNameInfo->new([$$args[2],  $$args[3], $$args[4]]),
    _groupInfo        => OMockView::OMockGroupInfo->new([$$args[5], $$args[6], $$args[7]]),
    _key              => $$args[8],
    _level            => $$args[9],
    _rollupType       => OMockView::OMockRollupType->new($$args[10]),
    _unitInfo         => OMockView::OMockUnitInfo->new([$$args[11], $$args[12], $$args[13]]),
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

#
# Compare this object with other object of the same type
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
  return $self->{_nameInfo}->{_summary} . " (" . $self->{_unitInfo}->{_summary} . ")";
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with statsType='%s', perDeviceLevel='%s', nameInfoKey='%s', nameInfoLabel='%s', nameInfoSummary='%s', groupInfoKey='%s', groupInfoLabel='%s', groupInfoSummary='%s', key='%s', level='%s', rollupType='%s', unitInfoKey='%s', unitInfoLabel='%s', unitInfoSummary='%s'", ref($self), $self->{_statsType}->{_val}, $self->{_perDeviceLevel}, $self->{_nameInfo}->{_key}, $self->{_nameInfo}->{_label}, $self->{_nameInfo}->{_summary}, $self->{_groupInfo}->{_key}, $self->{_groupInfo}->{_label}, $self->{_groupInfo}->{_summary}, $self->{_key}, $self->{_level}, $self->{_rollupType}->{_val}, $self->{_unitInfo}->{_key}, $self->{_unitInfo}->{_label}, $self->{_unitInfo}->{_summary};
}

1;

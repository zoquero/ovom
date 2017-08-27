package OPerfCounterInfo;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

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
    _unitInfo         => OMockView::OMockGroupInfo->new([$$args[11], $$args[12], $$args[13]]),
  }, $class;
  return $self;
}

sub key {
  my ($self) = @_;
  return $self->{_key};
}

sub groupInfo {
  my ($self) = @_;
  return $self->{_groupInfo};
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with statsType='%s', perDeviceLevel='%s', nameInfoKey='%s', nameInfoLabel='%s', nameInfoSummary='%s', groupInfoKey='%s', groupInfoLabel='%s', groupInfoSummary='%s', key='%s', level='%s', rollupType='%s', unitInfoKey='%s', unitInfoLabel='%s', unitInfoSummary='%s'", ref($self), $self->{_statsType}->{_val}, $self->{_perDeviceLevel}, $self->{_nameInfo}->{_key}, $self->{_nameInfo}->{_label}, $self->{_nameInfo}->{_summary}, $self->{_groupInfo}->{_key}, $self->{_groupInfo}->{_label}, $self->{_groupInfo}->{_summary}, $self->{_key}, $self->{_level}, $self->{_rollupType}->{_val}, $self->{_unitInfo}->{_key}, $self->{_unitInfo}->{_label}, $self->{_unitInfo}->{_summary};
}

1;

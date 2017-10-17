package OMockView::OMockPerfMetricId;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

sub new {
  my ($class, $args) = @_;

  if(! defined ($args) || ref($args) ne 'ARRAY') {
    Carp::croak("The constructor needs a ref to array of values");
    return undef;
  }

  if($#$args < 2) {
    Carp::croak("Array with few many values received in OMockPerfMetricId constructor");
    return undef;
  }

  my $__entity_mo_ref   = shift @$args;
  my $__counterId       = shift @$args;
  my $__instance        = shift @$args;
  my $__crit_threshold  = $#$args > -1 ? shift @$args : undef;
  my $__warn_threshold  = $#$args > -1 ? shift @$args : undef;
  my $__last_value      = $#$args > -1 ? shift @$args : undef;
  my $__last_collection = $#$args > -1 ? shift @$args : undef;

  my $self = bless {
    _entity_mo_ref => $__entity_mo_ref,
    _counterId     => $__counterId,
    _instance      => $__instance,
    _crit_threshold  => $__crit_threshold,
    _warn_threshold  => $__warn_threshold,
    _last_value      => $__last_value,
    _last_collection => $__last_collection,
  }, $class;
  return $self;
}

sub entity_mo_ref {
  my ($self) = @_;
  return $self->{_entity_mo_ref};
}

sub instance {
  my ($self) = @_;
  return $self->{_instance};
}

sub counterId {
  my ($self) = @_;
  return $self->{_counterId};
}

sub warnThreshold {
  my ($self) = @_;
  return $self->{_warnThreshold};
}

sub critThreshold {
  my ($self) = @_;
  return $self->{_critThreshold};
}

sub lastValue {
  my ($self) = @_;
  return $self->{_lastValue};
}

sub lastCollection {
  my ($self) = @_;
  return $self->{_lastCollection};
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s': {entity_mo_ref='%s',counterId='%s',instance='%s'}", ref($self), $self->{_entity_mo_ref}, $self->{_counterId}, $self->{_instance};
}

1;

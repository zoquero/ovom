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

  if($#$args < 3) {
    Carp::croak("Array with few many values received in OMockPerfMetricId constructor");
    return undef;
  }

  my $__id              = shift @$args;
  my $__entity_mo_ref   = shift @$args;
  my $__counterId       = shift @$args;
  my $__instance        = shift @$args;
  my $__critThreshold   = $#$args > -1 ? shift @$args : undef;
  my $__warnThreshold   = $#$args > -1 ? shift @$args : undef;
  my $__last_value      = $#$args > -1 ? shift @$args : undef;
  my $__last_collection = $#$args > -1 ? shift @$args : undef;

  my $self = bless {
    _id              => $__id,
    _entity_mo_ref   => $__entity_mo_ref,
    _counterId       => $__counterId,
    _instance        => $__instance,
    _critThreshold   => $__critThreshold,
    _warnThreshold   => $__warnThreshold,
    _last_value      => $__last_value,
    _last_collection => $__last_collection,
  }, $class;
  return $self;
}

sub newFromPerfMetricId {
  my ($class, $pmi) = @_;

  if(! defined ($pmi) || ref($pmi) ne 'PerfMetricId') {
    Carp::croak("The constructor needs a ref to PerfMetricId");
    return undef;
  }

  my $__id              = undef;
  my $__entity_mo_ref   = $pmi->{entity_mo_ref};
  my $__counterId       = $pmi->{counterId};
  my $__instance        = $pmi->{instance};
  my $__critThreshold   = undef;
  my $__warnThreshold   = undef;
  my $__last_value      = undef;
  my $__last_collection = undef;

  my $self = bless {
    _id              => $__id,
    _counterId       => $__counterId,
    _instance        => $__instance,
    _critThreshold   => $__critThreshold,
    _warnThreshold   => $__warnThreshold,
    _last_value      => $__last_value,
    _last_collection => $__last_collection,
  }, $class;
  return $self;
}

sub setId {
  my ($self, $newId) = @_;
  $self->{_id} = $newId;
}

sub id {
  my ($self) = @_;
  return $self->{_id};
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

sub setWarnThreshold {
  my ($self, $t) = @_;
  $self->{_warnThreshold} = $t;
}

sub setCritThreshold {
  my ($self, $t) = @_;
  $self->{_critThreshold} = $t;
}

sub stringify {
  my ($self) = @_;
  my $s = '';
  my $id = '';
  if(defined($self->{_id})) {
    $id = $self->{_id};
  }
  else {
    $id = "undef";
  }
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
  return sprintf "'%s': {id='%s',entity_mo_ref='%s',counterId='%s',instance='%s'%s}", ref($self), $id, $self->{_entity_mo_ref}, $self->{_counterId}, $self->{_instance}, $s;
}

1;

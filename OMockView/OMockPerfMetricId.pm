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

  if($#$args < 1) {
    Carp::croak("Array with few many values received in constructor");
    return undef;
  }

  my $self = bless {
    _counterId => shift @$args,
    _instance  => shift @$args,
  }, $class;
  return $self;
}

sub instance {
  my ($self) = @_;
  return $self->{_instance};
}

sub counterId {
  my ($self) = @_;
  return $self->{_counterId};
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with counterId='%s', instance='%s'", ref($self), $self->{_counterId}, $self->{_instance};
}

1;

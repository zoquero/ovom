package OMockView::OMockGroupInfo;
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
    Carp::croak("Array with few many values received in constructor");
    return undef;
  }

  my $self = bless {
    _key      => shift @$args,
    _label    => shift @$args,
    _summary  => shift @$args,
  }, $class;
  return $self;
}

sub newFromElementDescription {
  my ($class, $p) = @_;

  if(! defined ($p) || ref($p) ne 'ElementDescription') {
    Carp::croak("The constructor needs a ElementDescription and got a " 
                . ref($p));
    return undef;
  }

  my $self = bless {
    _key     => $p->{key},
    _label   => $p->{label},
    _summary => $p->{summary},
  }, $class;
  return $self;
}

sub key {
  my ($self) = @_;
  return $self->{_key};
}

sub label {
  my ($self) = @_;
  return $self->{_label};
}

sub summary {
  my ($self) = @_;
  return $self->{_summary};
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with key='%s', label='%s', summary='%s'", ref($self), $self->{_key}, $self->{_label}, $self->{_summary};
}

1;

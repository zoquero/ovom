package OMockView::OMockPerfQuerySpec;

use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

sub new {
  my ($class, %args) = @_;

  if(! defined ($args{'entity'}) || ! defined ($args{'metricId'})
  || ! defined ($args{'format'}) || ! defined ($args{'intervalId'})) {
    Carp::croak("The constructor needs a hash of args");
    return undef;
  }

  my $self = bless {
    _entity      => $args{'entity'},
    _metricId    => $args{'metricId'},
    _format      => $args{'format'},
    _intervalId  => $args{'intervalId'},
  }, $class;
  return $self;
}

# sub instance {
#   my ($self) = @_;
#   return $self->{_instance};
# }

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with entity->name='%s', #metricIds='%s', format='%s', intervalId='%s'", ref($self), $self->{_entity}->{view}, $#${$self->{_metricId}}, $self->{_format}, $self->{_intervalId};
}

1;

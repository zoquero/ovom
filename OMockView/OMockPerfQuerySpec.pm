package OMockView::OMockPerfQuerySpec;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use overload
    '""' => 'stringify';

#
#
# @arg entity view object
# @arg ref to array of PerfMetricId objcts
# @arg format (ex.: 'csv')
# @arg intervalId (ex.: 20)
#
sub new {
  my ($class, %args) = @_;

  if(! defined ($args{'entity'}) || ! defined ($args{'metricId'})
  || ! defined ($args{'format'}) || ! defined ($args{'intervalId'})) {
    Carp::croak("The constructor needs a hash of args");
    return undef;
  }

  my $entity = $args{'entity'};
  if(! defined($entity->{mo_ref})) {
    Carp::croak("PerfQuerySpec: The first argument for the constructor must be an entity");
    return undef;
  }
  if( ref($args{'metricId'}) ne 'ARRAY') {
    Carp::croak("PerfQuerySpec: The second argument for the constructor must be a PerfMetricId and is a " . ref($args{'metricId'}));
    return undef;
  }
  if( $args{'format'} eq '') {
    Carp::croak("PerfQuerySpec: The third argument for the constructor must be a format");
    return undef;
  }
  if( $args{'intervalId'} eq '') {
    Carp::croak("PerfQuerySpec: The third argument for the constructor must be a intervalId");
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
  return sprintf "'%s' with entity->name='%s', #metricIds='%s', format='%s', intervalId='%s'", ref($self), $self->{_entity}->{view}->{name}, $#${$self->{_metricId}}, $self->{_format}, $self->{_intervalId};
}

1;

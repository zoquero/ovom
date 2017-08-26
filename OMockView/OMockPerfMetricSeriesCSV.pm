package OMockView::OMockPerfMetricSeriesCSV;

use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

#
# bless( {
#          'value' => '42,83,...',
#          'id' => bless( {
#                           'instance' => '',
#                           'counterId' => '2'
#                         }, 'PerfMetricId' )
#        }, 'PerfMetricSeriesCSV' ),
#
sub new {
  my ($class, %args) = @_;

  if(! defined ($args{'value'}) || ! defined ($args{'id'})) {
    Carp::croak("The constructor needs a hash of args");
    return undef;
  }

  if(ref($args{'value'}) ne '') {
    Carp::croak("args{value} must be a string with values "
              . "in constructor of OMockPerfMetricSeriesCSV");
    return undef;
  }
  if($args{'value'} eq '') {
    Carp::croak("empty args{value} in constructor of OMockPerfMetricSeriesCSV");
    return undef;
  }

  if( ref($args{'id'}) ne 'PerfMetricId'
   && ref($args{'id'}) ne 'OMockView::OMockPerfMetricId' ) {
    Carp::croak("args{id} is not a PerfMetricId in constructor "
              . "of OMockPerfMetricSeriesCSV");
    return undef;
  }

  my $self = bless {
    _value => $args{'value'},
    _id    => $args{'id'},    # PerfMetricId
  }, $class;
  return $self;
}

sub value {
  my ($self) = @_;
  return $self->{_value};
}

sub id {
  my ($self) = @_;
  return $self->{_id};
}

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' {value='%s...',id->instance='%s',id->counterId='%s'}",
                 ref($self),
                 substr($self->{_value}, 0, 10),
                 $self->{_id}->{_value},
                 $self->{_id}->{_counterId};
}

1;

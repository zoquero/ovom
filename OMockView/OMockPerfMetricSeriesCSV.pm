package OMockView::OMockPerfMetricSeriesCSV;

use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

sub new {
  my ($class, %args) = @_;

  if(! defined ($args{'value'}) || ! defined ($args{'id'})) {
    Carp::croak("The constructor needs a hash of args");
    return undef;
  }

  if( ref($args{'id'}) ne 'PerfMetricId'
   && ref($args{'id'}) ne 'OMockView::OMockPerfMetricId' ) {
    Carp::croak("The constructor of OMockPerfMetricSeriesCSV needs a ref to a PerfMetricId as second argument");
    return undef;
  }

# bless( {
#          'value' => '42,83,...',
#          'id' => bless( {
#                           'instance' => '',
#                           'counterId' => '2'
#                         }, 'PerfMetricId' )
#        }, 'PerfMetricSeriesCSV' ),

  my $self = bless {
    _value => $args{'value'},
    _id    => $args{'id'},    # PerfMetricId
  }, $class;
  return $self;
}

# sub instance {
#   my ($self) = @_;
#   return $self->{_instance};
# }

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' {value='%s...',id->instance='%s',id->counterId='%s'}",
                 ref($self),
                 substr($self->{_value}, 0, 10),
                 $self->{_id}->{_value},
                 $self->{_id}->{_counterId};
}

1;

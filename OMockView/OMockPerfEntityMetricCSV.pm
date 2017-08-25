package OMockView::OMockPerfEntityMetricCSV;

use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

sub new {
  my ($class, %args) = @_;

  if(! defined ($args{'sampleInfoCSV'}) || ! defined ($args{'value'})
  || ! defined ($args{'entity'})) {
    Carp::croak("The constructor needs a hash of args");
    return undef;
  }

# $VAR1 = [
#           bless( {
#                    'sampleInfoCSV' => '20,2017-08-25T06:17:20Z,20,2017-08-25T06:17:40Z...',
#                    'value' => [
#                                 bless( {
#                                          'value' => '42,83,...',
#                                          'id' => bless( {
#                                                           'instance' => '',
#                                                           'counterId' => '2'
#                                                         }, 'PerfMetricId' )
#                                        }, 'PerfMetricSeriesCSV' ),
#                                 bless( {
#                                          'id' => bless( {
#                                                           'instance' => '',
#                                                           'counterId' => '6'
#                                                         }, 'PerfMetricId' ),
#                                          'value' => '38,76,...'
#                                        }, 'PerfMetricSeriesCSV' ),
#                                 ...
#                               ],
#                    'entity' => bless( {
#                                         'type' => 'VirtualMachine',
#                                         'value' => 'vm-17xxx'
#                                       }, 'ManagedObjectReference' )
#                  }, 'PerfEntityMetricCSV' )
#         ];

  my $self = bless {
    _sampleInfoCSV      => $args{'sampleInfoCSV'},
    _value    => $args{'value'},
    _entity      => $args{'entity'},
  }, $class;
  return $self;
}

# sub instance {
#   my ($self) = @_;
#   return $self->{_instance};
# }

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' {sampleInfoCSV='%s...',#value='%s',entity_mo_ref='%s'}",
                 ref($self),
                 substr($self->{_sampleInfoCSV}, 0, 10),
                 $#${$self->{_value}},
                 $self->{_entity}->{'mo_ref'};
}

1;

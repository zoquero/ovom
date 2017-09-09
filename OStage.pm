package OStage;
use strict;
use warnings;
use Carp;
use POSIX qw/strftime/;
use Scalar::Util qw(looks_like_number);
use overload
    '""' => 'stringify';
use OStageDescriptor;


#
# Class representing the perfData from each stage of each metric
#
# @field descriptor    : OStageDescriptor object describing the stage
# @field numPoints     : How many points does it contain
# @field timestamps    : ref to array of timestamps it contain
# @field values        : ref to array of the corresponding values to timestamps
# @field timestamp     : Handy short cut to the initial timestamp
# @field lastTimestamp : Handy short cut to the last timestamp
# @field filename      : Filename from which those values were parsed
#

our $csvSep = ";";

#
# Constructor with args hash
#
# Default values that mean 'stage without data perf file'
# * values        == [];
# * timestamp     == -1;
# * timestamps    == [];
# * lastTimestamp == -1;
#
# $arg ref to hash containing all the arguments:
#
# $arg->{descriptor}    : OStageDescriptor object describing the stage
# $arg->{numPoints}     : How many points does it contain
# $arg->{timestamps}    : ref to array of timestamps it contain
# $arg->{values}        : ref to array of the corresponding values to timestamps
# $arg->{timestamp}     : Handy short cut to the initial timestamp
# $arg->{lastTimestamp} : Handy short cut to the last timestamp
# $arg->{filename}      : Filename from which those values were parsed
#
sub new {
  my ($class, $args) = @_;

  # Preconditions
  if (! defined($args)) {
    Carp::croak("OStage constructor requires args");
    return undef;
  }

  if (! defined($args->{'descriptor'})) {
    Carp::croak("args{'descriptor'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'numPoints'})) {
    Carp::croak("args{'numPoints'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'timestamps'})) {
    Carp::croak("args{'timestamps'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'values'})) {
    Carp::croak("args{'values'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'timestamp'})) {
    Carp::croak("args{'timestamp'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'lastTimestamp'})) {
    Carp::croak("args{'lastTimestamp'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (! defined($args->{'filename'})) {
    Carp::croak("args{'filename'} isn't defined "
              . "at OStage constructor");
    return undef;
  }

  if (ref($args->{'descriptor'}) ne 'OStageDescriptor') {
    Carp::croak("args{'descriptor'} must be an array of OStageDescriptor "
              . "at OStage constructor, it's a " . ref($args->{'descriptor'}));
    return undef;
  }

  if (! looks_like_number($args->{'numPoints'})) {
    Carp::croak("args{'numPoints'} must be a number "
              . "at OStage constructor");
    return undef;
  }

  if (ref($args->{'timestamps'}) ne 'ARRAY') {
    Carp::croak("args{'timestamps'} must be an array of primitive values "
              . "at OStage constructor, it's a " . ref($args->{'timestamps'}));
    return undef;
  }

  if (ref($args->{'values'}) ne 'ARRAY') {
    Carp::croak("args{'values'} must be an array of primitive values "
              . "at OStage constructor, it's a " . ref($args->{'values'}));
    return undef;
  }

  if (! looks_like_number($args->{'timestamp'})) {
    Carp::croak("args{'timestamp'} must be a number "
              . "at OStageconstructor");
    return undef;
  }

  if (! looks_like_number($args->{'lastTimestamp'})) {
    Carp::croak("args{'lastTimestamp'} must be a number "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if ($args->{'filename'} eq '') {
    Carp::croak("args{'filename'} is empty "
              . "at OStageDescriptor constructor");
    return undef;
  }

  # Let's create:
  my $self = bless {
    descriptor       => $args->{'descriptor'},
    numPoints        => $args->{'numPoints'},
    timestamps       => $args->{'timestamps'},
    values           => $args->{'values'},
    timestamp        => $args->{'timestamp'},
    lastTimestamp    => $args->{'lastTimestamp'},
    filename         => $args->{'filename'},
  }, $class;
  return $self;
}

sub stringify {
  my ($self) = @_;

  my $dateStrI = strftime("%Y%m%d_%H%M%S",gmtime($self->{timestamp}));
  my $dateStrF = strftime("%Y%m%d_%H%M%S",gmtime($self->{lastTimestamp}));

  return sprintf "Stage called '%s' with %d values, initial timestamp=%s (%s), "
                . "last timestamp=%s (%s), "
                . "samplePeriod=%ss, duration=%ss and with filename '%s'",
                  $self->{descriptor}->{name}, ($#{$self->{values}} + 1),
                  $self->{timestamp},     $dateStrI,
                  $self->{lastTimestamp}, $dateStrF,
                  $self->{descriptor}->{samplePeriod},
                  $self->{descriptor}->{duration}, $self->{filename};
}

1;

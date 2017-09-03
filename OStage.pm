package OStage;
use strict;
use warnings;
use Carp;
use POSIX qw/strftime/;
use Scalar::Util qw(looks_like_number);
use overload
    '""' => 'stringify';
use OStageDescriptor;


our $csvSep = ";";

#
# Constructor with args hash
#
# Notes:
# * values        == []; # means 'stage without data perf file'
# * timestamp     == -1; # means 'stage without data perf file'
# * lastTimestamp == -1; # means 'stage without data perf file'
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

  if (ref($args->{'values'}) ne 'ARRAY') {
    Carp::croak("args{'values'} must be an array of primitive values "
              . "at OStage constructor, it's a " . ref($args->{'values'}));
    return undef;
  }

  if (! looks_like_number($args->{'timestamp'})) {
    Carp::croak("args{'timestamp'} must be a number "
              . "at OStageDescriptor constructor");
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

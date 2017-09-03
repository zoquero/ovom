package OStageDescriptor;
use strict;
use warnings;
use Carp;
use Scalar::Util qw(looks_like_number);
use overload
    '""' => 'stringify';

our $csvSep = ";";

#
# Constructor with args hash
#
sub new {
  my ($class, $args) = @_;

  # Preconditions
  if (! defined($args)) {
    Carp::croak("OStageDescriptor constructor requires args");
    return undef;
  }

  if (! defined($args->{'name'})) {
    Carp::croak("args{'name'} isn't defined "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if ($args->{'name'} eq '') {
    Carp::croak("args{'name'} is empty "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if (! defined($args->{'samplePeriod'})) {
    Carp::croak("args{'samplePeriod'} isn't defined "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if (! looks_like_number($args->{'samplePeriod'})) {
    Carp::croak("args{'samplePeriod'} must be a number "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if ( $args->{'samplePeriod'} <= 0) {
    Carp::croak("args{'samplePeriod'} must be a positive number "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if (! defined($args->{'duration'})) {
    Carp::croak("args{'duration'} isn't defined "
              . "at OStageDescriptor constructor");
    return undef;
  }

  if (! looks_like_number($args->{'duration'})) {
    Carp::croak("args{'duration'} must be a number "
              . "at OStageDescriptor constructor");
    return undef;
  }

  # Let's create:
  my $self = bless {
    name         => $args->{'name'},
    samplePeriod => $args->{'samplePeriod'},
    duration     => $args->{'duration'},
  }, $class;
  return $self;
}

sub stringify {
    my ($self) = @_;

#   my $dateStr = strftime("%Y-%m-%d %H:%M:%S",gmtime($self->{timestamp}));
#   return sprintf "Stage with '%d' values, initial timesamp='%s' ('%s'), "
#                 . "samplePeriod='%s's, duration='%s's and with filename '%s'",
#                   $#{$self->{values}}, $self->{timestamp}, $dateStr,
#                   $self->{samplePeriod}, $self->{duration}, $self->{filename};

    return sprintf "Stage with name '%s', samplePeriod=%ss and duration=%ss",
                    $self->{name}, $self->{samplePeriod}, $self->{duration};
}

1;

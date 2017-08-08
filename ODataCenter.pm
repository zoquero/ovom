package ODataCenter;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  my $self = bless {
    view            => $view,
    name            => undef,
    mo_ref          => undef,
    parent          => undef,
    datastoreFolder => undef,
    vmFolder        => undef,
    hostFolder      => undef,
    networkFolder   => undef,
  }, $class;
  Carp::croack("The constructor requires a View") unless (defined($view));
  $self->_init($view);
  return $self;
}

#
# Initializes fields from the view.
#
sub _init {
  my ($self, $view) = @_;
  my $parent;
#  if (defined($self->{view}->parent) && defined($self->{view}->parent->{value})) {
#    $parent = $self->{view}->parent->{value};
#  }
#  else {
#    $parent = undef;
#  }
  $self->{name}            = $self->{view}->{name};
  $self->{mo_ref}          = $self->{view}->{mo_ref}{value};
  $self->{parent}          = $self->{view}->{parent}->{value};
  $self->{datastoreFolder} = $self->{view}->{datastoreFolder}->{value};
  $self->{vmFolder}        = $self->{view}->{vmFolder}->{value};
  $self->{hostFolder}      = $self->{view}->{hostFolder}->{value};
  $self->{networkFolder}   = $self->{view}->{networkFolder}->{value};
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}            . $csvSep;
  $csvRow   .= $self->{mo_ref}          . $csvSep;
  $csvRow   .= $self->{parent}          . $csvSep;
  $csvRow   .= $self->{datastoreFolder} . $csvSep;
  $csvRow   .= $self->{vmFolder}        . $csvSep;
  $csvRow   .= $self->{hostFolder}      . $csvSep;
  $csvRow   .= $self->{networkFolder}            ;
  return $csvRow;
}

1;

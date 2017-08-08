package OFolder;
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
  $self->{name}            = $self->{view}->{name};
  $self->{mo_ref}          = $self->{view}->{mo_ref}{value};
  ##
  ## The root folder "Datacenters" hasn't parent
  ##
  if (defined($self->{view}->{parent}) && defined($self->{view}->{parent}->{value})) {
    $self->{parent}        = $self->{view}->{parent}->{value};
  }
  else {
    $self->{parent}        = '__NO_PARENT__';
  }
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}            . $csvSep;
  $csvRow   .= $self->{mo_ref}          . $csvSep;
  $csvRow   .= $self->{parent}          . $csvSep;
  return $csvRow;
}

1;

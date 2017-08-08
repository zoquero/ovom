package OHost;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  Carp::croack("OHost constructor requires a View") unless (defined($view));
  my $self = bless {
    view   => $view,
    name   => $view->{name},
    mo_ref => $view->{mo_ref}{value},
    parent => $view->{parent}->{value},
  }, $class;
  return $self;
}

#
# Initializes fields from the view.
#
sub _init {
  my ($self, $view) = @_;
  $self->{name}   = $self->{view}->{name};
  $self->{mo_ref} = $self->{view}->{mo_ref}{value};
  $self->{parent} = $self->{view}->{parent}->{value};
}

sub toCsvRow {
  my $self   = shift;
  my $csvRow = $self->{name}   . $csvSep;
  $csvRow   .= $self->{mo_ref} . $csvSep;
  $csvRow   .= $self->{parent};
  return $csvRow;
}

1;

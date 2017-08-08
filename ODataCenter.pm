package ODataCenter;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  Carp::croack("ODataCenter constructor requires a View") unless (defined($view));
  my $self = bless {
    view            => $view,
    name            => $view->{name},
    mo_ref          => $view->{mo_ref}{value},
    parent          => $view->{parent}->{value},
    datastoreFolder => $view->{datastoreFolder}->{value},
    vmFolder        => $view->{vmFolder}->{value},
    hostFolder      => $view->{hostFolder}->{value},
    networkFolder   => $view->{networkFolder}->{value},
  }, $class;
  return $self;
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

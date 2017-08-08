package OFolder;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  Carp::croack("OFolder constructor requires a View") unless (defined($view));
  my $self = bless {
    view            => $view,
    name            => $view->{name},
    mo_ref          => $view->{mo_ref}{value},
    ##
    ## The root folder "Datacenters" hasn't parent
    ##
    parent          => defined($view->{parent}->{value}) ?
                               $view->{parent}->{value} : undef,
  }, $class;
  return $self;
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}   . $csvSep;
  $csvRow   .= $self->{mo_ref} . $csvSep;
  $csvRow   .= defined($self->{parent}) ? $self->{parent} : '';
  return $csvRow;
}

1;

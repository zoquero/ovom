package OVirtualMachine;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  Carp::croack("OVirtualMachine constructor requires a View") unless (defined($view));
  my $self = bless {
    view            => $view,
    name            => $view->{name},
    mo_ref          => $view->{mo_ref}->{value},
    parent          => $view->{parent}->{value},
  }, $class;
  return $self;
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}    . $csvSep;
  $csvRow   .= $self->{mo_ref}  . $csvSep;
  $csvRow   .= $self->{parent};
  return $csvRow;
}

1;

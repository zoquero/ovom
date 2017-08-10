package ODataCenter;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $args) = @_;
  Carp::croack("ODataCenter constructor requires a View")
    unless (defined($args) && $#$args > 1);
  my $self = bless {
    id              => undef,
    oclass_name     => 'ODataCenter',
    view            => undef,
    name            => shift @$args,
    mo_ref          => shift @$args,
    parent          => shift @$args,
    datastoreFolder => shift @$args,
    vmFolder        => shift @$args,
    hostFolder      => shift @$args,
    networkFolder   => shift @$args,
  }, $class;
  return $self;
}

#
# Just like 'new' but adding a first component with the id in the args
#
sub newWithId {
  my ($class, $args) = @_;
  Carp::croack("ODataCenter constructor requires a View")
    unless (defined($args) && $#$args > 1);
  my $self = bless {
    id              => shift @$args,
    oclass_name     => 'ODataCenter',
    view            => undef,
    name            => shift @$args,
    mo_ref          => shift @$args,
    parent          => shift @$args,
    datastoreFolder => shift @$args,
    vmFolder        => shift @$args,
    hostFolder      => shift @$args,
    networkFolder   => shift @$args,
  }, $class;
  return $self;
}

sub newFromView {
  my ($class, $view) = @_;
  Carp::croack("ODataCenter constructor requires a View") unless (defined($view));
  my $self = bless {
    id              => undef,
    oclass_name     => 'ODataCenter',
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

#
# Compare this object with other object of the same type
#
# @arg reference to the other object of the same type
# @return 1 (if equal), 0 (if different but equal mo_ref), -1 if different, -2 if error
#
sub compare {
  my $self  = shift;
  my $other = shift;
  if(! defined($other)) {
    Carp::croack("Compare requires other entity of the same type as argument");
    return -2;
  }
  if( !defined($other->{name}) || !defined($other->{parent}) || !defined($other->{mo_ref})) {
    Carp::croack("compare: The argument doesn't look like an entity");
    return -2;
  }
  elsif ( $self->{mo_ref} ne $other->{mo_ref} ) {
    # Different folder (mo_ref differs)
    return -1;
  }
  elsif ( $self->{name}    ne $other->{name}
       || $self->{parent}  ne $other->{parent} ) {
    # Same folder (equal mo_ref), but name or parent has changed
    return 0;
  }
  else {
    # Equal object
    return 1;
  }
}

1;

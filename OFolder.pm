package OFolder;
use strict;
use warnings;
use Carp;

our $csvSep = ";";

sub new {
  my ($class, $args) = @_;
  Carp::croack("OFolder constructor requires args")
    unless (defined($args) && $#$args > 1);
  my $self = bless {
    view            => undef,
    name            => shift @$args,
    mo_ref          => shift @$args,
    parent          => shift @$args,
    enabled         => shift @$args,
  }, $class;
  return $self;
}


sub newFromView {
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
    enabled         => 1,
  }, $class;
  return $self;
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}                                     . $csvSep;
  $csvRow   .= $self->{mo_ref}                                   . $csvSep;
  $csvRow   .= (defined($self->{parent}) ? $self->{parent} : '') . $csvSep;
  $csvRow   .= $self->{enabled};
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
    Carp::croack("Compare requires other entity as argument");
    return -2;
  }
  if( !defined($other->{name}) || !defined($other->{parent}) || !defined($other->{mo_ref}) || !defined($other->{enabled})) {
    Carp::croack("The argument doesn't look like an entity in 'compare'");
    return -2;
  }
  if ( $self->{mo_ref} ne $other->{mo_ref} ) {
    # Different folder (mo_ref differs)
    return -1;
  }
  if ( $self->{name}    ne $other->{name}
    || $self->{parent}  ne $other->{parent}
    || $self->{enabled} ne $other->{enabled} ) {
    # Same folder (equal mo_ref), but name or parent has changed
    return 0;
  }
  # Equal object
  return 1;
}

1;

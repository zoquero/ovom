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
    id              => undef,
    oclass_name     => 'OFolder',
    view            => undef,
    name            => shift @$args,
    mo_ref          => shift @$args,
    parent          => shift @$args,
  }, $class;
  return $self;
}


#
# Just like 'new' but adding a first component with the id in the args
#
sub newWithId {
  my ($class, $args) = @_;
  Carp::croack("OFolder constructor requires args")
    unless (defined($args) && $#$args > 1);
  my $self = bless {
    id              => shift @$args,
    oclass_name     => 'OFolder',
    view            => undef,
    name            => shift @$args,
    mo_ref          => shift @$args,
    parent          => shift @$args,
  }, $class;
  return $self;
}


sub newFromView {
  my ($class, $view) = @_;
  Carp::croack("OFolder constructor requires a View") unless (defined($view));
  my $self = bless {
    id              => undef,
    oclass_name     => 'OFolder',
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
  my $csvRow = $self->{name}                                     . $csvSep;
  $csvRow   .= $self->{mo_ref}                                   . $csvSep;
  $csvRow   .= (defined($self->{parent}) ? $self->{parent} : '');
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
  if( !defined($other->{name}) || !defined($other->{parent}) || !defined($other->{mo_ref})) {
    Carp::croack("The argument doesn't look like an entity in 'compare'");
    return -2;
  }
  elsif ( $self->{mo_ref} ne $other->{mo_ref} ) {
    # Different folder (mo_ref differs)
    return -1;
  }
  elsif ( ( $self->{name}    eq $other->{name}
         && $self->{name}    eq 'Datacenters' )
       && ( $self->{parent}  eq '' 
         && $other->{parent} eq 'group-d1' )) {
    #
    # It's the special root folder that has:
    # name   == 'Datacenters'
    # mo_ref == 'group-d1'
    # parent == ''
    #
    # So, it's the same object.
    #
    return 1;
  }
  elsif ( $self->{name}    ne $other->{name}
       || $self->{parent}  ne $other->{parent} ) {
    # Same folder (equal mo_ref), but name or parent has changed
    return 0;
  }
  elsif ($self->{parent} eq '') {
    # Same folder (equal mo_ref), but name or parent has changed
    Carp::croack("vCenter shows a Folder with empty parent "
               . "and doesn't look like to be the root");
    return -2;
  }
  else {
    # Equal object
    return 1;
  }
}

1;

package OFolder;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

our $csvSep = ";";

#
# Constructor with args array
#
sub new {
  my ($class, $args) = @_;

  # Preconditions
  Carp::croak("OFolder constructor requires args")
    if (! defined($args) || $#$args < 0);

  my $a = { 'id'     => shift @$args,
            'name'   => shift @$args,
            'mo_ref' => shift @$args,
            'parent' => shift @$args };
  return OFolder->newWithArgsHash($a);
}

#
# Constructor that creates from a ODatacenter.
#
sub cloneFromDatacenter {
  my ($class, $dc) = @_;

  # Preconditions
  Carp::croak("OFolder constructor requires args")
    if (! defined($dc));

  Carp::croak("OFolder constructor requires args")
    if(ref($dc) ne 'ODatacenter');

  my $a = { 'id'     => undef,
            'name'   => $dc->{name},
            'mo_ref' => $dc->{mo_ref},
            'parent' => $dc->{parent} };
  return OFolder->newWithArgsHash($a);
}

#
# Constructor that creates from a OCluster.
#
sub cloneFromCluster {
  my ($class, $cluster) = @_;

  # Preconditions
  Carp::croak("OFolder constructor requires args")
    if (! defined($cluster));

  Carp::croak("OFolder constructor requires args")
    if(ref($cluster) ne 'OCluster');

  my $a = { 'id'     => undef,
            'name'   => $cluster->{name},
            'mo_ref' => $cluster->{mo_ref},
            'parent' => $cluster->{parent} };
  return OFolder->newWithArgsHash($a);
}

#
# Constructor with args hash
#
sub newWithArgsHash {
  my ($class, $args) = @_;

  # Preconditions
  Carp::croak("OFolder constructor requires args")
    if (! defined($args));
  Carp::croak("args{'name'} isn't defined at OFolder constructor")
    if (! defined($args->{'name'}));
  Carp::croak("args{'mo_ref'} isn't defined at OFolder constructor")
    if (! defined($args->{'mo_ref'}));

  my $self = bless {
    id              => $args->{'id'},
    view            => undef,
    name            => $args->{'name'},
    mo_ref          => $args->{'mo_ref'},
    parent          => $args->{'parent'},
  }, $class;
  return $self;
}

#
# Constructor with view
#
sub newFromView {
  my ($class, $view) = @_;

  Carp::croak("OFolder constructor requires a View")
    if (! defined($view));

  my $a = { 'id'     => undef,
            'name'   => $view->{name},
            'mo_ref' => $view->{mo_ref}{value},
            ##
            ## The root Folder hasn't parent
            ##
            'parent' => defined($view->{parent}->{value}) ?
                                $view->{parent}->{value}  : undef, };
  return OFolder->newWithArgsHash($a);
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
# @return  1 (if equal),
#          0 (if different but equal mo_ref),
#         -1 if different,
#         -2 if error
#
sub compare {
  my $self  = shift;
  my $other = shift;
  if(! defined($other)) {
    Carp::croak("Compare requires other entity as argument");
    return -2;
  }
  if(ref($self) ne ref($other)) {
    Carp::croak("Compare requires a entity of the same type as argument");
    return -2;
  }

  if( !defined($other->{name})
   || !defined($other->{parent})
   || !defined($other->{mo_ref})) {
    Carp::croak("The argument doesn't look like an entity in 'compare'");
    return -2;
  }
  elsif ( $self->{mo_ref} ne $other->{mo_ref} ) {
    # Different folder (mo_ref differs)
    return -1;
  }
  elsif ( ( $self->{name} eq $other->{name}
         && $self->{name} eq $OInventory::configuration{'root_folder.name'} )
       && ( ( ! defined($self->{parent}) || $self->{parent}  eq '' )
         && $other->{parent} eq $OInventory::configuration{'root_folder.mo_ref'} )) {
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
    Carp::croak("vCenter shows a Folder with empty parent "
               . "and doesn't look like to be the root");
    return -2;
  }
  else {
    # Equal object
    return 1;
  }
}


sub stringify {
    my ($self) = @_;
    return sprintf "Folder with name='%s' and mo_ref='%s'", $self->{name}, $self->{mo_ref};
}

1;

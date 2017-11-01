package OVirtualMachine;
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
  Carp::croak("OVirtualMachine constructor requires args")
    if (! defined($args) || $#$args < 0);

  my $a = { 'id'              => shift @$args,
            'name'            => shift @$args,
            'mo_ref'          => shift @$args,
            'parent'          => shift @$args,
            'view'            => undef,
            'hostFolder'      => shift @$args };
  return OVirtualMachine->newWithArgsHash($a);
}

#
# Constructor with args hash
#
sub newWithArgsHash {
  my ($class, $args) = @_;

  # Preconditions
  Carp::croak("OVirtualMachine constructor requires a View")
    if (! defined($args));
  Carp::croak("args{'name'} isn't defined at OVirtualMachine constructor")
    if (! defined($args->{'name'}));
  Carp::croak("args{'mo_ref'} isn't defined at OVirtualMachine constructor")
    if (! defined($args->{'mo_ref'}));

  my $self = bless {
    id              => $args->{'id'},
#   view            => undef,
    name            => $args->{'name'},
    mo_ref          => $args->{'mo_ref'},
    parent          => $args->{'parent'},
    view            => $args->{'view'},
  }, $class;
  return $self;
}

#
# Constructor with view
#
sub newFromView {
  my ($class, $view) = @_;
  
  Carp::croak("OVirtualMachine constructor requires a View")
    if (! defined($view));

  my $a = { 'id'              => undef,
            'name'            => $view->{name},
            'mo_ref'          => $view->{mo_ref}{value},
            'parent'          => $view->{parent}->{value},
            'view'            => $view
  };
  return OVirtualMachine->newWithArgsHash($a);
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{name}            . $csvSep;
  $csvRow   .= $self->{mo_ref}          . $csvSep;
  $csvRow   .= $self->{parent}                   ;
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
    Carp::croak("Compare requires other entity of the same type as argument");
    return -2;
  }
  if(ref($self) ne ref($other)) {
    Carp::croak("Compare requires a entity of the same type as argument");
    return -2;
  }
  if( !defined($other->{name}) 
   || !defined($other->{parent}) 
   || !defined($other->{mo_ref})) {
    Carp::croak("compare: The argument doesn't look like an entity");
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
 
sub stringify {
    my ($self) = @_;
    return sprintf "VM with name='%s' and mo_ref='%s'", $self->{name}, $self->{mo_ref};
}

1;

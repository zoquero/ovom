package DataCenter;

our $csvSep = ";";

sub new {
  my ($class, $view) = @_;
  my $self = bless {
    view            => $view,
    name            => '',
    mo_ref          => '',
    parent          => '',
    datastoreFolder => '',
    vmFolder        => '',
    hostFolder      => '',
    networkFolder   => '',
  }, $class;
  die "The constructor of DataCenter requires a View" if(! defined($view));

  $self->_init($args);
  return $self;
}

sub _init {
  my ($self, $args) = @_;
  $self->{name}   = $self->{view}->name;
  $self->{mo_ref} = $self->{view}->{'mo_ref'}{'value'};
  $self->{parent} = $self->{view}->parent->{'value'};
  $self->{datastoreFolder} = $self->{view}->datastoreFolder->{'value'};
  $self->{vmFolder}        = $self->{view}->vmFolder->{'value'};
  $self->{hostFolder}      = $self->{view}->hostFolder->{'value'};
  $self->{networkFolder}   = $self->{view}->networkFolder->{'value'};
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

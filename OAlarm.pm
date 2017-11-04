package OAlarm;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use overload
    '""' => 'stringify';

our $csvSep = ";";

#
# Constructor with args array
#
sub new {
  my ($class, $args) = @_;

  # Preconditions
  Carp::croak("Alarm constructor requires args")
    if (! defined($args) || $#$args < 0);

  my $a = { 'id'               => shift @$args,
            'entity_type'      => shift @$args,
            'mo_ref'           => shift @$args,
            'is_critical'      => shift @$args,
            'perf_metric_id'   => shift @$args,
            'is_acknowledged'  => shift @$args,
            'is_active'        => shift @$args,
            'alarm_time'       => shift @$args,
            'last_change'      => shift @$args };
  return Alarm->newWithArgsHash($a);
}

#
# Constructor with args hash
#
sub newWithArgsHash {
  my ($class, $args) = @_;

  # Preconditions
  Carp::croak("Alarm constructor requires args")
    if (! defined($args));
  Carp::croak("args{'entity_type'} isn't defined at Alarm constructor")
    if (! defined($args->{'entity_type'}));
  Carp::croak("args{'mo_ref'} isn't defined at Alarm constructor")
    if (! defined($args->{'mo_ref'}));
  Carp::croak("args{'is_critical'} isn't defined at Alarm constructor")
    if (! defined($args->{'is_critical'}));
  Carp::croak("args{'perf_metric_id'} isn't defined at Alarm constructor")
    if (! defined($args->{'perf_metric_id'}));
  Carp::croak("args{'is_acknowledged'} isn't defined at Alarm constructor")
    if (! defined($args->{'is_acknowledged'}));
  Carp::croak("args{'is_active'} isn't defined at Alarm constructor")
    if (! defined($args->{'is_active'}));
  Carp::croak("args{'alarm_time'} isn't defined at Alarm constructor")
    if (! defined($args->{'alarm_time'}));
# Carp::croak("args{'last_change'} isn't defined at Alarm constructor")
#   if (! defined($args->{'last_change'}));

  my $self = bless {
    id              => $args->{'id'},
    entity_type     => $args->{'entity_type'},
    mo_ref          => $args->{'mo_ref'},
    is_critical     => $args->{'is_critical'},     # 1 crit , 0 warn
    perf_metric_id  => $args->{'perf_metric_id'},
    is_acknowledged => $args->{'is_acknowledged'}, # 1 acknowledged , 0 not
    is_active       => $args->{'is_active'},       # 1 acknowledged , 0 not
    alarm_time      => $args->{'alarm_time'},
    last_change     => $args->{'last_chang'},
  }, $class;
  return $self;
}

sub id {
  my ($self) = @_;
  return $self->{id};
}
sub entity_type {
  my ($self) = @_;
  return $self->{entity_type};
}
sub mo_ref {
  my ($self) = @_;
  return $self->{mo_ref};
}
sub is_critical {
  my ($self) = @_;
  return $self->{is_critical};
}
sub perf_metric_id {
  my ($self) = @_;
  return $self->{perf_metric_id};
}
sub is_acknowledged {
  my ($self) = @_;
  return $self->{is_acknowledged};
}
sub is_active {
  my ($self) = @_;
  return $self->{is_active};
}
sub alarm_time {
  my ($self) = @_;
  return $self->{alarm_time};
}
sub last_change {
  my ($self) = @_;
  return $self->{last_change};
}

#
# Usefull alias
#
sub value {
  my ($self) = @_;
  return $self->{mo_ref};
}

sub setId {
  my ($self, $id) = @_;
  $self->{id} = $id;
}


sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{id}              . $csvSep;
  $csvRow   .= $self->{entity_type}     . $csvSep;
  $csvRow   .= $self->{mo_ref}          . $csvSep;
  $csvRow   .= $self->{is_critical}     . $csvSep;
  $csvRow   .= $self->{perf_metric_id}  . $csvSep;
  $csvRow   .= $self->{is_acknowledged} . $csvSep;
  $csvRow   .= $self->{is_active}       . $csvSep;
  $csvRow   .= $self->{alarm_time}      . $csvSep;
  $csvRow   .= $self->{last_change};
  return $csvRow;
}

sub stringify {
  my ($self) = @_;
  my $id;
  my $warnOrCrit;
  my $isActive;
  my $isAcknowledged;
  my $lastChange;

  if(defined($self->{id})) {
    $id = $self->{id};
  }
  else {
    $id = 'undef';
  }
  if($self->{is_critical}) {
    $warnOrCrit = 'Critical';
  }
  else {
    $warnOrCrit = 'Warning';
  }
  if($self->{is_active}) {
    $isActive = 'active';
  }
  else {
    $isActive = 'non-active';
  }
  if($self->{is_acknowledged}) {
    $isAcknowledged = 'acknowledged';
  }
  else {
    $isAcknowledged = 'non-acknowledged';
  }
  if(defined($self->{last_change})) {
    $lastChange = $self->{last_change};
  }
  else {
    $lastChange = 'undef';
  }

  return sprintf "%s alarm with id '%s' from the '%s' with mo_ref='%s' that's '%s' from the PerfMetricId '%s' that is '%s', that was triggered on '%s' and changed from the last time in '%s'", $id, $warnOrCrit, $self->{entity_type}, $self->{mo_ref}, $isActive, $self->{perf_metric_id}, $isAcknowledged, $self->{alarm_time}, $lastChange;
}

1;

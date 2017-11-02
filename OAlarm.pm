package OAlarm;
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
  Carp::croak("Alarm constructor requires args")
    if (! defined($args) || $#$args < 0);

  my $a = { 'id'               => shift @$args,
            'entity_type'      => shift @$args,
            'entity_moref'     => shift @$args,
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
  Carp::croak("args{'entity_moref'} isn't defined at Alarm constructor")
    if (! defined($args->{'entity_moref'}));
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
    entity_moref    => $args->{'entity_moref'},
    is_critical     => $args->{'is_critical'},     # 1 crit , 0 warn
    perf_metric_id  => $args->{'perf_metric_id'},
    is_acknowledged => $args->{'is_acknowledged'}, # 1 acknowledged , 0 not
    is_active       => $args->{'is_active'},       # 1 acknowledged , 0 not
    alarm_time      => $args->{'alarm_time'},
    last_change     => $args->{'last_chang'},
  }, $class;
  return $self;
}

sub toCsvRow {
  my $self = shift;
  my $csvRow = $self->{id}              . $csvSep;
  $csvRow   .= $self->{entity_type}     . $csvSep;
  $csvRow   .= $self->{entity_moref}    . $csvSep;
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
  my $warnOrCrit;
  my $isActive;
  my $isAcknowledged;

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

  return sprintf "%s alarm from the '%s' with mo_ref='%s' that's '%s' from the PerfMetricId '%s' that is '%s', that was triggered on '%s' and changed from the last time in '%s'", $warnOrCrit, $self->{entity_type}, $self->{mo_ref}, $isActive, $self->{perf_metric_id}, $isAcknowledged, $self->{alarm_time}, $self->{last_change};
}

1;

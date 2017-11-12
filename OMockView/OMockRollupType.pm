package OMockView::OMockRollupType;
use strict;
use warnings;
use Carp;
use overload
    '""' => 'stringify';

sub new {
  my ($class, $arg) = @_;

  if(! defined ($arg) || $arg eq '') {
    Carp::croak("The constructor needs the val");
    return undef;
  }

  my $self = bless {
    _val => $arg,
  }, $class;
  return $self;
} 

sub newFromPerfSummaryType {
  my ($class, $p) = @_;

  if(        ! defined ($p)
       || (    ref($p) ne 'PerfSummaryType'
            && ref($p) ne 'OMockView::OMockRollupType')) {
    Carp::croak("The constructor needs a RollupType and got a "
                . ref($p));
    return undef;
  }

  my $self = bless {
    _val => $p->val,
  }, $class;
  return $self;
}
    
sub val {    
  my ($self) = @_;
  return $self->{_val};
} 

sub stringify {
  my ($self) = @_;
  return sprintf "'%s' with val='%s'", ref($self), $self->{_val};
} 

1;

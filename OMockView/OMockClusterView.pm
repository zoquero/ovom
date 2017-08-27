package OMockView::OMockClusterView;
use strict;
use warnings;
use Carp;

# $view->{name};
# $view->{mo_ref}{value};
# $view->parent->{value};

sub new {
  my ($class, @args) = @_;
  my %mo_ref_hash = (value => $args[1]);
  my %parent_hash = (value => $args[2]);
  my $self = bless {
    name   => $args[0],
    mo_ref => \%mo_ref_hash,
    parent => \%parent_hash,
  }, $class;
  return $self;
}

#
# Added for compatibility with ManagedObjectReference->type
#
sub type {
  my ($self) = @_;
  return ref($self);
}

#
# Added for compatibility with ManagedObjectReference->type
#
sub value {
  my ($self) = @_;
  return $self->{mo_ref}->{value};
}

1;

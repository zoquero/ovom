package OMockHostView;
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

1;

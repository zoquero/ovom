package OMockView::OMockDatacenterView;
use strict;
use warnings;
use Carp;

# $view->{name};
# $view->{mo_ref}{value};
# $view->parent->{value};
# $view->datastoreFolder->{value};
# $view->vmFolder->{value};
# $view->hostFolder->{value};
# $view->networkFolder->{value};

sub new {
  my ($class, @args) = @_;
  my %mo_ref_hash          = (value => $args[1]);
  my %parent_hash          = (value => $args[2]);
  my %datastoreFolder_hash = (value => $args[3]);
  my %vmFolder_hash        = (value => $args[4]);
  my %hostFolder_hash      = (value => $args[5]);
  my %networkFolder_hash   = (value => $args[6]);

  my $self = bless {
    name            => $args[0],
    mo_ref          => \%mo_ref_hash,
    parent          => \%parent_hash,
    datastoreFolder => \%datastoreFolder_hash,
    vmFolder        => \%vmFolder_hash,
    hostFolder      => \%hostFolder_hash,
    networkFolder   => \%networkFolder_hash,
  }, $class;
  return $self;
}

1;

package OMockView::OMockPerfManager;
use strict;
use warnings;

sub new {
  my ($class, @args) = @_;
  my %mo_ref_hash = (value => undef);
  my $self = bless {
    mo_ref => \%mo_ref_hash,
  }, $class;
  return $self;
}

1;

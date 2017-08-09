package OvomDao;
use strict;
use warnings;

sub connect {
  OvomExtractor::log(1, "Successfully connected to database");
  return 0;
}


sub disconnect {
  OvomExtractor::log(1, "Successfully disconnected from database");
  return 0;
}

1;

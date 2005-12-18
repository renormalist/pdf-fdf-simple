#! perl -Tw

use Test::More;

if ($ENV{DO_DIST_CHECK}) {
  eval "use Test::Pod::Coverage";
  plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
  all_pod_coverage_ok();
} else {
  print STDERR 
  plan skip_all => 'Test::Pod::Coverage skipped unless env $DO_DIST_CHECK set.';
}

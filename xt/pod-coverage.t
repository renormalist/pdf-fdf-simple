#! perl -Tw

use Test::More;

eval "use Test::Pod::Coverage";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
plan tests => 2;
pod_coverage_ok( "PDF::FDF::Simple");
pod_coverage_ok( "PDF::FDF::Simple::Builder");

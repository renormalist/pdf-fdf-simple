### -*- mode: perl; -*-

use PDF::FDF::Simple;
use Test::More;
use Test::Deep;

use Data::Dumper;
use Parse::RecDescent;
use strict;
use warnings;

plan tests => 10;

################## tests ##################

# This real world file contains field 'Email' without a value
my $fdf_fname = 't/slashvalues1.fdf';
my $fdf_outname = "t/fdfparser_output2.fdf";

my $fdf1 = new PDF::FDF::Simple ({ filename => $fdf_fname });
my $erg1 = $fdf1->load;

is (
    $erg1->{'Nm'},
    'NAME',
    "1-Nm: NAME"
   );

is (
    $erg1->{'PurchaseCd'},
    'Yes',
    "1-PurchaseCd: Yes"
   );

is (
    $erg1->{'Header'},
    'Released 10/10/08.',
    "1-Header: Released 10/10/08."
   );

is (
    $erg1->{'DeliverPt'},
    'DILIVERY',
    "1-DeliverPt: DILIVERY"
   );

$fdf1->filename ($fdf_outname);
my $success = $fdf1->save;

my $fdf1x = new PDF::FDF::Simple ({ filename => $fdf_outname });
my $erg1x = $fdf1->load;
cmp_deeply($erg1, $erg1x, "1-write - read back - compare");

################## part 2 ##################

$fdf_fname = 't/slashvalues2.fdf';

my $fdf2 = new PDF::FDF::Simple ({ filename => $fdf_fname });
my $erg2 = $fdf2->load;

is (
    $erg2->{'Nm'},
    'NAME',
    "2-Nm: NAME"
   );

is (
    $erg2->{'PurchaseCd'},
    'Yes',
    "2-PurchaseCd: Yes"
   );

is (
    $erg2->{'Header'},
    'Released 10/10/08.',
    "2-Header: Released 10/10/08."
   );

is (
    $erg2->{'DeliverPt'},
    'DILIVERY',
    "2-DeliverPt: DILIVERY"
   );

$fdf2->filename ($fdf_outname);
$success = $fdf2->save;

my $fdf2x = new PDF::FDF::Simple ({ filename => $fdf_outname });
my $erg2x = $fdf2->load;
cmp_deeply($erg2, $erg2x, "2-write - read back - compare");


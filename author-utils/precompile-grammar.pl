#! /usr/bin/env perl
# ABSTRACT: precompile the grammar file
# PODNAME: precompile-grammar

use strict;
use warnings;

use File::Copy "mv";

require Parse::RecDescent;

my $grammar_file ='share/grammar';
open GRAMMAR_FILE, $grammar_file or die "Cannot open grammar file ".$grammar_file;
local $/;
my $grammar = <GRAMMAR_FILE>;

Parse::RecDescent->Precompile($grammar, "PDF::FDF::Simple::Grammar");
my $target = "lib/PDF/FDF/Simple/Grammar.pm";
mv "Grammar.pm", $target;
print "Updated $target\n";

1;

__END__

=head1 SYNOPSIS

 ./author-utils/precompile-grammar

=head1 DESCRIPTION

Precompiles the grammar file into class files

  lib/PDF/FDF/Simple/Grammar.pm

=cut

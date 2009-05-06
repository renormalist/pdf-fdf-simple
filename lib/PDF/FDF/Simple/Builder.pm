package PDF::FDF::Simple::Builder;

use strict;
use warnings;

use Module::Build;
use File::Copy "mv";
use Parse::RecDescent;

use vars qw(@ISA);
@ISA = ("Module::Build");

sub ACTION_grammar
{
        require File::ShareDir;

        my $grammar_file ='lib/auto/PDF/FDF/Simple/grammar';
        open GRAMMAR_FILE, $grammar_file or die "Cannot open grammar file ".$grammar_file;
        local $/;
        my $grammar = <GRAMMAR_FILE>;
        Parse::RecDescent->Precompile($grammar, "PDF::FDF::Simple::Grammar");
        my $target = "lib/PDF/FDF/Simple/Grammar.pm";
        mv "Grammar.pm", $target;
        print "Updated $target\n";
}


1;

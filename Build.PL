use lib "./lib";
use PDF::FDF::Simple::Builder;

use strict;
use warnings;

my %params = (
              module_name => 'PDF::FDF::Simple',
              license     => 'perl',
              requires    => {
                              'perl'                  => '5.6.1',
                              'Parse::RecDescent'     => '1.94',
                              'Class::Accessor::Fast' => 0,
                              'Test::More'            => 0,
                              'Compress::Zlib'        => 0,
                              'File::ShareDir'        => 0,
                             },
              meta_add    => {
                              resources => {
                                            repository => 'git://github.com/renormalist/pdf-fdf-simple.git',
                                            }
                             },
             );

my $build = new PDF::FDF::Simple::Builder (%params);
$build->create_build_script;

# copy_if_modified (from => "foo",
# to_dir => "lib/")
# install_base_relpaths($type)


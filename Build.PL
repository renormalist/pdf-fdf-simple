use Module::Build;

my %params = (
              module_name => 'PDF::FDF::Simple',
              license     => 'perl',
              requires    => {
                              perl                  => '5.6.1',
                              Parse::RecDescent     => '1.94',
                              Class::Accessor::Fast => 0,
                              Test::More            => 0,
                             },
             );

my $build = new Module::Build (%params);
$build->create_build_script;

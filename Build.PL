use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'POE::Test::Helpers',
    license             => 'perl',
    dist_author         => 'Sawyer <xsawyerx@cpan.org>',
    dist_version_from   => 'lib/POE/Test/Helpers.pm',
    build_requires => {
        'Test::More'  => 0,
        'MooseX::POE' => 0.205,
    },

    requires => {
        'Test::Deep'         => 0,
        'Test::Deep::NoTest' => 0,
        'List::AllUtils'     => 0,
        'Moose'              => 0.80,
        'POE'                => 1.2,
    },
    add_to_cleanup      => [ 'POE-Test-Helpers-*' ],
    create_makefile_pl  => 'traditional',
    create_readme       => 1,
    create_license      => 1,
);

$builder->create_build_script();

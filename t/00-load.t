#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'POE::Test::Helpers' );
}

diag( "Testing POE::Test::Helpers $POE::Test::Simple::VERSION, Perl $], $^X" );

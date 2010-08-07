#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;

# later change to POE::Test::Helpers
use POE::Test::Helpers::Session;

my $helper = POE::Test::Helpers::Session->new(
    run => sub {}, tests => {},
);

isa_ok( $helper, 'POE::Test::Helpers::Session' );

# checking errors

# missing name
throws_ok { $helper->reached_event() }
    qr/^Missing event name in reached_event/, 'Name is mandatory';
throws_ok { $helper->reached_event( name => '' ) }
    qr/^Missing event name in reached_event/, 'Name is mandatory';

# got non-digit count
throws_ok { $helper->reached_event( name => 'a' ) }
    qr/^Missing event count in reached_event/, 'No count';
throws_ok { $helper->reached_event( name => 'a', count => 'z' ) }
    qr/^Event count must be integer in reached_event/, 'Non-digit count';
throws_ok { $helper->reached_event( name => 'a', count => '' ) }
    qr/^Event count must be integer in reached_event/, 'Empty count';

# got non-digit order
throws_ok { $helper->reached_event( name => 'a', count => 0, ) }
    qr/^Missing event order in reached_event/, 'No order';
throws_ok { $helper->reached_event( name => 'a', order => 'z' ) }
    qr/^Event order must be integer in reached_event/, 'Non-digit order';
throws_ok { $helper->reached_event( name => 'a', order => '' ) }
    qr/^Event order must be integer in reached_event/, 'Empty order';

# got non-arrayref params
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, params => {} )
} qr/^Bad event params in reached_event/, 'Odd params';
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, params => '' )
} qr/^Bad event params in reached_event/, 'Empty params';

# got non-arrayref deps
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, deps => {} )
} qr/^Bad event deps in reached_event/, 'Odd deps';
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, deps => '' )
} qr/^Bad event deps in reached_event/, 'Empty deps';

__END__
# CHECK THE TESTS BEING DONE
{
    no warnings qw/redefine once/;
    *POE::Test::Helpers::Session::check_order = sub {
        ok( 1, 'Reached check_order' );
    };

    *POE::Test::Helpers::Session::check_count = sub {
        ok( 1, 'Reached check_count' );
    };

    *POE::Test::Helpers::Session::check_params = sub {
        ok( 1, 'Reached check_params' );
    };

    *POE::Test::Helpers::Session::check_deps = sub {
        ok( 1, 'Reached check_deps' );
    };
}

# typical syntax
$helper->reached_event(
    name   => '_start',
    count  => 0,
    params => [ 'hello', 'world' ],
);

# explicitly no parameters, don't check count
$helper->reached_event(
    name   => 'next',
    params => [],
);

# don't check parameters
$helper->reached_event(
    name  => '_stop',
    count => 1,
);


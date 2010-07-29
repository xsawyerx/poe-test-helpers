#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;

# later change to POE::Test::Helpers
use POE::Test::Helpers::Session;

my $helper = POE::Test::Helpers::Session->new(
    tests => {
        '_start' => { count  => 0, params => [ 'hello', 'world' ] },
        'next'   => { params => [] },
        '_stop'  => { count  => 1  },
    },
);

isa_ok( $helper, 'POE::Test::Helpers::Session' );

# checking errors

# missing name
throws_ok { $helper->reached_event( count => 0, params => [] ) }
    qr/^Missing event name in reached_event/, 'Name is mandatory';
throws_ok { $helper->reached_event( name => '', count => 0, params => [] ) }
    qr/^Missing event name in reached_event/, 'Name is mandatory';

# got non-digit count
throws_ok { $helper->reached_event( name => 'a', count => 'z' ) }
    qr/^Bad event count in reached_event/, 'Non-digit count';
throws_ok { $helper->reached_event( name => 'a', count => '' ) }
    qr/^Bad event count in reached_event/, 'Empty count';

# got non-digit order
throws_ok { $helper->reached_event( name => 'a', order => 'z' ) }
    qr/^Bad event order in reached_event/, 'Non-digit order';
throws_ok { $helper->reached_event( name => 'a', order => '' ) }
    qr/^Bad event order in reached_event/, 'Empty order';

# got non-arrayref params
throws_ok { $helper->reached_event( name => 'a', params => {} ) }
    qr/^Bad event params in reached_event/, 'Odd params';
throws_ok { $helper->reached_event( name => 'a', params => '' ) }
    qr/^Bad event params in reached_event/, 'Empty params';

# got non-arrayref deps
throws_ok { $helper->reached_event( name => 'a', deps => {} ) }
    qr/^Bad event deps in reached_event/, 'Odd deps';
throws_ok { $helper->reached_event( name => 'a', deps => '' ) }
    qr/^Bad event deps in reached_event/, 'Empty deps';

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


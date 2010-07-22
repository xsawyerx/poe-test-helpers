#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;

# later change to POE::Test::Helpers
use POE::Test::Helpers::Session;

my $helper = POE::Test::Helpers::Session->new;

isa_ok( $helper, 'POE::Test::Helpers::Session' );

# checking errors

# missing name
throws_ok { $helper->register_event( count => 0, params => [] ) }
    qr/^Missing event name in register_event/, 'Name is mandatory';
throws_ok { $helper->register_event( name => '', count => 0, params => [] ) }
    qr/^Missing event name in register_event/, 'Name is mandatory';

# got non-digit count
throws_ok { $helper->register_event( name => 'a', count => 'z' ) }
    qr/^Bad event count in register_event/, 'Non-digit count';
throws_ok { $helper->register_event( name => 'a', count => '' ) }
    qr/^Bad event count in register_event/, 'Empty count';

# got non-arrayref params
throws_ok { $helper->register_event( name => 'a', params => {} ) }
    qr/^Bad event params in register_event/, 'Odd params';
throws_ok { $helper->register_event( name => 'a', params => '' ) }
    qr/^Bad event params in register_event/, 'Empty params';

# typical syntax
$helper->register_event(
    name   => '_start',
    count  => 0,
    params => [ 'hello', 'world' ],
);

# explicitly no parameters, don't check count
$helper->register_event(
    name   => 'next',
    params => [],
);

# don't check parameters
$helper->register_event(
    name  => '_stop',
    count => 1,
);

my %expected = (
    _start => {
        count  => 0,
        params => [ 'hello', 'world' ],
    },
    next  => { params => [] },
    _stop => { count => 1 },
);

is_deeply(
    $helper->{'events'},
    \%expected,
    'register_event created correct hash',
);


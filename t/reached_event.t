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
throws_ok { $helper->reached_event( name => 'a', count => 0, order => 'z' ) }
    qr/^Event order must be integer in reached_event/, 'Non-digit order';
throws_ok { $helper->reached_event( name => 'a', count => 0, order => '' ) }
    qr/^Event order must be integer in reached_event/, 'Empty order';

# got non-arrayref params
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, params => {} )
} qr/^Event params must be arrayref in reached_event/, 'Odd params';
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, params => '' )
} qr/^Event params must be arrayref in reached_event/, 'Empty params';

# got non-arrayref deps
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, deps => {} )
} qr/^Event deps must be arrayref in reached_event/, 'Odd deps';
throws_ok { $helper->reached_event(
    name => 'a', count => 0, order => 0, deps => '' )
} qr/^Event deps must be arrayref in reached_event/, 'Empty deps';


#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 15;
use Test::Exception;

# XXX: later change to POE::Test::Helpers
use POE::Test::Helpers::Session;
my $class = 'POE::Test::Helpers::Session'; 
my $new   = sub { return POE::Test::Helpers::Session->new(@_) };

throws_ok { $new->() } qr/^Missing tests data in new/,
    'tests and run required';

throws_ok { $new->( tests => {} ) }
    qr/Missing run method in new/, 'run required';

throws_ok { $new->( run => sub {1} ) } qr/^Missing tests data in new /,
    'tests required';

throws_ok { $new->( run => {} ) } qr/^Run method should be a coderef in new /,
    'run should be coderef';

throws_ok { $new->( tests => [] ) } qr/Tests data should be a hashref in new /,
    'tests should be hashref';

# checking errors

# missing name
throws_ok { $new->( count => 0, params => [] ) }
    qr/^Missing event name in new/, 'Name is mandatory';
throws_ok { $new->( name => '', count => 0, params => [] ) }
    qr/^Missing event name in new/, 'Name is mandatory';

# got non-digit count
throws_ok { $new->( name => 'a', count => 'z' ) }
    qr/^Bad event count in new/, 'Non-digit count';
throws_ok { $new->( name => 'a', count => '' ) }
    qr/^Bad event count in new/, 'Empty count';

# got non-digit order
throws_ok { $new->( name => 'a', order => 'z' ) }
    qr/^Bad event order in new/, 'Non-digit order';
throws_ok { $new->( name => 'a', order => '' ) }
    qr/^Bad event order in new/, 'Empty order';

# got non-arrayref params
throws_ok { $new->( name => 'a', params => {} ) }
    qr/^Bad event params in new/, 'Odd params';
throws_ok { $new->( name => 'a', params => '' ) }
    qr/^Bad event params in new/, 'Empty params';

# got non-arrayref deps
throws_ok { $new->( name => 'a', deps => {} ) }
    qr/^Bad event deps in new/, 'Odd deps';
throws_ok { $new->( name => 'a', deps => '' ) }
    qr/^Bad event deps in new/, 'Empty deps';

# typical syntax
isa_ok(
    $new->(
        tests => {
            name   => '_start',
            count  => 0,
            params => [ 'hello', 'world' ],
        }
    ),
    $class,
);

# explicitly no parameters, don't check count
isa_ok(
    $new->(
        name   => 'next',
        params => [],
    ),
    $class,
);

# don't check parameters
isa_ok(
    $new->(
        name  => '_stop',
        count => 1,
    ),
    $class,
);


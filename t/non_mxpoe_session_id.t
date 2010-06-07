#!perl

# how to work with POE::Test::Helpers separate of MooseX::POE
use strict;
use warnings;
use POE;
use POE::Test::Helpers::Session;
use Test::More tests => 4;

sub start { $_[KERNEL]->yield('next') }
sub next  { $_[KERNEL]->yield('last') }
sub last  {1}
sub stop  {1}

my $session = POE::Session->create(
    inline_states => {
        '_start' => \&start,
        'next'   => \&next,
        'last'   => \&last,
        '_stop'  => \&stop,
    },
);

POE::Test::Helpers::Session->spawn(
    alias           => 'tester',
    test_session_id => $session->ID,
);

POE::Kernel->run();


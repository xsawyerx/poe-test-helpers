#!perl

# how to work with POE::Test::Helpers separate of MooseX::POE
use strict;
use warnings;
use POE;
use POE::Test::Helpers::Session;
use Test::More tests => 4;

$|=1;
sub start { print "t: _start\n"; $_[KERNEL]->yield('next') }
sub next  { print "t: next\n"; $_[KERNEL]->yield('last') }
sub last  { print "t: last\n"; 1}
sub stop  { print "t: _stop\n"; 1}


POE::Test::Helpers::Session->spawn(
    alias => 'tester',
    test  => sub {
        POE::Session->create(
            inline_states => {
                '_start' => \&start,
                'next'   => \&next,
                'last'   => \&last,
                '_stop'  => \&stop,
            },
            options => { trace => 1 },
        );
    },
);

print "t: before run\n";
POE::Kernel->run();
print "t: after run\n";


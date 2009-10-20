#!perl

# testing ordered events
# this method was first written by ADAMK
# and can be found in POE::Declare t/04-stop.t

# the Role provided simply runs the tests for the session
package Session;
use Test::More tests => 4;
use MooseX::POE;
with 'POE::Test::Helpers';
sub START {
    $_[OBJECT]->order( 0, 'START' );
    $_[KERNEL]->yield('next');
}
event 'next' => sub {
    $_[OBJECT]->order( 1, 'next' );
    $_[KERNEL]->yield('last');
};
event 'last' => sub {
    $_[OBJECT]->order( 2, 'last' );
};
sub STOP {
    $_[OBJECT]->order( 3, 'STOP' );
}

package main;
use POE::Kernel;
Session->new();
POE::Kernel->run();


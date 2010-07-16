#!perl

# testing event parameters
# this allows to set each event with sets of parameters
# these are the parameters that it MUST have
# and they are in the order in which it's required
package Session;

use Test::More tests => 4;
use POE::Test::Helpers::Session;

use POE;

my $flag = 0;
POE::Test::Helpers::Session->spawn(
    run => sub {
        POE::Session->create(
            inline_states => {
                _start => sub { $_[KERNEL]->yield( 'next', 'hello', 'world') },
                next   => sub { $_[KERNEL]->yield('more') },
                more   => sub {
                    $flag++ || $_[KERNEL]->yield( 'next', 'goodbye' );
                },
            },
        );
    },

    test_event_params => {
        'next' => [ [ 'hello', 'world' ], ['goodbye'] ],
        'more' => [],
    },
);

POE::Kernel->run();


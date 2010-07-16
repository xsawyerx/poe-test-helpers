#!perl

# testing sequenced ordered events
# this is a more relaxed and flexible implementation of ADAMK's version
# it allows to define order by previous occured events
# instead of number of specific occurrence.
# that way, you can define which events should have preceded
# instead of what exact global order it had

package Session;

use Test::More tests => 4;
use POE::Test::Helpers::Session;

use POE;

POE::Test::Helpers::Session->spawn(
    run => sub {
        POE::Session->create(
            inline_states => {
                _start => sub { $_[KERNEL]->yield('next') },
                next   => sub { $_[KERNEL]->yield('last') },
                last   => sub {1},
            },
        );
    },

    test_sequence => {
        '_start' => [],
        'next'   => [ '_start'                 ],
        'last'   => [ '_start', 'next'         ],
        '_stop'  => [ '_start', 'next', 'last' ],
    },
);

POE::Kernel->run();

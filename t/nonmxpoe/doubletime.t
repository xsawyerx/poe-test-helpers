#!perl

# testing sequenced ordered events
# this is a more relaxed and flexible implementation of ADAMK's version
# it allows to define order by previous occured events
# instead of number of specific occurrence.
# that way, you can define which events should have preceded
# instead of what exact global order it had

# we don't care whether next run the correct number of times
# only that it ran with the correct dependencies that followed
package Session;

use Test::More tests => 14;
use POE::Test::Helpers::Session;

use POE;

my $count = 0;
POE::Test::Helpers::Session->spawn(
    run => sub {
        POE::Session->create(
            inline_states => {
                _start => sub { $_[KERNEL]->yield('next') },
                next   => sub { $_[KERNEL]->yield('more') },
                more   => sub {
                    $count++ < 3 ? $_[KERNEL]->yield('next') :
                                   $_[KERNEL]->yield('last');
                },
                last   => sub {1},
            },
        );
    },

    tests => {
        '_start' => { count => 1          },
        'next'   => { deps  => ['_start'] },
        'more'   => {
            count => 4,
            deps  => [ '_start', 'next' ],
        },

        'last'   => {
            count => 1,
            deps  => [ '_start', 'next', 'more' ],
        },

        '_stop'  => {
            count => 1,
            deps  => [ '_start', 'next', 'more', 'last' ],
        },
    },
);

POE::Kernel->run();


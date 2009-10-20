#!perl

# testing event parameters
# this allows to set each event with sets of parameters
# these are the parameters that it MUST have
# and they are in the order in which it's required

package Session;
use Test::More tests => 4;
use MooseX::POE;
with 'POE::Test::Helpers';
has '+event_params' => (
    default => sub { {
        'next' => [ [ 'hello', 'world' ], [ 'goodbye' ] ],
        'more' => [],
} } );

my $flag = 0;
sub START           { $_[KERNEL]->yield( 'next', 'hello', 'world' ) }
event 'next' => sub { $_[KERNEL]->yield( 'more'                   ) };
event 'more' => sub {
    $flag++ || $_[KERNEL]->yield( 'next', 'goodbye' );
};

package main;
use POE::Kernel;
Session->new();
POE::Kernel->run();


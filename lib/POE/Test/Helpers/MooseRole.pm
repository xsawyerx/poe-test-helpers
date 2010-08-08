package POE::Test::Helpers::MooseRole;
# ABSTRACT: A Moose role for POE::Test::Helpers for MooseX::POE

use Carp;
use Test::Deep         qw( cmp_bag bag );
use Test::Deep::NoTest qw( eq_deeply );
use List::AllUtils     qw( none );
use Test::More;
use Moose::Role;
use POE::Session; # for POE variables
use POE::Test::Helpers;

has 'object' => (
    is         => 'ro',
    isa        => 'POE::Test::Helpers',
    lazy_build => 1,
    handles    => [ 'reached_event', 'check_all_counts' ],
);

has 'tests'       => ( is => 'ro', isa => 'HashRef', required => 1         );
has 'params_type' => ( is => 'ro', isa => 'Str',     default  => 'ordered' );

sub _build_object {
    my $self   = shift;
    my $object = POE::Test::Helpers->new(
        run         => sub {1},
        tests       => $self->tests,
        params_type => $self->params_type,
    );
}

before 'STARTALL' => sub {
    my $self  = shift;
    my $class = ref $self;

    $self->reached_event(
        name  => '_start',
        order => 0,
    );

    my $count = 1;
    my @subs_to_override = keys %{ $self->object->{'tests'} };

    foreach my $event (@subs_to_override) {
        $event eq '_start' || $event eq '_stop' and next;

        Moose::Meta::Class->initialize($class)->add_before_method_modifier(
            $event => sub {
                my $self = $_[OBJECT];
                $self->reached_event(
                    name   => $event,
                    order  => $count++,
                    params => [ @_[ ARG0 .. $#_ ] ],
                );
            }
        );
    }
};

after 'STOPALL' => sub {
    my $self = shift;
    my $order = $self->object->{'events_order'}             ?
                scalar @{ $self->object->{'events_order'} } :
                0;

    $self->reached_event(
        name  => '_stop',
        order => $order,
    );

    $self->check_all_counts;
};

no Moose::Role;
1;

__END__

=head1 SYNOPSIS

This module provides a Moose role to allow you to test your POE code.

Currently it's best used with L<MooseX::POE> but L<POE::Session> code is also
doable.

Perhaps a little code snippet.

    package MySession;
    use MooseX::POE;
    with 'POE::Test::Helpers';

    has '+seq_ordering' => ( default => sub { {
        last => { 1 => ['next'] },
    } } );

    event 'START' => sub {
        $_[KERNEL]->yield('next');
    };

    event 'next' => sub {
        $_[KERNEL]->yield('last');
    };

    event 'last' => sub {
        ...
    };

    package main;
    use Test::More tests => 2;
    use POE::Kernel;
    MySession->new();
    POE::Kernel->run();

    ...

Testing event-based programs is not trivial at all. There's a lot of hidden race
conditions and unknown behavior afoot. Usually we separate the testing to
components, subroutines and events. However, as good as it is (and it's good!),
it doesn't give us the exact behavior we'll get from the application once
running.

There are also a lot of types of tests that we would want to run, such as:

=over 4

=item * Ordered Events:

Did every event run in the specific ordered I wanted it to?

I<(maybe some event was called first instead of third...)>

=item * Sequence Ordered Events:

Declaring dependency events for tested events.

I<(an event is only okay if the preceeding events ran first)>

=item * Event Counting:

How many times can each event run?

I<(this event can be run only 4 times, no more, no less)>

=item * Ordered Event Parameters:

Checking specific parameters an event received, supporting multiple options.

I<(did this event get the right parameters for each call?)>

=item * Unordered Event Parameters:

Same thing, just without having a specific order of sets of events.

=back

This module allows to do all those things using a simple L<Moose> Role.

In order to use it, you must consume the role (using I<with>) and then change
the following attributes.

=head1 Attributes

=head2 seq_ordering

This is a hash reference which sets the number of times each event can be run
and/or the event that had to come first before the event could be run. That is,
if you have an event "world", you can specify that "world" can only be run once,
or can only be run twice. You can instead specify that "world" can only be run
after a different event - "hello" - has been run.

Here are some examples:

    has '+seq_ordering' => ( default => sub { {
        hello => 1,                  # hello can only be run once
        there => ['hello'],          # there can only be run after hello
        world => { 2 => ['hello'] }, # world runs twice, only after hello
    } } );

One thing to remember is that event dependencies are not direct. That is, in the
above example, "world" can be run right after "there" but as long as "hello" was
run sometime prior to that, it will be okay. That is, sequence ordering is not
strict.

=head2 event_params

This is a hash reference which sets the parameters each event is expecting. By
default, this parameters must be consecutive. That is, if there are two sets of
parameters, the first one is what's tested when the event is run for the first
time and the second one will be tested when the event is run the second time. If
this is troublesome for you, check the next attribute, you'll enjoy that.

    has '+event_params' => ( default => sub { {
        goodbye => [ [ 'cruel',  'world' ] ],
        hello   => [ [ 'ironic', 'twist' ] ],
        special => [ [ 'params', 'for', first', 'run' ], [ 'more', 'params' ] ],
    } } );

You'll notice one weird thing: two array refs. The reason is actually very
simple. This test checks each parameter separately, so you specify sets of
parameters, each set for a different run. Thus, each set is defined in an array
ref. Because of this, even if you're only giving one set of params, it needs to
be encapsulated in an array ref. This might change in the future, if anyone will
care enough.

=head2 event_params_type

This is a simple string which controls how the event_params will go. Meanwhile
it can only be set to "ordered" and "unordered". This might change in the future
or could be replaced with "event_params_ordered" boolean or something. Be
warned.

Basically this means that you don't care about the order of how the parameters
get there, but only that whenever the event was run, it had one of the sets of
parameters.

=head1 METHODS

=head2 order

Simple ordered tests can also be done using this framework, but are less
intuitive. In order to set orders of events, a method has to be run. I'm sure
this will be changed, so stay tuned.

    event 'example' => sub {
        my $self = $_[OBJECT];
        $self->order( 0, 'Example runs first!' );
    };

=head1 AUTHOR

Sawyer, C<< <xsawyerx at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-test-simple at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Test-Helpers>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I
make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Test::Helpers

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Test-Helpers>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Test-Helpers>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Test-Helpers>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Test-Helpers/>

=back

=head1 ACKNOWLEDGEMENTS

I owe a lot of thanks to the following people:

=over 4

=item * Chris (perigrin) Prather

Thanks for all the comments and ideas. Thanks for L<MooseX::POE>!

=item * Rocco (dngor) Caputo

Thanks for the input and ideas. Thanks for L<POE>!

=item * #moose and #poe

Really great people and constantly helping me with stuff, including one of the
core principles in this module.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Sawyer, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


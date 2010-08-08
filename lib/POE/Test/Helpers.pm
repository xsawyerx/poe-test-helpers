package POE::Test::Helpers;
# ABSTRACT: Testing framework for POE

use strictures 1;

use Carp;
use parent 'Test::Builder::Module';
use POE::Session;
use Data::Validate    'is_integer';
use List::AllUtils     qw( first none );
use Test::Deep::NoTest qw( bag eq_deeply );
use namespace::autoclean;

my $CLASS = __PACKAGE__;

sub new {
    my ( $class, %opts ) = @_;

    # must have tests
    my $tests = $opts{'tests'};
    defined $tests       or croak 'Missing tests data in new';
    ref $tests eq 'HASH' or croak 'Tests data should be a hashref in new';

    # must have run method
    exists $opts{'run'}        or croak 'Missing run method in new';
    ref $opts{'run'} eq 'CODE' or croak 'Run method should be a coderef in new';

    foreach my $name ( keys %{$tests} ) {
        my $test_data = $tests->{$name};

        my ( $count, $order, $params, $deps ) =
            @{$test_data}{ qw/ count order params deps / };

        # currently we still allow to register tests without requiring
        # at least a count or params

        # check the count
        if ( defined $count ) {
            # count is only tested in the last run so we just check the param
            defined is_integer($count) or croak 'Bad event count in new';
        }

        # check the order
        if ( defined $order ) {
            defined is_integer($order) or croak 'Bad event order in new';
        }

        # check deps
        if ( defined $deps ) {
            ref $deps eq 'ARRAY' or croak 'Bad event deps in new';
        }

        # check the params
        if ( defined $params ) {
            ref $params eq 'ARRAY' or croak 'Bad event params in new';
        }
    }

    my $self = bless {
        tests       => $tests,
        run         => $opts{'run'},
        params_type => $opts{'params_type'} || 'ordered',
    }, $class;

    return $self;
}

sub spawn {
    my ( $class, %opts ) = @_;

    my $self = $class->new(%opts);

    $self->{'session_id'} = POE::Session->create(
        object_states => [
            $self => [ '_start', '_child' ],
        ],
    )->ID;

    return $self;
}

sub reached_event {
    my ( $self, %opts ) = @_;
    # we don't have to get params,
    # but we do have to get the name and order

    my $name = $opts{'name'};
    # must have name
    defined $name && $name ne ''
        or croak 'Missing event name in reached_event';

    my ( $event_order, $event_params, $event_deps ) =
        @opts{ qw/ order params deps / };

    defined $event_order
        or croak 'Missing event order in reached_event';
    defined is_integer($event_order)
        or croak 'Event order must be integer in reached_event';

    if ( defined $event_params ) {
        ref $event_params eq 'ARRAY'
            or croak 'Event params must be arrayref in reached_event';
    }

    if ( defined $event_deps ) {
        ref $event_deps eq 'ARRAY'
            or croak 'Event deps must be arrayref in reached_event';
    }

    my $test_data = $self->{'tests'}{$name};

    my ( $test_count, $test_order, $test_params, $test_deps ) =
        @{$test_data}{ qw/ count order params deps / };

    # currently we still allow to register events without requiring
    # at least a count or params

    # add the event to the list of events
    push @{ $self->{'events_order'} }, $name;

    # check the order
    if ( defined $test_order ) {
        $self->check_order( $name, $event_order );
    }

    # check deps
    if ( defined $test_deps ) {
        $self->check_deps( $name, $event_deps );
    }

    # check the params
    if ( defined $test_params ) {
        $self->check_params( $name, $event_params );
    }

    return 1;
}

sub check_count {
    my ( $self, $event, $count ) = @_;
    my $tb = $CLASS->builder;

    my $count_from_event = grep /^$event$/, @{ $self->{'events_order'} };
    $tb->is_num( $count_from_event, $count, "$event ran $count times" );

    return 1;
}

sub check_order {
    my ( $self, $event, $event_order ) = @_;
    my $tb = $CLASS->builder;

    my $event_from_order = $self->{'events_order'}[$event_order];

    $tb->is_eq( $event, $event_from_order, "($event_order) $event" );

    return 1;
}

sub check_deps {
    my ( $self, $event, $deps ) = @_;
    my $tb = $CLASS->builder;

    # get the event's tested dependencies and all events run so far
    my @deps_from_event = @{ $self->{'tests'}{$event}{'deps'} };
    my @all_events      = map { $self->{'events_order'}[$_] }
        $#{ $self->{'events_order'} };

    # check for problematic dependencies
    my @problems = ();
    foreach my $dep_event (@deps_from_event) {
        if ( ! grep /^$dep_event$/, @all_events ) {
            push @problems, $dep_event;
        }
    }

    # serialize possible errors
    my $missing = join ', ', @problems;
    my $extra   = @problems ? "[$missing missing]" : q{};

    $tb->ok( ( @problems > 0 ), "Correct sub deps for ${event}${extra}" );
}

sub check_params {
    my ( $self, $event, $current_params ) = @_;
    my $tb = $CLASS->builder;

    my $test_params = $self->{'tests'}{$event}{'params'};

    if ( $self->{'params_type'} eq 'ordered' ) {
        # remove the fetched
        my $expected_params = shift @{$test_params} || [];

        $tb->ok(
            eq_deeply(
                $current_params,
                $expected_params,
            ),
            "($event) Correct params",
        );
    } else {
        # don't remove, just match
        my $okay = 0;

        foreach my $expected_params ( @{$test_params} ) {
            if ( eq_deeply(
                    $current_params,
                    bag(@{$expected_params}) ) ) {
                $okay++;
            }
        }

        $tb->ok( $okay, "($event) Correct [unordered] params" );
    }
}

sub _child {
    # this says that _start on our spawned session started
    # we should mark _start on our superhash
    my $self    = $_[OBJECT];
    my $change  = $_[ARG0];
    my $session = $_[ARG1];

    my $internals = $session->[KERNEL];

    if ( $change eq 'create' ) {
        $self->reached_event(
            name  => '_start',
            order => 0,
        );
    } elsif ( $change eq 'lose' ) {
        # get the last events_order
        my $order = $self->{'events_order'}             ?
                    scalar @{ $self->{'events_order'} } :
                    0;

        $self->reached_event(
            name  => '_stop',
            order => $order,
        );

        # checking the count
        foreach my $test ( keys %{ $self->{'tests'} } ) {
            my $test_data = $self->{'tests'}{$test};

            if ( exists $test_data->{'count'} ) {
                $self->check_count( $test, $test_data->{'count'} );
            }
        }
    }
}

sub _start {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

    # collect the keys of everyone
    # if exists key in test, add a test for it for them
    $self->{'session_id'} = $_[SESSION]->ID();

    my @subs_to_override = keys %{ $self->{'tests'} };

    my $callback        = $self->{'run'};
    my $session_to_test = $callback->();
    my $internal_data   = $session_to_test->[KERNEL];

    # 0 is done by _start in _child event, so we start from 1
    my $count = 1;

    foreach my $sub_to_override (@subs_to_override) {
        # use _child event to handle these
        $sub_to_override eq '_start' || $sub_to_override eq '_stop' and next;

        # override the subroutine
        my $old_sub = $internal_data->{$sub_to_override};
        my $new_sub = sub {
            $self->reached_event(
                name   => $sub_to_override,
                order  => $count++,
                params => [ @_[ ARG0 .. $#_ ] ],
            );

            goto &$old_sub;
        };

        $internal_data->{$sub_to_override} = $new_sub;
    }
}

1;

__END__

=head1 SYNOPSIS

This module provides you with a framwork to easily write tests for your POE
code.

The main purpose of this module is to be non-instrusive (or abstrusive) and
allow you to write your code without getting in your way.

    package MySession;

    use Test::More tests => 1;
    use POE;
    use POE::Test::Helpers;

    # defining a callback to create a session
    my $run = sub {
        return POE::Session->create(
            inline_states => {
                '_start' => sub {
                    print "Start says hi!\n";
                    $_[KERNEL]->yield('next');
                },
                'next' => sub { print "Next says hi!\n" },
            }
        );
    };

    # here we define the tests
    # and tell POE::Test::Helpers to run your session
    POE::Test::Helpers->spawn(
        run   => $run,
        tests => {
            # _start is actually 0
            # next will run right after _start
            next => { order => 1 },
        },
    );

Testing event-based programs is not trivial at all. There's a lot of hidden race
conditions and unknown behavior afoot. Usually we separate the testing to
components, subroutines and events. However, as good as it is (and it's good!),
it doesn't give us the exact behavior we'll get from the application once
running.

There are also a lot of types of tests that we would want to run, such as:

=over 4

=item * Ordered Events:

Did every event run in the specific order I wanted it to?

I<(maybe some event was called first instead of third...)>

=item * Sequence Ordered Events:

Did every event run only after other events?

Imagine you want to check whether C<run_updates> ran, but you know it can should
only run after C<get_main_status> ran. In event-based programming, you would
give up the idea of testing this possible race condition, but with
Test::POE::Helpers you can test it.

I<< C<run_updates> can only run after C<get_main_status> >

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

=head1 METHODS

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

Copyright 2009-2010 Sawyer, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


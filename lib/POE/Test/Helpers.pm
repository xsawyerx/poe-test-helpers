package POE::Test::Helpers;

our $VERSION = '0.05';

use Carp;
use Test::Deep         qw( cmp_bag bag );
use Test::Deep::NoTest qw( eq_deeply );
use List::AllUtils     qw( none );
use Test::More;
use Moose::Role;
use POE::Session; # for POE variables

# TODO: use native Counter here
# TODO: use native Hash here
has 'order_count'  => ( is => 'rw', isa => 'Int',     default => 0          );
has 'track_seq'    => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has 'seq_ordering' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'event_params' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

has 'event_params_type' => ( is => 'rw', isa => 'Str', default => 'ordered' );

before 'STARTALL' => sub {
    my $self  = shift;
    my $class = ref $self;
    foreach my $event ( keys %{ $self->seq_ordering } ) {
        Moose::Meta::Class->initialize($class)->add_before_method_modifier(
            $event => sub {
                my $self = $_[OBJECT];
                $self->_seq_order($event);
            }
        );
    }

    foreach my $event ( keys %{ $self->event_params } ) {
        Moose::Meta::Class->initialize($class)->add_before_method_modifier(
            $event => sub {
                my $self = $_[OBJECT];
                $self->_seq_order( $event, @_[ ARG0 .. $#_ ] );
            }
        );
    }
};

after 'STOPALL' => sub {
    my $self = shift;
    $self->_seq_end();
};

sub order {
    my ( $self, $order, $msg ) = @_;
    my $new_order = $order + 1;
    is( $order, $self->order_count, "($order) $msg" );
    $self->order_count( $new_order );
    return;
}

# TODO: max value should only be counted once
# this can be done via trigger() perhaps
sub _seq_order {
    my ( $self, $event, @args ) = @_;
    my $value = $self->seq_ordering->{$event} || q{};

    # checking sequences
    if ( ref $value eq 'ARRAY' ) {
        # event dependencies
        $self->_seq_check_deps( $value, $event );
    } elsif ( ref $value eq 'HASH' ) {
        # mixture of sub counting and event dependencies
        # checking deps, setting max value
        if ( keys %{$value} > 1 ) {
            carp "Skipping $event, too many definitions.\n";
            return;
        }

        my ( $max, $array ) = each %{$value};

        $self->_seq_check_deps( $array, $event );
        $self->track_seq->{$event}{'max'} = $max;
    } elsif ( ! ref $value ) {
        # just setting the max value for each sub
        $self->track_seq->{$event}{'max'} = $value;
    } else {
        carp "Problem with value: $value\n";
    }

    # checking parameter
    if ( my $event_params = $self->event_params->{$event} ) {
        my $current_params  = @args ? \@args : [];

        # event_params defined, we can check
        if ( $self->event_params_type eq 'ordered' ) {
            my $expected_params = shift @{$event_params} || [];

            cmp_bag(
                $current_params,
                $expected_params,
                "($event) Correct params",
            );
        } elsif ( my $type = $self->event_params_type eq 'unordered' ) {
            my $okay = 0;

            foreach my $expected_params ( @{$event_params} ) {
                if ( eq_deeply(
                        $current_params,
                        bag(@{$expected_params}) ) ) {
                    $okay++;
                }
            }

            ok( $okay, "($event) Correct [unordered] params" );
        } else {
            carp "Unknown event_params_type: $type\n";
        }
    }

    $self->track_seq->{$event}{'cur'}++;
    return;
}

sub _seq_check_deps {
    my ( $self, $got_deps, $event ) = @_;
    my @exp_deps = keys %{ $self->track_seq };
    my @bad      = ();

    foreach my $dep ( @{$got_deps} ) {
        if ( none { $dep eq $_ } @exp_deps ) {
            push @bad, $dep;
        }
    }

    my $data  = join ', ', map { qq{"$_"} } @bad;
    my $extra = scalar @bad ? " [$data missing]" : q{};
    ok( ! scalar @bad, "Correct sequence for $event" . $extra );

    return;
}

# TODO: refactoring plzkthx
sub _seq_end {
    my $self = shift;
    # now we can check th sub counting
    foreach my $event ( keys %{ $self->seq_ordering } ) {
        $self->track_seq->{$event}{'max'} || next;

        is(
            $self->track_seq->{$event}{'cur'},
            $self->track_seq->{$event}{'max'},
            "($event) Correct number of runs",
        );

    }
}

no Moose::Role;
1;

__END__

=head1 NAME

POE::Test::Helpers - Testing framework for POE

=head1 VERSION

Version 0.05

=head1 SYNOPSIS

This module provides a Moose role to allow you to test your POE code.

Currently it's best used with L<MooseX::POE> but L<POE::Session> code is also doable.

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

Testing event-based programs is not trivial at all. There's a lot of hidden race conditions and unknown behavior afoot. Usually we separate the testing to components, subroutines and events. However, as good as it is (and it's good!), it doesn't give us the exact behavior we'll get from the application once running.

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

In order to use it, you must consume the role (using I<with>) and then change the following attributes.

=head1 Attributes

=head2 seq_ordering

This is a hash reference which sets the number of times each event can be run and/or the event that had to come first before the event could be run. That is, if you have an event "world", you can specify that "world" can only be run once, or can only be run twice. You can instead specify that "world" can only be run after a different event - "hello" - has been run.

Here are some examples:

    has '+seq_ordering' => ( default => sub { {
        hello => 1,                  # hello can only be run once
        there => ['hello'],          # there can only be run after hello
        world => { 2 => ['hello'] }, # world has to be run twice and only after hello
    } } );

One thing to remember is that event dependencies are not direct. That is, in the above example, "world" can be run right after "there" but as long as "hello" was run sometime prior to that, it will be okay. That is, sequence ordering is not strict.

=head2 event_params

This is a hash reference which sets the parameters each event is expecting. By default, this parameters must be consecutive. That is, if there are two sets of parameters, the first one is what's tested when the event is run for the first time and the second one will be tested when the event is run the second time. If this is troublesome for you, check the next attribute, you'll enjoy that.

    has '+event_params' => ( default => sub { {
        goodbye => [ [ 'cruel',  'world' ] ],
        hello   => [ [ 'ironic', 'twist' ] ],
        special => [ [ 'params', 'for', first', 'run' ], [ 'params', 'for', 'second' ] ],
    } } );

You'll notice one weird thing: two array refs. The reason is actually very simple. This test checks each parameter separately, so you specify sets of parameters, each set for a different run. Thus, each set is defined in an array ref. Because of this, even if you're only giving one set of params, it needs to be encapsulated in an array ref. This might change in the future, if anyone will care enough.

=head2 event_params_type

This is a simple string which controls how the event_params will go. Meanwhile it can only be set to "ordered" and "unordered". This might change in the future or could be replaced with "event_params_ordered" boolean or something. Be warned.

Basically this means that you don't care about the order of how the parameters get there, but only that whenever the event was run, it had one of the sets of parameters.

=head1 METHODS

=head2 order

Simple ordered tests can also be done using this framework, but are less intuitive. In order to set orders of events, a method has to be run. I'm sure this will be changed, so stay tuned.

    event 'example' => sub {
        my $self = $_[OBJECT];
        $self->order( 0, 'Example runs first!' );
    };

=head1 AUTHOR

Sawyer, C<< <xsawyerx at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-test-simple at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Test-Simple>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Test::Simple

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Test-Simple>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Test-Simple>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Test-Simple>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Test-Simple/>

=back

=head1 ACKNOWLEDGEMENTS

I owe a lot of thanks to the following people:

=over 4

=item * Chris (perigrin) Prather

Thanks for all the comments and ideas. Thanks for L<MooseX::POE>!

=item * Rocco (dngor) Caputo

Thanks for the input and ideas. Thanks for L<POE>!

=item * #moose and #poe

Really great people and constantly helping me with stuff, including one of the core principles in this module.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Sawyer, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


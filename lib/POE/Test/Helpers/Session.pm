package POE::Test::Helpers::Session;

use strictures 1;

use Carp;
use parent 'Test::Builder::Module';
use POE::Session;
use Data::Validate 'is_integer';
use namespace::autoclean;

use List::AllUtils     qw( first none );
use Test::More;

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

    foreach my $test ( @{$tests} ) {
        # must have name
        my $name = $test->{'name'};
        defined $name && $name ne ''
            or croak 'Missing test name in new';

        my $test_data = $test->{$name};

        my ( $count, $order, $params, $deps ) =
            @{$test_data}{ qw/ name count order params deps / };

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

    my $self = bless { %{$tests} }, $class;

    return $self;
}

sub spawn {
    my ( $class, %opts ) = @_;

    my $self = $class->new(%opts);

    # use some key that can have a simple boolean value
    $self->{'event_params_type'} ||= 'ordered';

    $self->{'session_id'} = POE::Session->create(
        object_states => [
            $self => [ '_start', '_child' ],
        ],
    )->ID;

    return $self;
}

sub reached_event {
    my ( $self, %opts ) = @_;
    my $name = $opts{'name'};
    # must have name
    defined $name && $name ne ''
        or croak 'Missing event name in reached_event';

    my $ev_data = $self->{'tests'}{$name};

    my ( $count, $order, $params, $deps ) =
        @{$ev_data}{ qw/ name count order params deps / };

    # currently we still allow to register events without requiring
    # at least a count or params

    # add the event to the list of events
    push @{ $self->{'events_order'} }, $name;

    # check the count
    if ( defined $count ) {
        # count is only tested in the last run so we just check the param
        defined is_integer($count) or croak 'Bad event count in reached_event';
    }

    # check the order
    if ( defined $order ) {
        defined is_integer($order) or croak 'Bad event order in reached_event';

        defined $ev_data->{'order'} && $self->check_order( $name, $order );
    }

    # check deps
    if ( defined $deps ) {
        ref $deps eq 'ARRAY' or croak 'Bad event deps in reached_event';

        defined $ev_data->{'deps'} && $self->check_deps( $name, $deps );
    }

    # check the params
    if ( defined $params ) {
        ref $params eq 'ARRAY' or croak 'Bad event params in reached_event';

        defined $ev_data->{'params'} && $self->check_params( $name, $params );
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
    my ( $self, $event, $params ) = @_;

    if ( $self->{'params_type'} eq 'ordered' ) {
        # remove the fetched
    } else {
        # don't remove, just match
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
            my $ev_data = $self->{'tests'}{$test};

            if ( exists $ev_data->{'count'} ) {
                $self->check_count( $test, $ev_data->{'count'} );
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
                params => [ ARG0 .. $#_ ],
            );

            goto &$old_sub;
        };

        $internal_data->{$sub_to_override} = $new_sub;
    }
}

sub _seq_order {
    my ( $self, $event, @args ) = @_;

    # check whether we should run _seq_order or not
    $self->_should_add( $event, 'test_sequence' ) or return;

    my $value = $self->{'test_sequence'}{$event} || q{};

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
        $self->{'track_seq'}{$event}{'max'} = $max;
    } elsif ( ! ref $value ) {
        # just setting the max value for each sub
        $self->{'track_seq'}{$event}{'max'} = $value;
    } else {
        carp "Problem with value: $value\n";
    }

    # checking parameter
    if ( my $event_params = $self->{'test_event_params'}{$event} ) {
        my $current_params  = @args ? \@args : [];

        # event_params defined, we can check
        if ( $self->{'event_params_type'} eq 'ordered' ) {
            my $expected_params = shift @{$event_params} || [];

            cmp_bag(
                $current_params,
                $expected_params,
                "($event) Correct params",
            );
        } elsif ( my $type = $self->{'event_params_type'} eq 'unordered' ) {
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

    $self->{'track_seq'}{$event}{'cur'}++;
    return;
}

sub _seq_check_deps {
    my ( $self, $got_deps, $event ) = @_;
    my @exp_deps = keys %{ $self->{'track_seq'} };
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

1;


package POE::Test::Helpers::Session;

use strict;
use warnings;
use Carp;
use POE::Session;
use parent 'Test::Builder::Module';
use namespace::autoclean;

use List::AllUtils     qw( first none );
use Test::More;

sub spawn {
    my ( $class, %opts ) = @_;

    $opts{ lc $_ } = delete $opts{$_} for keys %opts;
    my $self       = bless { %opts }, $class;

    $self->{'session_id'} = POE::Session->create(
        object_states => [
            $self => [ '_start', '_child' ],
        ],
    )->ID;

    return $self;
}

sub _child {
    # this says that _start on our spawned session started
    # we should mark _start on our superhash
    my $self   = $_[OBJECT];
    my $change = $_[ARG0];

    if ( $change eq 'create' ) {
        $self->order( 0, '_start' );
        $self->_seq_order('_start');
    } elsif ( $change eq 'lose' ) {
        $self->order( -1, '_stop' );
        $self->_seq_order('_stop');
    }
}

sub _start {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    my ( $test_order, $test_sequence, $test_sequence_count ) =
        @{$self}{qw/ test_order test_sequence test_sequence_count /};

    # collect the keys of everyone
    # if exists key in test, add a test for it for them
    $self->{'session_id'} = $_[SESSION]->ID();

    # start with test_order
    my @subs_to_override  = ref $test_order eq 'ARRAY' ? @{$test_order} : ();

    # continue with test_sequence
    push @subs_to_override, ref $test_sequence eq 'HASH' ?
                            keys %{$test_sequence}       :
                            ();

    # continue with test_sequence_count
    push @subs_to_override, ref $test_sequence_count eq 'HASH' ?
                            keys %{$test_sequence_count}       :
                            ();

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
            # count the order
            $self->order( $count, $sub_to_override ) and $count++;

            # sequence order
            $self->_seq_order($sub_to_override);

            # sequence order count
            # ...

            goto &$old_sub;
        };

        $internal_data->{$sub_to_override} = $new_sub;
    }
}

sub _should_add {
    my ( $self, $event, $test ) = @_;
    my @test_events = ();

    if ( exists $self->{$test} ) {
        my @test_events = ();
        if ( ref $self->{$test} eq 'HASH' ) {
            @test_events = keys %{ $self->{$test} };
        } elsif ( ref $self->{$test} eq 'ARRAY' ) {
            @test_events = @{ $self->{$test} };
        }

        if ( first { $_ eq $event } @test_events ) {
            return 1;
        }
    }

    return;
}

# start this method with underscore as well
sub order {
    my ( $self, $order, $msg ) = @_;
    my $new_order   = $order + 1;
    my $order_count = $self->{'order_count'} || 0;

    $self->_should_add( $msg, 'test_order' ) or return;
    $order == -1 and $order = $order_count;

    is( $order, $order_count, "($order) $msg" );
    $self->{'order_count'} = $new_order;

    return 1;
}

sub _seq_order {
    my ( $self, $event, @args ) = @_;
    my $value = $self->{'test_sequence'}{$event} || q{};

    $self->_should_add( $event, 'test_sequence' ) or return;

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
    if ( my $event_params = $self->{'event_params'}{$event} ) {
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

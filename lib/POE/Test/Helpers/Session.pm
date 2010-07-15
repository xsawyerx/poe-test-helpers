package POE::Test::Helpers::Session;

use strict;
use warnings;
use Carp;
use POE::Session;
use parent 'Test::Builder::Module';
use namespace::autoclean;

use Test::More;

sub order {
    my ( $self, $order, $msg ) = @_;
    my $new_order   = $order + 1;
    my $order_count = $self->{'order_count'} || 0;

    $order == -1 and $order = $order_count;

    is( $order, $order_count, "($order) $msg" );
    $self->{'order_count'} = $new_order;
    return;
}

sub spawn {
    my ( $class, %opts ) = @_;

    $opts{ lc $_ } = delete $opts{$_} for keys %opts;
    my $self       = bless { %opts }, $class;

    $self->{'session_id'} = POE::Session->create(
        object_states => [
            $self => [ '_start', '_stop', '_child' ],
        ],
    )->ID;

    return $self;
}

sub _child {
    # this says that _start on our spawned session started
    # we should mark _start on our superhash
    my $self   = $_[OBJECT];
    my $change = $_[ARG0];

       if ( $change eq 'create' ) { $self->order(  0, '_start' ) }
    elsif ( $change eq 'lose'   ) { $self->order( -1, '_stop'  ) }
}

sub _start {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

    $self->{'session_id'} = $_[SESSION]->ID();
    my @subs_to_override  = ref $self->{'test_order'} eq 'ARRAY' ?
                            @{ $self->{'test_order'} }           :
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
            $self->order( $count, $sub_to_override );
            $count++;

            goto &$old_sub;
        };

        $internal_data->{$sub_to_override} = $new_sub;
    }
}

sub _stop {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
}

sub _seq_order {
    my ( $self, $event, @args ) = @_;
    my $value = $self->{'seq_ordering'}{$event} || q{};

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

1;

__END__
shift @{$session};
my $internal = $session->[SESSION]; # right?
my $old_method = $internal->{'next'};
my $new_method = sub {
    print "ack?\n";
    goto &$old_method;
};

$internal->{'next'} = $new_method;


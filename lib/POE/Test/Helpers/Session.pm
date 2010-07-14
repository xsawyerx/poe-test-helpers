package POE::Test::Helpers::Session;

use strict;
use warnings;
use POE::Session;
use parent 'Test::Builder::Module';
use namespace::autoclean;

$|=1;
sub spawn {
    my ( $class, %opts ) = @_;
    $opts{ lc $_ } = delete $opts{$_} for keys %opts;

    print "PTH: SPAWNED!\n";
    my $self = bless { %opts }, $class;

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
}

sub _start {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    print "PTH: _start\n";

    $self->{'session_id'} = $_[SESSION]->ID();
    my $cb = $self->{'run'};
    my $session = $cb->();
    my $internal = $session->[KERNEL];
    my $old_sub = $internal->{'next'};
    my $new_sub = sub { print "[INJECTED] HERE\n"; goto &$old_sub };
    $internal->{'next'} = $new_sub;
}

sub set_alias {
    my $self = shift;

    if ( my $alias = $self->{'alias'} ) {
        print "PTH: setting alias $alias\n";
        #$kernel->alias_set($alias);
    } else {
        print "PTH: incrementing refcount\n";
        #$kernel->refcount_increment( $self->{'session_id'} => __PACKAGE__ );
    }
}

sub _stop {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    print "PTH: _stop\n";
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


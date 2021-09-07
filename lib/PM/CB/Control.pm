package PM::CB::Control;

use warnings;
use strict;

use PM::CB::Communication;


sub new {
    my ($class, $struct) = @_;
    bless $struct, $class
}


sub start_comm {
    my ($self) = @_;
    $self->{communicate_t} = $self->{worker_class}->create(sub {
        my $communication = 'PM::CB::Communication'->new({
            to_gui   => $self->{to_gui},
            from_gui => $self->{to_comm},
            pm_url   => $self->{pm_url},
        });
        $communication->communicate;
    });

    my $counter = 10;
    while (1) {
        my $msg = $self->{from_gui}->dequeue_nb;
        last if $msg && 'quit' eq $msg->[0];


        if ($msg) {
            { random_url => sub { $self->{random_url} = $msg->[1] }
            }->{$msg->[0]}->();
        }

        sleep 1;
        $self->heartbeat;
        if ($self->{random_url} && ! $counter--) {
            $counter = 10;
            $self->{to_comm}->enqueue(['url', random_url()]);
            $self->{to_comm}->enqueue(['url']);
        };
    }
    $self->{to_comm}->insert(0, ['quit']);
    $self->{communicate_t}->join;
    $self->{to_gui}->insert(0, ['quit']);
}


sub random_url {
    (map +( $_, "www.$_" ), map "perlmonks.$_", qw( org net com ))[rand 6]
}


sub heartbeat {
    my ($self) = @_;

    unless ($self->{communicate_t}->is_running) {
        warn "PMCB: Restarting worker...\n";
        eval { $self->{communicate_t}->join };
        $self->start_comm;
        $self->{to_gui}->enqueue(['send_login']);
    }
}


__PACKAGE__

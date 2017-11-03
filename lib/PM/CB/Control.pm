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
        my $communication = PM::CB::Communication->new({
            to_gui   => $self->{to_gui},
            from_gui => $self->{to_comm},
        });
        $communication->communicate;
    });
    while (1) {
        my $msg = $self->{from_gui}->dequeue_nb;
        last if $msg && 'quit' eq $msg->[0];
        sleep 1;
        $self->heartbeat;
    }
    $self->{to_comm}->insert(0, ['quit']);
    $self->{communicate_t}->join;
    $self->{to_gui}->insert(0, ['quit']);
}


sub heartbeat {
    my ($self) = @_;

    my $running = $self->{running};
    my $ok = $self->{worker_class}->$running;
    unless (2 == $ok) {
        warn "Restarting worker...\n";
        eval { $self->{communicate_t}->join };
        $self->start_comm;
        $self->{to_gui}->enqueue(['send_login']);
    }
}


__PACKAGE__

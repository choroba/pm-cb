package PM::CB::Communication;

use warnings;
use strict;

use constant {
    PM_URL        => 'http://www.perlmonks.org/bare/?node_id=',
    FREQ          => 7,
    # Node ids:
    LOGIN         => 109,
    CB            => 207304,
    SEND          => 227820,
    PRIVATE       => 15848,
};


sub new {
    my ($class, $struct) = @_;
    bless $struct, $class
}


sub communicate {
    my ($self) = @_;
    require XML::LibXML;
    require WWW::Mechanize;
    require Time::HiRes;

    my $mech = $self->{mech} =
        'WWW::Mechanize'->new( timeout => 16, autocheck => 0 );

    my ($from_id, $previous, %seen);

    my $last_update = -1;
    my ($message, $command);
    my %dispatch = (
        login => sub { $self->login(@$message)
                           or $self->{readQ}->enqueue(['login']) },
        send  => sub { $message->[0] =~ tr/\x00-\x20/ /s;
                       $self->send_message($message->[0]) },
        title => sub { $self->get_title(@$message) },
        quit  => sub { no warnings 'exiting'; last },
    );

    while (1) {
        if ($message = $self->{writeQ}->dequeue_nb) {
            $command = shift @$message;
            $dispatch{$command}->();
        }

        Time::HiRes::usleep(250_000);
        next if time - $last_update < FREQ;

        $last_update = time;

        my $url = PM_URL . CB;
        $url .= ";fromid=$from_id" if defined $from_id;
        $mech->get($url);

        my $xml;
        if (eval {
            $xml = 'XML::LibXML'->load_xml(string => $mech->content);
        }) {

            my @messages = $xml->findnodes('/chatter/message');

            my $time = $xml->findvalue('/chatter/info/@gentimeGMT');

            for my $message (@messages) {
                my $id = $message->findvalue('message_id');
                if (! exists $seen{$id}) {
                    $self->{readQ}->enqueue([
                        chat => $time,
                                $message->findvalue('author'),
                                $message->findvalue('text') ]);
                    undef $seen{$id};
                }
            }
            $self->{readQ}->enqueue([ time => $time, !! @messages ]);

            my $new_from_id = $xml->findvalue(
                '/chatter/message[last()]/message_id');
            $from_id = $new_from_id if length $new_from_id;

            $previous = $xml;
        }

        my @private = $self->get_all_private(\%seen);
        for my $msg (@private) {
            $self->{readQ}->enqueue([
                private => @$msg{qw{ author time text }}
            ]) unless exists $seen{"p$msg->{id}"};
            undef $seen{"p$msg->{id}"};
        }
    }
}


{   my %titles;
    sub get_title {
        my ($self, $id, $name) = @_;
        my $title = $titles{$id};
        unless (defined $title) {
            my $url = PM_URL . $id;
            require XML::LibXML;
            $self->{mech}->get($url . ';displaytype=xml');
            my $dom;
            eval {
                $dom = 'XML::LibXML'->load_xml(string => $self->{mech}->content)
            } or return;

            $titles{$id} = $title = $dom->findvalue('/node/@title');
        }
        $self->{readQ}->enqueue(['title', $id, $name, $title]);
    }
}


sub login {
    my ($self, $username, $password) = @_;
    my $response = $self->{mech}->get(PM_URL . LOGIN);
    if ($response->is_success) {
        $self->{mech}->submit_form(
            form_number => 1,
            fields      => { user   => $username,
                             passwd => $password,
        });
        return $self->{mech}->content
            !~ /^Oops\.  You must have the wrong login/m
    }
    return
}


sub send_message {
    my ($self, $message) = @_;
    return unless length $message;

    ( my $msg = $message )
        =~ s/(.)/ord $1 > 127 ? '&#' . ord($1) . ';' : $1/ge;
    my $response = $self->{mech}->post(
        PM_URL . SEND,
        Content   => { op      => 'message',
                       node    => SEND,
                       message => $msg }
    );
    my $content = $response->content;
    $self->{readQ}->enqueue([ private => '<pm-cb-g>', undef, $content ])
        unless $content =~ /^Chatter accepted/;
}


sub get_all_private {
    my ($self, $seen) = @_;

    my $url = PM_URL . PRIVATE;

    my ($max, @private);
  ALL:
    while (1) {
        $self->{mech}->get($url);
        last unless $self->{mech}->content =~ /</;

        my $xml;
        eval { $xml = 'XML::LibXML'->load_xml(string => $self->{mech}->content) }
            or last;

        my @messages;
        last unless @messages = $xml->findnodes('/CHATTER/message');

        for my $msg (@messages) {
            my $id = $msg->findvalue('@message_id');
            last ALL if $seen->{"p$id"};

            push @private, {
                author => $msg->findvalue('@author'),
                time   => $msg->findvalue('@time'),
                text   => $msg->findvalue('text()'),
                id     => $id,
            };
        }

        my $first = $messages[0]->findvalue('@message_id');
        $url = PM_URL . PRIVATE . "&prior_to=$first";
    }

    return @private
}


__PACKAGE__

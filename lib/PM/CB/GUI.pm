package PM::CB::GUI;

use warnings;
use strict;

use constant {
    TITLE        => 'PM::CB::G',
    PUBLIC       => 0,
    PRIVATE      => 1,
    GESTURE      => 2,
    HISTORY_SIZE => 100,
};


sub new {
    my ($class, $struct) = @_;
    bless $struct, $class
}


sub url {
    my ($self, $url) = @_;
    $url //= '__PM_CB_URL__';
    $url =~ s{__PM_CB_URL__}{https://$self->{browse_url}/?node=};
    return $url
}


sub gui {
    my ($self) = @_;

    require Time::Piece;
    my $tzoffset = Time::Piece::localtime()->tzoffset;
    $self->{last_date} = q();

    require Tk;

    require Tk::Dialog;
    require Tk::ROText;
    require Tk::Balloon;

    $self->{mw} = my $mw = 'MainWindow'->new(-title => TITLE);
    $self->{geometry} and $mw->geometry ($self->{geometry});
    $mw->protocol(WM_DELETE_WINDOW => sub { $self->quit });
    $mw->optionAdd('*font', "$self->{font_name} $self->{char_size}");

    my $read_f = $mw->Frame->pack(-expand => 1, -fill => 'both');
    $self->{read} = my $read
        = $read_f->ROText(-background => $self->{bg_color},
                          -foreground => $self->{fg_color},
                          -wrap       => 'word')
        ->pack(-expand => 1, -fill => 'both');
    $read->tagConfigure(author  => -foreground => $self->{author_color});
    $read->tagConfigure(private => -foreground => $self->{private_color});
    $read->tagConfigure(gesture => -foreground => $self->{gesture_color});
    $read->tagConfigure(seen    => -foreground => $self->{seen_color});
    $read->tagConfigure(time    => -foreground => $self->{time_color});

    my $balloon = $self->{balloon} = $mw->Balloon;

    my $last_update_f = $mw->Frame->pack;
    $self->{last_update} = my $last_update
        = $last_update_f->Label(-text       => 'No update yet',
                                -foreground => 'black')
        ->pack(-side => 'left');

    my $write_f = $mw->Frame->pack(-fill => 'x');
    $self->{write} = my $write = $write_f->Text(
        -height     => 3,
        -background => $self->{bg_color},
        -foreground => $self->{fg_color},
        -wrap       => 'word',
    )->pack(-fill => 'x');

    $write->bind('<Shift-Insert>', sub {
        my $paste = eval { $write->SelectionGet }
            // eval { $write->SelectionGet(-selection => 'CLIPBOARD') };
        $write->insert('insert', $paste) if length $paste;
    });

    my $button_f = $mw->Frame->pack;
    my $send_b = $button_f->Button(-text => 'Send',
                                   -command => sub { $self->send },
                                  )->pack(-side => 'left');
    $mw->bind("<$_>", sub { $write->delete('insert - 1 char');
                            $send_b->invoke }
    ) for qw( Return KP_Enter );

    my $seen_b = $button_f->Button(-text      => 'Seen',
                                   -command   => sub { $self->seen },
                                   -underline => 0,
                                  )->pack(-side => 'left');
    $mw->bind('<Alt-s>', sub { $seen_b->invoke });

    my $save_b = $button_f->Button(
        -text => 'Save',
        -command => sub { $self->save },
        -underline => 1
    )->pack(-side => 'left');
    $mw->bind('<Alt-a>', sub { $save_b->invoke });

    $self->{opt_b} = my $opt_b = $button_f->Button(
        -text => 'Options',
        -command => sub {
            $self->show_options;
        },
        -underline => 0,
    )->pack(-side => 'left');
    $mw->bind('<Alt-o>', sub { $opt_b->invoke });

    my $list_b = $button_f->Button(
        -text      => 'List Monks',
        -command   => sub { $self->list_monks },
        -underline => 0,
    )->pack(-side => 'left');
    $mw->bind('<Alt-l>', sub { $list_b->invoke });

    my $help_b = $self->{opt_h} = $button_f->Button(-text      => 'Help',
                                   -command   => sub { $self->help },
                                   -underline => 0,
                                  )->pack(-side => 'left');
    $mw->bind('<Alt-h>', sub { $help_b->invoke });

    my $quit_b = $button_f->Button(-text      => 'Quit',
                                   -command   => sub { $self->quit },
                                   -underline => 0,
                                  )->pack(-side => 'left');
    $mw->bind('<Alt-q>', sub { $quit_b->invoke });

    $mw->bind('<Prior>',
              sub { $self->{read}->yviewScroll(-1, 'pages')});
    $mw->bind('<Next>',
              sub { $self->{read}->yviewScroll( 1, 'pages')});

    $self->{history} = [""];
    $self->{history_index} = -1;
    $mw->bind('<Alt-comma>',
              sub {
                  $self->{history_index}--
                      unless $self->{history_index} <= -@{ $self->{history} };
                  $write->Contents(
                      $self->{history}[ $self->{history_index} ]
                  );
              });
    $mw->bind('<Alt-period>',
              sub {
                  $self->{history_index}++
                      unless $self->{history_index} == -1;
                  $write->Contents(
                      $self->{history}[ $self->{history_index} ]
                  );
              });

    my ($username, $password);

    $mw->repeat(1000, sub {
        my $msg;
        my %dispatch = (
            time       => sub { $self->update_time($msg->[0], $tzoffset,
                                                   $msg->[1]) },
            login      => sub { $self->login_dialog },
            chat       => sub { $self->show_message($tzoffset, @$msg);
                                $self->increment_unread; },
            private    => sub { $self->show_private(@$msg, $tzoffset);
                                $self->increment_unread; },
            title      => sub { $self->show_title(@$msg) },
            send_login => sub { $self->send_login },
            url        => sub { $self->{pm_url} = $msg->[0] },
            list       => sub { $self->show_list(@$msg) },
            quit       => sub { $self->{control_t}->join; Tk::exit() },

        );
        while ($msg = $self->{from_comm}->dequeue_nb) {
            my $type = shift @$msg;
            $dispatch{$type}->();
        }
    });

    $mw->after(1, sub { $self->login_dialog; $self->{write}->focus; });

    Tk::MainLoop();
}


sub send {
    my ($self) = @_;
    my $write = $self->{write};
    $self->{to_comm}->enqueue([ send => $write->Contents ]);
    splice @{ $self->{history} }, -1, 0, $write->Contents;
    shift @{ $self->{history} } if HISTORY_SIZE < @{ $self->{history} };
    $self->{history_index} = -1;
    $write->Contents(q());
}


sub list_monks {
    my ($self) = @_;
    $self->{to_comm}->enqueue(['list']);
}


sub show_options {
    my ($self) = @_;
    $self->{opt_b}->configure(-state => 'disabled');
    my $opt_w = $self->{mw}->Toplevel(-title => TITLE . ' Options');

    $self->{to_comm}->enqueue(['url'])
        if $self->{random_url} || ! exists $self->{pm_url};

    my $opt_f = $opt_w->Frame(-relief => 'groove', -borderwidth => 2)
        ->pack(-padx => 5, -pady => 5);

    my @opts = (
        [ 'Font Size'        => 'char_size' ],
        [ 'Font Family'      => 'font_name' ],
        [ 'Background Color' => 'bg_color' ],
        [ 'Foreground Color' => 'fg_color' ],
        [ 'Author Color'     => 'author_color' ],
        [ 'Private Color'    => 'private_color' ],
        [ 'Gesture Color'    => 'gesture_color' ],
        [ 'Timestamp Color'  => 'time_color' ],
        [ 'Seen Color'       => 'seen_color' ],
        [ 'Browser URL'      => 'browse_url' ],
    );

    my $new;
    for my $opt (@opts) {
        my $f = $opt_f->Frame->pack(-fill => 'x');
        $f->Label(-text => $opt->[0])->pack(-side => 'left');
        $f->Entry(
            -textvariable => \($new->{ $opt->[1] } = $self->{ $opt->[1] })
        )->pack(-side => 'right');
    }

    my $old_url = $self->{pm_url} // q();
    my $old_random = $self->{random_url};
    my $f = $opt_f->Frame->pack(-fill => 'x');
    $f->Label(-text => 'PerlMonks URL')->pack(-side => 'left');
    my $e;
    $f->Checkbutton(
        -variable => \$self->{random_url},
        -text     => 'Random',
        -command  => sub {
            $e->configure(-state => $self->{random_url}
                                    ? 'disabled' : 'normal' )
        }
    )->pack(-side => 'left');
    $e = $f->Entry(-textvariable => \$self->{pm_url},
              -state => $self->{random_url} ? 'disabled' : 'normal')
        ->pack(-side => 'right');

    my $time_f = $opt_f->Frame->pack(-fill => 'x');
    $opt_f->Label(-text => 'Show Timestamps')->pack(-side => 'left');
    $opt_f->Checkbutton(-variable => \(my $show_time = ! $self->{no_time}))
        ->pack(-side => 'right');

    my $info_f = $opt_w->Frame(-relief => 'groove', -borderwidth => 2)
        ->pack(-padx => 5, -pady => 5);
    $info_f->Label(
        -justify => 'left',
        -text => join "\n",
            'Threading model:',
            ($self->{mce} ? ('MCE::Hobo '     . $MCE::Hobo::VERSION,
                             'MCE::Shared '   . $MCE::Shared::VERSION)
                          : ('threads '       . $threads::VERSION,
                             'Thread::Queue ' . $Thread::Queue::VERSION)
            ),
        'Stack size: ' . 2 ** $self->{stack_size}
    )->pack(-side => 'left', -padx => 5);

    my $button_f = $opt_w->Frame->pack(-padx => 5, -pady => 5);
    my $apply_b = $button_f->Button(
        -text      => 'Apply',
        -underline => 0,
        -command   => sub{
            $new->{pm_url} = $self->{pm_url} if $self->{pm_url} ne $old_url;
            $self->update_options($show_time, $new);
            $opt_w->destroy;
            $self->{opt_b}->configure(-state => 'normal');
        },
    )->pack(-side => 'left');
    $opt_w->bind('<Alt-a>', sub { $apply_b->invoke });

    my $cancel_b = $button_f->Button(
        -text => 'Cancel',
        -command => my $cancel_s = sub {
            $self->{pm_url} = $old_url;
            $self->{random_url} = $old_random;
            $opt_w->destroy;
            $self->{opt_b}->configure(-state => 'normal');
        },
    )->pack(-side => 'left');
    $opt_w->bind('<Escape>', $cancel_s);
    $opt_w->protocol(WM_DELETE_WINDOW => $cancel_s);
}


sub update_options {
    my ($self, $show_time, $new) = @_;

    my $old_url = $self->{pm_url};
    for my $opt (keys %$new) {
        $self->{$opt} = $new->{$opt} if ! exists $self->{$opt}
                                     || $self->{$opt} ne $new->{$opt};
    }

    $self->{mw}->optionAdd('*font', "$self->{font_name} $self->{char_size}");
    for my $part (qw( read write last_update )) {
        $self->{$part}->configure(
            -font => $self->{mw}->fontCreate(
                -family => $self->{font_name},
                -size   => $self->{char_size},
            ),
            (-bg  => $self->{bg_color},
             -fg  => $self->{fg_color}) x ('last_update' ne $part),
        );
    }
    $self->{read}->tagConfigure(author => -foreground => $self->{author_color});
    $self->{read}->tagConfigure(seen   => -foreground => $self->{seen_color});
    $self->{read}->tagConfigure(time   => -foreground => $self->{time_color});
    $self->{read}->tagConfigure(
        private => -foreground => $self->{private_color});
    $self->{no_time} = ! $show_time;

    $self->{to_control}->enqueue(['random_url', $self->{random_url}]);
    if ($old_url ne $self->{pm_url}) {
        $self->{to_comm}->enqueue(['url', $self->{pm_url}]);
        $self->send_login;
    }
}


sub show_title {
    my ($self, $id, $name, $title) = @_;
    my $tag = "browse:$id|$name";
    my ($from, $to) = ('1.0');
    while (($from, $to) = $self->{read}->tagNextrange($tag, $from)) {
        $self->{read}->delete($from, $to);
        $self->{read}->insert($from, "[$title]", [$tag]);
        $from = $to;
    }
}


sub save {
    my ($self) = @_;
    my $file = $self->{mw}->getSaveFile(-title => 'Save the history to a file');
    return unless defined $file;

    if (open my $OUT, '>', $file) {
        print {$OUT} $self->{read}->Contents;
    } else {
        $self->{mw}->messageBox(
            -title => "Can't save",
            -icon  => 'error',
            -message => "'$file' can't be opened for writing",
            -type => 'Ok'
        );
    }
}


sub increment_unread {
    my ($self) = @_;
    my $title = $self->{mw}->cget('-title');
    if ($title =~ s/([0-9]+)/$1 + 1/e) {
        $self->{mw}->configure(-title => $title);
    } else {
        $self->{mw}->configure(-title => '[1] ' . TITLE);
    }
}


sub seen {
    my ($self) = @_;
    while (my ($from, $to) = $self->{read}->tagNextrange('unseen', '1.0')) {
        $self->{read}->tagRemove('unseen', $from, $to);
        $self->{read}->tagAdd('seen', $from, $to);
    }
    $self->{mw}->configure(-title => TITLE);
}


sub decode {
    require charnames;
    my ($msg) = @_;

    $msg =~ s/&#(x?)([0-9a-f]+);/$1 ? chr hex $2 : chr $2/gei;
    $msg =~ s/([^\0-\x{FFFF}])/
              "\x{2997}" . charnames::viacode(ord $1) . "\x{2998}"/ge
        if 'MSWin32' eq $^O;
    return $msg
}


sub show {
    my ($self, $timestamp, $author, $message, $type) = @_;

    my $text = $self->{read};
    $text->insert(end => "<$timestamp> ", ['time']) unless $self->{no_time};
    my $author_separator = $type == GESTURE ? "" : ': ';
    $text->insert(end => "[$author]$author_separator",
                  { (PRIVATE) => 'private',
                    (PUBLIC)  => 'author',
                    (GESTURE) => 'gesture' }->{$type});
    my ($line, $column) = split /\./, $text->index('end');
    --$line;
    $column += (3 + length($timestamp)) * ! $self->{no_time} + 2
        + length($author_separator) + length $author;
    $text->insert(end => "$message\n", ['unseen']);

    my $fix_length = 0;
    while ($message =~ m{\[(\s*(?:
                                 https?
                                 | (?:meta)?mod | doc
                                 | id
                                 | wp
                               )://.+?\s*|\S+)\]}gx
    ) {
        my $orig = $1;
        my ($url, $name) = split /\|/, $orig;
        my $from = $line . '.'
                 . ($column + pos($message)
                    - length(length $name ? "[$url|$name]" : "[$url]")
                    - $fix_length);
        my $to = $line . '.' . ($column - $fix_length + pos $message);
        $text->delete($from, $to);

        $name = $url unless length $name;
        s/^\s+//, s/\s+$// for $name, $url;
        $url =~ s{^(?:(?:meta)?mod|doc)://}{http://p3rl.org/};
        $url =~ s{^wp://}{https://en.wikipedia.org/wiki/};

        my $tag = "browse:$url|$name";

        if ($url =~ m{^id://([0-9]+)}) {
            my $id = $1;
            $self->ask_title($id, $url) if $name eq $url;
            $url = '__PM_CB_URL__' . $id;
            $tag = "browse:$id|$name";
        } elsif ($url eq $orig) {
            substr $url, 0, 0, '__PM_CB_URL__';
            $tag = "browse:$url|$name";
        }

        $fix_length += length($orig) - length($name);

        $self->add_clickable($name, $tag, $from, $url);
    }
    $text->see('end');
}


sub add_clickable {
    my ($self, $name, $tag, $from, $url) = @_;
    my $text = $self->{read};
    $text->tagConfigure($tag => -underline => 1);
    $text->insert($from, "[$name]", [$tag]);
    $text->tagBind($tag, '<Enter>',
                   sub { $self->{balloon}->attach(
                       $text,
                       -balloonmsg      => $self->url($url),
                       -state           => 'balloon',
                       -balloonposition => 'mouse') });
    $text->tagBind($tag, '<Leave>',
                   sub { $self->{balloon}->detach($text) });
    $text->tagBind($tag, '<Button-1>',
                   sub { browse($self->url($url)) });
    $text->tagBind($tag, $self->{copy_url} || '<Control-Button-1>',
                   sub { $text->clipboardAppend($self->url($url)) });
}


sub show_list {
    my ($self, @monks) = @_;
    $self->{read}->insert('end', '[Active Monks]', ['private']);
    for my $monk (@monks) {
        $self->{read}->insert('end', ' ');
        $self->add_clickable("$monk", "browse:$monk", 'end',
                             $self->url("__PM_CB_URL__$monk"));
    }
    $self->{read}->insert('end', "\n");
}


sub ask_title {
    my ($self, $id, $name) = @_;
    $self->{to_comm}->enqueue(['title', $id, $name]);
}


sub browse {
    my ($url) = @_;
    my $action = {
        MSWin32 => sub { system 1, qq{start "$url" /b "$url"} },
        darwin  => sub { system qq{open "$url" &} },
    }->{$^O}    || sub { system qq{xdg-open "$url" &} };
    $action->();
}


sub show_message {
    my ($self, $tzoffset, $timestamp, $author, $message) = @_;

    my $type = $message =~ s{^/me(?=\s|')}{} ? GESTURE : PUBLIC;
    $message = decode($message);
    $timestamp = convert_time($timestamp, $tzoffset)
                 ->strftime('%Y-%m-%d %H:%M:%S');

    substr $timestamp, 0, 11, q() if 0 == index $timestamp, $self->{last_date};
    $self->show($timestamp, $author, $message, $type);
}


sub show_private {
    my ($self, $author, $time, $msg, $tzoffset) = @_;
    $msg = decode($msg);
    $msg =~ s/[\n\r]//g;

    if (defined $time) {
        local $ENV{TZ} = 'America/New_York';
        my $est = Time::Piece::localtime()->tzoffset;
        $time = 'Time::Piece'->strptime($time, '%Y-%m-%d %H:%M:%S')
              - $est + $tzoffset;
    } else {
        $time = Time::Piece::localtime();
    }
    $time = $time->strftime('%Y-%m-%d %H:%M:%S');

    $self->show($time, $author, $msg, PRIVATE);
}


sub convert_time {
    my ($server_time, $tzoffset) = @_;
    my $local_time = 'Time::Piece'->strptime(
        $server_time, '%Y-%m-%d %H:%M:%S'
    ) + $tzoffset;  # Assumption: Server time is in UTC.
    return $local_time
}


sub update_time {
    my ($self, $server_time, $tzoffset, $should_update) = @_;
    my $local_time = convert_time($server_time, $tzoffset);
    $self->{last_update}->configure(
        -text => 'Last update: '
                 . $local_time->strftime('%Y-%m-%d %H:%M:%S'));
    $self->{last_date} = $local_time->strftime('%Y-%m-%d') if $should_update;
}


{   my ($login, $password);
    sub send_login {
        my ($self) = @_;
        $self->{to_comm}->enqueue([ 'login', $login, $password ]);
    }

    sub login_dialog {
        my ($self) = @_;

        my $dialog = $self->{mw}->Dialog(
            -title          => 'Login',
            -default_button => 'Login',
            -buttons        => [qw[ Login Cancel ]]);

        my $username_f = $dialog->Frame->pack(-fill => 'both');
        $username_f->Label(-text => 'Username: ')
            ->pack(-side => 'left', -fill => 'x');
        my $username_e = $username_f->Entry->pack(-side => 'left');
        $username_e->focus;

        my $password_f = $dialog->Frame->pack(-fill => 'both');
        $password_f->Label(-text => 'Password: ')
            ->pack(-side => 'left', -fill => 'x');
        my $password_e = $password_f->Entry(-show => '*')->pack(-side => 'right');

        my $reply = $dialog->Show;
        if ('Cancel' eq $reply) {
            $self->quit;
            return
        }

        ($login, $password) = ($username_e->get, $password_e->get);
        $self->send_login;
    }
}


sub quit {
    my ($self) = @_;
    print STDERR "Quitting...\n";
    $self->{to_control}->insert(0, ['quit']);
}


sub help {
    my ($self) = @_;
    $self->{opt_h}->configure(-state => 'disabled');
    my $top = $self->{mw}->Toplevel(-title => TITLE . ' Help');
    my $text = $top->ROText(height => 4)->pack;
    $text->insert('end', "<Alt+,> previous history item\n");
    $text->insert('end', "<Alt+.> next history item\n");
    $text->insert('end', "\n<Esc> to exit help");
    $top->bind('<Escape>', my $end = sub {
                   $top->DESTROY;
                   $self->{opt_h}->configure(-state => 'normal');
               });
    $top->protocol(WM_DELETE_WINDOW => $end);
}

__PACKAGE__

# cpanfile

on build => sub {
    my $does_threads = eval { require threads; 1 };

    if ( $does_threads ) {
        suggests 'MCE::Hobo';
        suggests 'MCE::Shared';
    } else {
        requires 'MCE::Hobo';
        requires 'MCE::Shared';
    }
};

requires 'Time::HiRes';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

# END

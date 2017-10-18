# BEGIN

on configure => sub {
    if ( `perl -V` =~ /useithreads=undef/ ) {
        requires 'MCE::Hobo';
        requires 'MCE::Shared';
    } else {
        requires 'Thread::Queue';
        suggests 'MCE::Hobo';
        suggests 'MCE::Shared';
    };
};

requires 'Time::HiRes';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

# END

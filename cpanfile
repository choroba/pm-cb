# BEGIN
use Config;

on build => sub {
    if ( ! $Config{'usethreads'} ) {
        requires 'MCE::Hobo';
        requires 'MCE::Shared';
    } else {
        suggests 'MCE::Hobo';
        suggests 'MCE::Shared';
    };
};

requires 'Time::HiRes';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

# END

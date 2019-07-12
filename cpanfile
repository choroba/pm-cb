use Config;

on build => sub {
    if ($Config{usethreads}) {
        suggests 'MCE::Child';
        suggests 'MCE::Channel';
    } else {
        requires 'MCE::Child';
        requires 'MCE::Channel';
    }
};

requires 'FindBin';
requires 'Getopt::Long';
requires 'Pod::Usage';
requires 'Time::HiRes';
requires 'Time::Piece';
requires 'charnames';

requires 'LWP::Protocol::https';
requires 'Syntax::Construct';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

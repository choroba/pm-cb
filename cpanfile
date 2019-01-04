use Config;

on build => sub {
    if ($Config{usethreads}) {
        suggests 'MCE::Hobo';
        suggests 'MCE::Shared';
    } else {
        requires 'MCE::Hobo';
        requires 'MCE::Shared';
    }
};

requires 'FindBin';
requires 'Getopt::Long';
requires 'Pod::Usage';
requires 'Time::HiRes';
requires 'Time::Piece';
requires 'charnames';

requires 'Syntax::Construct';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

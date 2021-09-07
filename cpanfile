use Config;

# The MCE 1.841 distribution includes MCE::Channel and MCE::Child.
# Thus, suggesting or requiring MCE::Child will pick up minimally MCE 1.841.
# MCE::Hobo is included with MCE::Shared.

on build => sub {
    if ($Config{usethreads}) {
        suggests 'MCE::Child';
        suggests 'MCE::Hobo';
    } else {
        requires 'MCE::Child';
        requires 'MCE::Hobo';
    }
    suggests 'MCE::Child';
    suggests 'MCE::Channel';
};

requires 'FindBin';
requires 'Getopt::Long';
requires 'Pod::Usage';
requires 'Time::HiRes';
requires 'Time::Piece';
requires 'charnames';

requires 'List::Util';
requires 'LWP::Protocol::https';
requires 'Syntax::Construct';
requires 'Tk';
requires 'WWW::Mechanize';
requires 'XML::LibXML';

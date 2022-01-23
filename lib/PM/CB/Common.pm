package PM::CB::Common;

use warnings;
use strict;

use Exporter qw{ import };
our @EXPORT_OK = qw{ to_entities };

sub to_entities {
    my ($message) = @_;
    $message =~ s/(.)/ord $1 > 127 ? '&#' . ord($1) . ';' : $1/ge;
    return $message
}


__PACKAGE__

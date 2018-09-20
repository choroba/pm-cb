#!/pro/bin/perl

use 5.14.2;
use warnings;
use Term::ANSIColor;

my $pat = shift // ".";

my %conf;
my $home = $ENV{HOME} || $ENV{USERPROFILE} || $ENV{HOMEPATH};
foreach my $rcf (grep { -s }
	"$home/pm-cb.rc", "$home/.pm-cbrc", "$home/.config/pm-cb") {
    my $mode = (stat $rcf)[2];
    $mode & 022 and next;
    open my $fh, "<", $rcf or next;
    while (<$fh>) {
	m/^\s*[;#]/ and next;
	$mode & 044 && m/password/i and next;
	my ($k, $v) = (m/^\s*([-\w]+)\s*[:=]\s*(.*\S)/) or next;
	$conf{ lc $k
	    =~ s{-}{_}gr
	    =~ s{[-_]colou?r$}{_color}ir
	    =~ s{background}{bg}ir
	    =~ s{foreground}{fg}ir
	    =~ s{^(?:unicode|utf-?8?)$}{utf8}ir
	    =~ s{^use_}{}ir
	    =~ s{font_size}{char_size}ir
	    =~ s{font_family}{char_name}ir
	    =~ s{show_time(?:stamps?)}{show_time}ir
	    =~ s{copy_url$}{copy_link}ir
	  } = $v
	    =~ s{U\+?([0-9A-Fa-f]{2,7})}{chr hex $1}ger
	    =~ s{^(?:no|false)$}{0}ir
	    =~ s{^(?:yes|true)$}{1}ir;
	}
    }
exists $conf{show_time} and $conf{no_time} = !delete $conf{show_time};
$conf{font_name} =~ m/\s/ and $conf{font_name} = "{".$conf{font_name}."}";
$conf{copy_link} =~ s{^<*(.*?)>*$}{<$1>};

my $ct = color ("grey15");	# color ($conf{time_color}   || "darkcyan") || color ("grey15");
my $ca = color ("bright_blue");	# color ($conf{author_color} || "blue")     || color ("bright_blue");
my $cu = color ("red");		# color ($conf{self_color}   || "red")      || color ("red");
my $cr = color ("reset");

my $user = lc ($conf{username} || $ENV{logname});

if (my $hf = $conf{history_file}) {
    $hf =~ s/~/$ENV{HOME}/;
    if (open my $fh, '<:encoding(utf-8)', $hf) {
	local $/ = "\x{2028}";
	chomp (my @hist = <$fh>);
	for (grep m/$pat/i => @hist) {
	    my ($time, $author, $msg) = split m/\x{2063}/ => $_;
	    $msg =~ s/[\r\n\s]*\z//;
	    my $dc = $user eq lc $author =~ s/^\W+//r =~ s/\W+$//r ? $cu : $ca;
	    say $ct, $time, $dc, $author, $cr, $msg;
	    }
	}
    }

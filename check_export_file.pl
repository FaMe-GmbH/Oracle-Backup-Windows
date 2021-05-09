use Getopt::Long;
use strict;

my ($filename, $min_size);
GetOptions("filename=s" => \$filename, "min-size=s" => \$min_size);
if (! $filename) {
	die "Script $0 requires a filename.";
}
elsif (! -f $filename) {
	die "File $filename does not exist.";
}
if ($min_size =~ /(\d+)([KMG])?/i) {
	if (uc($2) eq "K") {
		$min_size = $1 * 1024;
	}
	elsif (uc($2) eq "M") {
		$min_size = $1 * 1024 * 1024;
	}
	elsif (uc($2) eq "G") {
		$min_size = $1 * 1024 * 1024 * 1024;
	}
	elsif (uc($2) eq "B") {
		$min_size = $1;
	}
	elsif ($2) {
		print STDERR "ignoring invalid parameter min_size=$min_size.\n";
	}
	else {
		$min_size = $1;
	}
}
else {
	$min_size = 100 * 1024 * 1024; # 100MB default min. size
}

my @stat = stat($filename); 
if ($stat[7] < $min_size) {
	print STDERR "File $filename has size=$stat[7] and is smaller than minimum size $min_size.\n";
	exit 10;
} elsif ($stat[9] < time() - 86400 / 2) {
	print STDERR "File $filename has size=$stat[7] but is older than 12 hours\n";
	exit 20;
}
else {
	print STDERR "File check OK - $filename has size=$stat[7] (minimum = $min_size) and is newer than 12 hours\n";
	exit 0;
}

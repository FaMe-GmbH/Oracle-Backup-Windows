# check_ftp_transfer_log.pl:
# reads the WinSCP log file
# The logfile must contain a line matching this pattern:
# C:\oracle\admin\Q1268\backup\backup_Q1268_20210509-1612.dmp.zip |         313 KB | 3609.2 KB/s | binary | 100%
# and must not contain any messages like
#   General failure (server should provide error description).
#   Error code: <number>
#   Error message from server: Failure
#
# Exit codes:
#   0: OK
#   1: general failure
# 100: parameter error - no file checked
# 101: cannot open logfile - no file checked
# 102: file transfer incomplete
# others: explicit FTP error code

# script parameters:
# check_ftp_transfer_log.pl <winscp logfile>

use strict;

if (! @ARGV) {
	print STDERR "Usage $0 [WinSCP logfile]\n";
	exit 100;
}
my $err = 0;
my $success = 0;
if (open(LOG, $ARGV[0])) {
	foreach (<LOG>)
	{
		chomp;
		if (/Error code:\s*(\d+)/i && $1 > 0) {
			print STDERR "Error message from FTP log: $_\n";
			$err = $1;
		}
		elsif ($err == 0 && /failure/i) {
			print STDERR "Error message from FTP log: $_\n";
			$err = 99;
		}
		elsif (/\|\s*binary\s*\|/) {
			my @f = split(/\|/, $_);
			if (@f == 5 && $f[4] =~ /^\s*100\%/) {
				$success = 1;
			}
		}
	}
	close LOG;
	if ($err > 0) {
		exit $err;
	}
	elsif (! $success) {
		print STDERR "FTP log does not contain any error messages but the file transfer was not completed.\n";
		exit 102;
	}
	else {
		print STDERR "FTP transfer log OK.\n";
		exit 0;
	}
}
else {
	print STDERR "cannot open file $ARGV[0]: $!\n";
	exit 101;
}


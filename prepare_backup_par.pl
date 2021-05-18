# usage: $0 [--prepare|--check_ftp_dir|--check_ftp_transfer|--logfile_name|--check_day_of_week [--manual]] [--ftp_login=[URL]] [--remote_ftp_dir=[directory]]
#
# Option --prepare (default):
# Reads the FAME_BACKUP_DIR directory from the dir.txt file
# Sets up the backup.par file and the ftp file transfer scripts winscp.ftpcommand1 and winscp.ftpcommand2
# (winscp.ftpcommand* for Windows only)
# Print the full path and filename of the DUMPFILE on STDOUT.
# Requires the option --ftp_login or the ENV variable FTP_LOGIN
# Requires the option --remote_ftp_dir or the ENV variable REMOTE_FTP_DIR
#
# Option --check_ftp_dir: used with Windows ftp tool only
# reads file ftp1.log which must contain a line 
#    257 "/mnt/backup/database/<computername>/<YYYYMM>"
# script dies with error message if this line is not found
#
# Option --check_ftp_transfer: used with Windows ftp tool only
# reads file ftp2.log which must contain predefined FTP server messages in a predefined sequence
# script dies with error message if this sequence is not found
#
# Option --logfile-name:
# determines a filename for the logfile and prints it to STDOUT.
#
# Option --check_day_of_week [--manual]
# prints date and time
# dies on Sundays and Mondays;  i.e. no backup on Sundays and Mondays, except if --manual is passed in as well
#



use POSIX qw(strftime); 
use Getopt::Long;

# commandline options:
my $logdate = 0;
my $prepare = 0;
my $check_ftp_dir = 0;
my $check_ftp_transfer = 0;
my $logfile_name = "";
my $check_day_of_week = 0;
my $manual = 0;
my $ftp_login="";
my $remote_ftp_dir="";
GetOptions ("logdate" => \$logdate,
			"prepare" => \$prepare,
			"check_ftp_dir" => \$check_ftp_dir,
			"check_ftp_transfer"  => \$check_ftp_transfer,
			"logfile_name"  => \$logfile_name,
			"manual"  => \$manual,
			"check_day_of_week"  => \$check_day_of_week,
			"ftp_login=s" => \$ftp_login,
			"remote_ftp_dir=s" => \$remote_ftp_dir)
  or die("usage: $0 [--logdate|--prepare|--check_ftp_dir|--check_ftp_transfer|--logfile_name|--check_day_of_week [--manual]]");


$ftp_login = ($ftp_login ? $ftp_login : $ENV{FTP_LOGIN});
$remote_ftp_dir = ($remote_ftp_dir ? $remote_ftp_dir : $ENV{REMOTE_FTP_DIR});

my $t = strftime('%Y%m%d-%H%M', localtime()); 
my $computername = lc($ENV{COMPUTERNAME} ? $ENV{COMPUTERNAME} : $ENV{HOSTNAME});
if (! $computername) {
	die "ENV variables HOSTNAMEN and COMPUTERNAME are both not defined.";
}
$computername =~ s/(\w+)(\..*)/$1/;
  
# called to check the FTP remote directory?
if ($check_ftp_dir) {
	my $dir_ok = 0;
	open (FTP1LOG, "ftp1.log") || die "cannot open file ftp1.log: $!";
	foreach (<FTP1LOG>)
	{
		if (m!^257\s+\"/mnt/backup/database/$computername/?\"!) {
			$dir_ok = 1;
		}
	}
	close FTP1LOG;
	if ($dir_ok) {
		print "FTP directory /mnt/backup/database/$computername OK\n";
		exit(0);
	}
	else {
		die "FTP directory /mnt/backup/database/$computername does not exist.\n"
	}
}

# called to check the FTP transfer?
elsif ($check_ftp_transfer) {
	my $dir_ok = 0;
	# expect these FTP messages:
	my @lines2check = (
		"230 Login successful.",
		"250 Directory successfully changed.",
		"200 Switching to Binary mode.",
		"200 PORT command successful. Consider using PASV.",
		"150 Ok to send data.",
		"226 Transfer complete.",
		"221 Goodbye."
	);
	my $k = 0;
	open (FTP2LOG, "ftp2.log") || die "cannot open file ftp2.log: $!";
	# read logfile lines and compare FTP messages with those from the list:
	foreach (<FTP2LOG>)
	{
		chomp;
		s/\s+$//;
		if ($k < @lines2check && $_ eq $lines2check[$k]) {
			++$k;
		}
	}
	close FTP2LOG;
	if ($k == @lines2check) {
		# all FTP server responses found:
		exit(0);
	}
	else {
		die "FTP transfer did not succeed. Check file ftp2.log.";
	}
}

# called to determine the name of the backup.log?
elsif ($logfile_name) {
	print "backup.$t.log";
	exit(0);
}

# called to set the logdate?
elsif ($logdate) {
	print $t;
	exit(0);
}

# Called to tell whether we back up today?
elsif ($check_day_of_week) {
	print scalar(localtime()), "\n";
	my @tm = localtime();
	if ($tm[6] < 2 && ! $manual) {
		die "No backup on Sundays and Mondays.";
	}
	else {
		exit(0);
	}
}

if (length("$ENV{ORACLE_SID}") == 0) {
	die "ENV variable ORACLE_SID is not defined.";
}
my $file = "backup_${computername}_$ENV{ORACLE_SID}_$t.dmp";

# check dir.txt:
my $directory = "";
open(DIRTXT, "dir.txt") || die "File dir.txt is missing: $!";
foreach (<DIRTXT>)
{
	chomp;
	s/^\s+//;
	s/\s+$//;
	if (! $directory && $_ && -d $_) {
		$directory = $_;
	}
}
close DIRTXT;
if (! $directory) {
	die "$ENV{ORACLE_SID}: Oracle directory FAME_BACKUP_DIR is not defined or not valid.";
}

open (BACKUP_PAR, ">backup.par") || die "cannot write file backup.par: $!";
print BACKUP_PAR <<EOF
# file created by $0 on $t
DUMPFILE=$file
FULL=Y
LOGFILE=$file.log
DIRECTORY=FAME_BACKUP_DIR
EOF
;
close BACKUP_PAR;

# WinSCP command files: Windows only.
if ($^O =~ /mswin32/i) {
	unless ($remote_ftp_dir)	{ die "remote_ftp_dir is not set. Stop."; }
	unless ($ftp_login) 		{ die "ftp_login is not set. Stop."; }

	open(FTPCOM1, ">winscp.ftpcommand1.$ENV{ORACLE_SID}") || die "cannot write file winscp.ftpcommand1.$ENV{ORACLE_SID}: $!";
	print FTPCOM1 <<EOF
option batch on
open $ftp_login
cd $remote_ftp_dir
pwd
bye
EOF
;
	close FTPCOM1;

	open(FTPCOM2, ">winscp.ftpcommand2.$ENV{ORACLE_SID}") || die "cannot write to file winscp.ftpcommand2.$ENV{ORACLE_SID}: $!";
	print FTPCOM2 <<EOF
option batch on
open $ftp_login
cd $remote_ftp_dir
option transfer binary
put $directory\\$file.zip
close
exit
EOF
;
	close FTPCOM2;
}

# Script output is expected by batch file:
if ($^O =~ /mswin32/i) {
	print "$directory\\$file";
}
else {
	print "$directory/$file";
}

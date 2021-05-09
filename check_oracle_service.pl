# checks the output of 
#	sc query OracleServiceXXXX
# expects a line 
#         STATE              : 4  RUNNING
# if such a line is not found, the program dies / returns a non-zero value.
my $oracle_service_running = 0;
foreach (<>)
{
	if (/^\s*STATE\s+:\s+4\s+RUNNING\s*$/) {
		$oracle_service_running = 1;
	}
}
if ($oracle_service_running) {
	print "Oracle Service $ENV{ORACLE_SID} is running.\n";
	exit(0);
} 
else { 
	die "Oracle Service $ENV{ORACLE_SID} is NOT running. Stop.";
}


# reads backup.conf and returns all instances that are to be backed up
# expects lines in backup.conf to have to following format:
# instance:[Y|Yes|N|No|<days>]
# where <days> are week days, maybe a list of them, even ranges. 
# Example:
# TESTDB: MON, WED, FRI-SUN
 

# Lookup tables for day names and numbers:
my @days = qw (SUN MON TUE WED THU FRI SAT); # days in localtime() numbering order
my %daytab;
for (my $i = 0 ; $i < @days ; $i++)
{
	$daytab{$days[$i]} = $i; # lookup table for DAY => number
}
my @today = localtime();
my $day_of_week = $today[6];
# Apply TESTDAY environment variable:
if ($ENV{TESTDAY}) {
	for (my $i = 0 ; $i < @days ; $i++)
	{
		if ($days[$i] eq uc($ENV{TESTDAY})) {
			$day_of_week = $i;
			last;
		}
	}
}
my $result = "";
open(CONF, "backup.conf") || die "cannot read file backup.conf: $!";
foreach (<CONF>)
{
	chomp;
	s/\s+//g;	# remove *any* whitespace
	s/#.*//;	# remove comments
	if (/^(\w+):/) {
		my @instance_def = split(/:/, $_);
		my $instance_name = shift @instance_def;
		my $backup_instance = 0;
		# intially there is no day the instance is to be backed up:
		my @days4instance = (0, 0, 0, 0, 0, 0, 0);
		# backup_all.cmd parameter --manual flags "run all backups now"
		if ($ENV{MANUAL} == 1) {
			$backup_instance = 1;
			print STDERR "MANUAL=1 detected.\n";
		}
		# backup_all.cmd parameter --instance <INSTANCE> flags "run this backup now"
		elsif ($ENV{INSTANCE} eq $instance_name) {
			$backup_instance = 1;
			print STDERR "INSTANCE=$ENV{INSTANCE} detected.\n";
		}
		elsif (! $ENV{INSTANCE} && @instance_def) {
			my $backup_flags = uc(shift(@instance_def));
			# print "instance_name=$instance_name  backup_flags=$backup_flags\n";
			if ($backup_flags =~ /\b(Y|YES)\b/i) {
				$backup_instance = 1;
			}
			else {
				my @backup_days = ($backup_flags =~ /([A-Z]{3}-?)/ig);
				if (@backup_days) {
					for (my $i = 0 ; $i < @backup_days ; $i++)
					{
						# print "backup_days[$i]=$backup_days[$i]\n";
						if ($backup_days[$i] =~ /\w+-/ && $i + 1 < @backup_days && $backup_days[$i+1] =~ /^\w+$/) {
							chop $backup_days[$i];
							if (exists($daytab{$backup_days[$i]}) && exists($daytab{$backup_days[$i+1]})
							&&  $daytab{$backup_days[$i]} < $daytab{$backup_days[$i+1]}) {
								# valid range definition:
								for (my $j = $daytab{$backup_days[$i]} ; $j <= $daytab{$backup_days[$i+1]} ; $j++)
								{
									# mark all days in range as days for backup
									$days4instance[$j] = 1;
								}
							}
							else {
								print STDERR "(1) bad backup schedule definition \"$_\"- ignored\n";
								last;
							}
						}
						elsif (exists($daytab{$backup_days[$i]})) {
							$days4instance[$daytab{$backup_days[$i]}] = 1;
						}
						else {
							print STDERR "(2) bad backup schedule definition \"$_\"- ignored\n";
							last;
						}
					}
					# backup today?
					if ($days4instance[$day_of_week]) {
						$backup_instance = 1; # yes
					}
				}
			}
		}
		if ($backup_instance) {
			print "$instance_name\n";
		}
	}
}
close CONF;



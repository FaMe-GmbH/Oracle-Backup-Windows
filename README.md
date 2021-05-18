Oracle-Backup-Windows

# 1. Introduction

These scripts run Oracle database exports for selected instances.
A configuration sets the weekly schedule for automatic exports
for each instance individually.

Each export file is named using the following schema:
    backup_COMPUTERNAME_INSTANCE_YYYYMMDD_HHMI.dmp

After running the export the export file and export log file are
packed as a 7Zip or zip archive and uploaded to an SFTP or FTP site.
The local files will be removed in the end, even if zipping or FTP transfer fails.

Instances are either selected by a configuration file or by running 
    backup_all.cmd --instance [Name]
from the command line.

All exports are assumed to be full exports and to be run as SYSTEM.

Requirements:
- Oracle export tool expdp
- Perl for several scripts (available through the Oracle software installation if installed on the database server)
- 7Zip or simply zip to zip export dump files
- WinSCP (modify the scripts to use another FTP client or whatever to transfer the export files)
- tee (available through, for instance, UnxUtils)

# 2. Configuration

## 2.1 Databases and schedule

The file backup.conf lists all Oracle instances to export plus their weekly schedule:
    P1000:MON-FRI:SYSTEM/manager
    P2000:MON,WED,SAT

The Oracle instance P1000 is to be exported daily from Monday till Friday.
The SYSTEM password for P1000 is "manager".

The Oracle instance P2000 is to be exported on Monday, Wednesday, and Saturday.
The SYSTEM password for P2000 is the default password set in backup-settings.cmd.

Comments in backup.conf begin with a '#' pound sign.

## 2.2 General configuration

The general configuration is done using environment variables.
To set them use backup-settings.cmd.
See the example file for parameters and descriptions.
The script should set PATH and NLS_LANG as well.

# 3. Logging

The script automatically creates logs in a subdirectory named "logs".
Old logfiles are automatically deleted after 30 days.

See backup_all.out for an example of a script run.

# 4. Export settings

The Oracle exports needs a parameter file and a directory where the export dump file
is to be written into. For that directory Oracle uses a DIRECTORY object
which has been named FAME_BACKUP_DIR here.

The export parameter file is created by the script prepare_backup_par.pl every time
an export is to be run. It also contains a DUMPFILE parameter setting the filename.
The filename includes the Oracle instance's name, the environment variable COMPUTERNAME, 
and date and time of the export.

Use SQL script fame_backup_dir.sql to create that DIRECTORY object.
Edit it beforehand to set the correct path for your machine.
Alternately, edit the script prepare_backup_par.pl to use another DIRECTORY object
(or none at all).


# 5. Testing your configuration

To test without running an actual Oracle export use

    backup_all.cmd --test

This will simulate the export by creating a text file of 100MByte size,
but run everything else: 
- using backup-settings.cmd
- reading the backup.conf file
- determining the Oracle instances to export
- running 7Zip or zip
- uploading to the SFTP or FTP site
- creating logfiles and deleting old ones

# 6. Running the export

## 6.1 Running the export for all databases scheduled for today
Just run
`backup_all.cmd`

## 6.2. Running the export based on a schedule
Use the Windows scheduler to run backup_all.cmd every day at the desired time.
Set the working directory to the installation directory.

## 6.3. Running the export for all databases configured, even those not scheduled for today
Run
    backup_all.cmd --manual

## 6.4 Running the export for a specific database now
Run
    backup_all.cmd --instance [Name]
This will ignore the schedule set for that database.


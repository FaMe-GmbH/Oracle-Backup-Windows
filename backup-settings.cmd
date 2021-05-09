@echo off
REM Settings for export-based Oracle backup on Windows

REM set PATH here to include tee and perl if necessary
REM perl is always available on %ORACLE_HOME%\perl 
PATH C:\Program Files\7-Zip;C:\oracle\product\12.2.0\dbhome_1\perl\bin;C:\oracle\product\12.2.0\dbhome_1\bin;C:\usr\local\wbin;c:\windows;c:\windows\system32;

REM for tee and date install UnixUtils

REM path to date.exe from UnixUtils:
REM set UNIXDATE=\usr\local\wbin\date.exe

REM prefer 7zip to zip export dump files:
set ZIP=7Z

REM the Oracle ADMIN directory:
set ADMIN_DIR=C:\oracle\admin

REM the folder containing the backup scripts
set SCRIPT_DIR=C:\oracle\admin\backup-scripts

REM the minimum size of a dump file - smaller sizes trigger errors, cause the backup to fail.
set MIN_DUMP_SIZE=100M

REM Installation path of WinSCP - directory only:
set WINSCP="C:\Program Files (x86)\WinSCP"

REM FTP login for backup server:
set FTP_LOGIN=sftp://dbbackup:fame0111@fameasp11/

REM FTP directory on backup server:
set REMOTE_FTP_DIR=/backup/database/famevm04

REM TESTMODE=1 disables the Oracle export but performs all other steps
set TESTMODE=0

REM TESTDAY: sets the day of week to assume for today
REM evaluated in script read_backup_config.pl
set TESTDAY=

REM MANUAL=1 enforces backup now for all instances even if not configured
REM evaluated in script read_backup_config.pl
set MANUAL=

REM INSTANCE=<name> enforces backup now for the specified instance
REM evaluated in script read_backup_config.pl
set INSTANCE=

set SUMMARY=%SCRIPT_DIR%\summary.log
set NLS_LANG=AMERICAN_AMERICA.AL32UTF8

REM default SYSTEM password for exports:
set SYSTEM_PASSWORD=fame12c


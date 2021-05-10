@echo off

REM general database backup script
REM backs up all Oracle databases listed in file backup.conf which are up and running
REM use parameter --manual to run the backup on other days
REM parameter --test: do not run export but create a test file to test this script

call backup-settings.cmd

del %SUMMARY% 2> NUL

cd %SCRIPT_DIR%
REM set logfile for backup
for /f %%d in ('perl prepare_backup_par.pl --logdate') do set LOGDATE=%%d
set BACKUP_LOG=logs\backup.%LOGDATE%.log

REM check for --test, --instance, and --manual option:
REM --instance and --manual are evaluated in script read_backup_config.pl
@echo off
:read_args
if not "%1"=="" (
	if "%1" =="--test" set TESTMODE=1
	if "%1" =="--manual" set MANUAL=1
	if "%1" =="--instance" (
		set INSTANCE=%2
		shift
	)
	shift
)
if not "%1"=="" goto read_args

REM read file backup.conf: returns all instances to back up 
for /f %%d in ('perl read_backup_config.pl') do call backup_db0.cmd %%d  2>&1 | tee -a %BACKUP_LOG%

REM delete all old backup logs
forfiles /P logs /M *.* /D -30 /c "cmd /c echo removing ^"@file^" >> %BACKUP_LOG% && del @file >> %BACKUP_LOG% 2>&1"

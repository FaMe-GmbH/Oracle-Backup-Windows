@echo on
REM database backup script
REM parameters:   backup_db.cmd <Instance> [--test]
REM <Instance> is required

REM Exit codes:
REM 1 = Instance name not provided or directory variables not set or directories do not exist
REM 2 = OracleService%ORACLE_SID% is not running
REM 3 = script prepare_backup_par.pl failed to execute or raised an error
REM 4 = FTP test failed
REM 6 = Export dump file not found or smaller than %MIN_DUMP_SIZE%
REM 7 = Zip error
REM 8 = FTP error
REM 9 = expdp error code 1 / failed


setlocal EnableDelayedExpansion

set param_error=
if "%1"=="" (
	echo script backup_db.cmd requires the DB instance name as parameter 1 - not set
	set param_error=1
)
if not defined ADMIN_DIR (
	echo "Directory variable ADMIN_DIR is not set."
	set param_error=1
) else (
	if not exist "%ADMIN_DIR%" (
		echo Directory variable ADMIN_DIR="%ADMIN_DIR%^" is not a valid directory.
		set param_error=1
	)
)
if not defined SCRIPT_DIR (
	echo "Directory variable SCRIPT_DIR is not set."
	set param_error=1
) else (
	if not exist "%SCRIPT_DIR%" (
		echo Directory variable SCRIPT_DIR="%SCRIPT_DIR%^" is not a valid directory.
		set param_error=1
	)
)

if not exist "%ADMIN_DIR%\%1" (
	echo Directory %ADMIN_DIR%\%1 does not exist"
	set param_error=1
) else if not exist "%ADMIN_DIR%\%1\backup" (
	mkdir %ADMIN_DIR%\%1\backup
	if errorlevel 1 (
		echo Directory %ADMIN_DIR%\%1\backup does not exist and/or cannot be created.
		set param_error=1
	) else (
		echo created directory %ADMIN_DIR%\%1\backup
	)
)
if "%param_error%"=="1" (
	echo parameter or directory check failed. Stop.
	exit /B 1
)

REM get SYSTEM password if defined in backup.conf:
for /f "tokens=1" %%d in ('call find_system_pwd.cmd') do set SYSTEM_PWD4INSTANCE=%%d

REM get default SYSTEM password if not set in backup.conf:
if not defined SYSTEM_PWD4INSTANCE set SYSTEM_PWD4INSTANCE=%SYSTEM_PASSWORD%
if not defined SYSTEM_PWD4INSTANCE echo "The SYSTEM password is not set and has to be entered at sqlplus and expdp logins."

if "%TESTMODE%"=="1" echo SYSTEM_PWD4INSTANCE="%SYSTEM_PWD4INSTANCE%"

pushd %ADMIN_DIR%\%1\backup
if errorlevel 1 (
	echo cannot cd into directory "%ADMIN_DIR%\%1\backup"
	popd
	exit /B 1
)

set ORACLE_SID=%1
set DUMPFILE=

echo ORACLE_SID=%ORACLE_SID%
echo NLS_LANG=%NLS_LANG%

REM check Oracle service. Perl script dies with error if it is not running
sc query OracleService%ORACLE_SID% | perl %SCRIPT_DIR%\check_oracle_service.pl
if errorlevel 1 (
	echo OracleService%ORACLE_SID% is not running
	popd
	exit /B 2
)
echo ---EXPORT DIRECTORY-----------

del dir.txt 2> NUL
del winscp.ftpcommand1.%ORACLE_SID% 2> NUL
del winscp.ftpcommand2.%ORACLE_SID% 2> NUL
REM get backup directory FAME_BACKUP_DIR from database  => dir.txt
sqlplus -L -S system/%SYSTEM_PWD4INSTANCE% @%SCRIPT_DIR%\get_backup_dir.sql
if errorlevel 1 (
	echo Unable to retrieve the FAME_BACKUP_DIR from the database using SQL*Plus.
	popd
	exit /B 5
)
echo ---dir.txt----------------
type dir.txt
echo --------------------------

REM set up parameter file with dumpfile name and 2 ftp command batchfiles :
REM Perl script prints path filename of dump file; directory is taken from dir.txt
REM The script will die with an error message if the FAME_BACKUP_DIR is not set or not a valid directory.
for /f %%i in ('perl %SCRIPT_DIR%\prepare_backup_par.pl') do set DUMPFILE=%%i
REM if the script prepare_backup_par.pl dies inside the for loop the errorlevel may not be set...
if errorlevel 1 (
	echo Preparation of export parameter file of FTP command file by script prepare_backup_par.pl failed. Stop.
	popd
	exit /B 3
)
REM ... but DUMPFILE will be empty.
if not defined DUMPFILE (
	echo The DUMPFILE name has not been set by script prepare_backup_par.pl. Stop.
	popd
	exit /B 3
)

REM Test FTP connectivity and directory existence:
%winscp%\winscp.com /script=winscp.ftpcommand1.%ORACLE_SID% 2>&1 | tee winscp.ftpcommand1.%ORACLE_SID%.log
if errorlevel 1 (
	echo FTP login error or remote directory does not exist. Stop.
	popd
	exit /B 4
)
echo FTP connectivity test successful.

REM run the export, write to logfile only
echo ---EXPORT----------------------
echo export command=^"expdp system/%SYSTEM_PWD4INSTANCE% parfile=backup.par 2>NUL^"
@echo on
if "%TESTMODE%"=="1" (
	echo "Test: creating testfile %DUMPFILE% of 100MB+100kB size"
	REM Note: CMD preprocesses strings with ! marks, so we have to use ^! here
	perl -e "my $s = ('o' x 1024); for (my $i = 0 ; $i < 102400 ; $i++) { unless (print qq($s\n)) { die qq(cannot create testfile $^!); } }" > "%DUMPFILE%"
	if errorlevel 1 (
		echo "failed to create testfile %DUMPFILE% of 100MB+100kB size"
		popd
		exit /B 9
	) else (
		echo "Test: created testfile %DUMPFILE% of 100MB+100kB size"
	)
	
) else (
	echo "Starting expdp for instance %ORACLE_SID% ..."
	expdp system/%SYSTEM_PWD4INSTANCE% parfile=backup.par 2>&1
	if errorlevel  5 (
		echo "Oracle export terminated with warnings."
	) else (
		if errorlevel 1 (
			echo "expdp terminated with error code 1 (fatal error). Stop."
			call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
			popd
			exit /B 9
		)
	)
	tail -n 5 %DUMPFILE%.log | perl -e "{local $/; my $s=<>; if ($s=~/Job .SYSTEM.* successfully completed/s) {exit 0;} else {exit 1;}}"
	if errorlevel 1 (
		echo "String ^"Job .SYSTEM.... successfully completed^" not found in %DUMPFILE%.log"
		call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
		popd
		exit /B 9
	)
	echo "End of Oracle export."
)
@echo off

REM check dumpfile: must be newer than the winscp command files and have a reasonable size.
REM for /f %%i in ('%UNIXFIND% -size +%MIN_DUMP_SIZE% -ctime -1 -name %DUMPFILE%') do set CHECKDMP=%%i - wont run on Win64
echo "checking export file %DUMPFILE% for timestamp < 12 hours and size >= %MIN_DUMP_SIZE%"
perl %SCRIPT_DIR%\check_export_file.pl --filename "%DUMPFILE%" --min-size="%MIN_DUMP_SIZE%"
if errorlevel 1 (
	echo the dump file is very small, outdated, or does not exist. Export ist considered as failed. Stop.
	echo deleting export file....
	call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
	popd
	exit /B 6
) else (
	echo export file check OK
)

REM zip and copy:
echo ---ZIP-------------------------

@echo off
set zip_error=0
if "%ZIP%"=="7Z" (
	echo using 7Zip to compress the export dump file...
	7z a %DUMPFILE%.zip %DUMPFILE%
	if errorlevel 1 (
		echo 7Zip failed to zip the export dump file.
		set zip_error=1
	)
	echo using 7Zip to add logfiles to the zip archive....
	7z a %DUMPFILE%.zip %DUMPFILE%.log ftp1.%ORACLE_SID%.log dir.txt backup.par ^
		winscp.ftpcommand1.%ORACLE_SID%.log ^
		winscp.ftpcommand1.%ORACLE_SID% ^
		winscp.ftpcommand2.%ORACLE_SID%
	if errorlevel 2 (
		echo 7Zip could not to add all logfiles to the zip archive.
		set zip_error=1
	) else (
		if errorlevel 1 (
			echo 7Zip ended with warnings adding logfiles to the zip archive, but the export dump file is included into the zip file.
		)
	)
) else (
	zip %DUMPFILE%.zip %DUMPFILE% %DUMPFILE%.log ftp1.%ORACLE_SID%.log dir.txt backup.par ^
		winscp.ftpcommand1.%ORACLE_SID%.log ^
		winscp.ftpcommand1.%ORACLE_SID% ^
		winscp.ftpcommand2.%ORACLE_SID%
	if errorlevel 1 (
		echo Zip failed. Zip program used is
		where zip.exe | head -n 1
		set zip_error=1
	)
)
if %zip_error% EQU 1 (
	call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
	popd
	exit /B 7
)
echo --FTP---------------------

REM FTP upload of backup:
echo Upload zip file onto FTP server:
%winscp%\winscp.com /script=winscp.ftpcommand2.%ORACLE_SID%  2>&1 | tee winscp.ftpcommand2.%ORACLE_SID%.log
if errorlevel 1 (
	echo FTP login or file transfer error.
	call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
	popd
	exit /B 8
)
perl %SCRIPT_DIR%\check_ftp_transfer_log.pl winscp.ftpcommand2.%ORACLE_SID%.log
if errorlevel 1 (
	echo FTP login or file transfer error.
	call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"
	popd
	exit /B 8
)

echo FTP transfer successful.
echo Backup completed.
echo ORACLE_SID=%ORACLE_SID%  DUMPFILE=%DUMPFILE%

echo --CLEANUP---------------------
call %SCRIPT_DIR%\remove_dumpfile.cmd "%DUMPFILE%"


popd
exit /B 0


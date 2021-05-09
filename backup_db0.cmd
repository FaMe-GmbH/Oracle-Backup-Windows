@echo off

echo.
echo.
echo --------------------------------------
echo next Instance to back up: %1
perl -e "print scalar(localtime()), qq(\n);"
for /f %%t in ('perl -e "print time();"') do set UNIXTIME=%%t

call backup_db.cmd %1
set err=%ERRORLEVEL%
if "%err%" GTR 9 (
	echo "exitcode=%err%  - undefined exit code"
) else (
	REM for exitcodes 1-8 messages have already been printed.
	echo "exitcode=%err%"
)

perl -e "my $t0=%UNIXTIME%; my @totaltime=gmtime(time()-$t0); print sprintf(qq{Total time: %%dh %%dmin %%ds\n}, reverse @totaltime[0..2]);"

echo --------------------------------------
echo.

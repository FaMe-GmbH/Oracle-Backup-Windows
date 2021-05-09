whenever sqlerror exit 1
whenever oserror exit 2
spool dir.txt
set pagesize 0
set feedback off
set linesize 500
set trimspool on
column DIRECTORY_PATH format A300
select trim(DIRECTORY_PATH) from dba_directories where DIRECTORY_NAME = 'FAME_BACKUP_DIR';
spool off
exit


spool fame_backup_dir.lst

prompt directory FAME_BACKUP_DIR

drop directory FAME_BACKUP_DIR;
create directory FAME_BACKUP_DIR as 'E:\ora_backup\P1000\dpdump';

spool off
exit;

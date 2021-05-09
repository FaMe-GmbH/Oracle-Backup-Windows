@echo off
findstr /R "^%ORACLE_SID%\s*:"  backup.conf | perl -ne "chomp; @f=split(/:/, $_); if (@f >= 3 && $f[0] eq qq(%ORACLE_SID%) && $f[2] =~ m!system/(.+)!i) { print $1; }"

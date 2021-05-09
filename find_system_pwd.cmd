@echo off
findstr /R "^%ORACLE_SID%"  backup.conf | perl -ne "chomp; @f=split(/:/, $_); if (@f >= 3 && $f[2] =~ m!system/(.+)!i) { print $1; }"

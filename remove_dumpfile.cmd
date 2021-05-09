@echo off
if not "%1"=="" (
	@echo on
	del %1
	del %1.zip
	@echo off
)

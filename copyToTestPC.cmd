@echo off
set f=\\skorik10\c$\Users\skorik\Repository\CrystalDiskInfo

set h=utc104-30
call :copy

set h=disp104-4
call :copy

set h=utc104-4
call :copy

set h=utc104-5
call :copy




goto :EOF

:COPY

copy /Y "%f%\Shutdown.ps1"    "\\%h%\c$\Program Files\CrystalDiskInfo" 
copy /Y "%f%\Shutdown.psm1"    "\\%h%\c$\Program Files\CrystalDiskInfo" 
copy /Y "%f%\ShutdownWarningDeskTop.ps1"    "\\%h%\c$\Program Files\CrystalDiskInfo" 
copy /Y "%f%\execCrystalDiskInfor.ps1"    "\\%h%\c$\Program Files\CrystalDiskInfo" 
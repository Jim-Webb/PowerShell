:: Start of WMI reset that you should be using

@echo off
sc config winmgmt start= disabled
net stop winmgmt /y
%systemdrive%
cd %windir%\system32\wbem
for /f %%s in (‘dir /b *.dll’) do regsvr32 /s %%s
wmiprvse /regserver 
winmgmt /regserver
sc config winmgmt start= Auto
net start winmgmt
dir /b *.mof *.mfl | findstr /v /i uninstall > moflist.txt & for /F %%s in (moflist.txt) do mofcomp %%s

:: End of WMI reset that you should be using
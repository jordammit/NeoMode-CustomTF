@echo off

rem ---------------------------------------------------
rem This batch mantains server running in case of crash
rem and handles server restart exit codes, relaunching.
rem ------------------------------ OfteN[cp] 14/12/2004

echo Launching Prozac QWSV... (permanent batch loop)

:begin

rem Wake up, Neo...
pqwsv -mem 96 +gamedir fortress

if errorlevel == 2 goto reset
if errorlevel == 1 goto crash

goto end

:reset
echo Restarting server... (Shell batch)
goto begin

:crash
echo Server crashed! Restarting... (Shell batch)
goto begin

:end

@echo off
if "%~1"=="--help" goto :help

echo Example dev tools command
echo Parameter: %1
goto :eof

:help
echo Usage: %~n0 [parameter]
echo.
echo Example command for dev tools operations.
exit /b 0

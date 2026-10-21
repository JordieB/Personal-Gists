@echo off
rem Basic smoke test for dev-tools.cmd

echo Testing dev-tools.cmd...

rem Test help option
call "%~dp0..\..\..\modules\command_prompt\dev-tools\dev-tools.cmd" --help
if errorlevel 1 (
    echo FAIL: Help command failed
    exit /b 1
)

rem Test basic execution
call "%~dp0..\..\..\modules\command_prompt\dev-tools\dev-tools.cmd" test_param
if errorlevel 1 (
    echo FAIL: Basic execution failed
    exit /b 1
)

echo PASS: All tests passed

@echo off
rem ===========================================================================
rem  Ex 03: valid/ready handshake register -- Vivado 2019.1 synthesis (batch)
rem
rem  Usage:
rem      synth.bat      synthesize once, print LUT / FF, write util.rpt
rem
rem  Notes:
rem      - This file is pure ASCII + CRLF on purpose. cmd.exe under
rem        "chcp 65001" mis-parses batch files containing non-ASCII text
rem        (it splits a line at the wrong byte offset). That is exactly
rem        the "'...' is not recognized" error seen before.
rem      - Synthesis only, no place & route -> no fmax number.
rem      - Testbench is not synthesized, so only hs_reg.v is read.
rem  If Vivado lives somewhere else, edit the VIVADO_HOME line only.
rem ===========================================================================
setlocal

set "VIVADO_HOME=E:\Xilinx\Vivado\2019.1"

cd /d "%~dp0"

if not exist "%VIVADO_HOME%\settings64.bat" (
    echo.
    echo [ERROR] Vivado environment script not found:
    echo         %VIVADO_HOME%\settings64.bat
    echo         Edit this file and fix VIVADO_HOME.
    echo.
    pause
    exit /b 1
)

if not exist "hs_reg.v" (
    echo.
    echo [ERROR] hs_reg.v not found in the current directory.
    echo         Current directory: %CD%
    echo         Run this from C:\ic-work\verilog-start\03_handshake
    echo.
    pause
    exit /b 1
)

if not exist "synth.tcl" (
    echo.
    echo [ERROR] synth.tcl not found - the Tcl script was not copied over.
    echo.
    pause
    exit /b 1
)

rem vivado is not on PATH: load the Vivado environment first
call "%VIVADO_HOME%\settings64.bat" >nul 2>&1

echo.
echo ============================================================
echo   Ex 03: handshake register   (Vivado synthesis, resource numbers)
echo ============================================================
echo.
echo  Part: xc7a35tcsg324-1 (Artix-7 35T)
echo  Synthesizing, about 30-60 s. Do not close this window ...
echo.

call vivado -mode batch -source synth.tcl
if errorlevel 1 goto fail

echo.
echo ============================================================
echo   Synthesis OK. Report: %~dp0util.rpt
echo   Three numbers matter:
echo     Slice Registers  -- expect 9   (1  +  8)
echo     Slice LUTs       -- expect 1..2  (only the s_ready OR gate)
echo     Block RAM / DSPs -- expect 0
echo   Then put them into the progress log.
echo ============================================================
echo.
goto :eof

:fail
echo.
echo [FAILED] synthesis errored. Check in this order:
echo        1. Are you in C:\ic-work\verilog-start\03_handshake ?
echo           (never run Vivado under the Desktop path: Chinese chars
echo            and a single quote in the user name crash Vivado 2019.1)
echo        2. Any syntax error in hs_reg.v? (run_xsim.bat PASS = syntax is fine)
echo        3. Send me the first ERROR / CRITICAL WARNING in vivado.log
echo.
pause
exit /b 1

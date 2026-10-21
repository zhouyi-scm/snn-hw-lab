@echo off
rem ===========================================================================
rem  Ex 02: leaky membrane potential accumulator -- Vivado 2019.1 (batch)
rem
rem  Usage:
rem      synth.bat      synthesize once, print LUT / FF / BRAM, write util.rpt
rem
rem  Notes:
rem      - Synthesis only, no place & route -> no fmax number.
rem      - Testbench is not synthesized, so only lif_leak.v is read.
rem      - Keep this file pure ASCII + CRLF (cmd + chcp 65001 mis-parses
rem        non-ASCII batch files). Also: no half-width ( ) inside
rem        "if ... ( ... )" blocks -- cmd treats ) as the end of the block.
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

if not exist "lif_leak.v" (
    echo.
    echo [ERROR] lif_leak.v not found in the current directory.
    echo         Current directory: %CD%
    echo         Run this from C:\ic-work\verilog-start\02_lif_leak
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
echo   Ex 02: leaky membrane accumulator   (Vivado synthesis)
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
echo   Two numbers matter here:
echo     Slice LUTs        -- cost of the leak + accumulate arithmetic
echo     Slice Registers   -- should be exactly 16, the only register group
echo   Then put them into the progress log.
echo ============================================================
echo.
goto :eof

:fail
echo.
echo [FAILED] synthesis errored. Check in this order:
echo        1. Are you in C:\ic-work\verilog-start\02_lif_leak ?
echo           Never run Vivado under the Desktop path: Chinese chars and a
echo           single quote in the user name crash Vivado 2019.1.
echo        2. Any syntax error in lif_leak.v? Run run_xsim.bat first.
echo        3. Send me the first ERROR / CRITICAL WARNING in vivado.log
echo.
pause
exit /b 1

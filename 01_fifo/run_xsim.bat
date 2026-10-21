@echo off
rem ===========================================================================
rem  Exercise 01: synchronous FIFO -- XSim (Vivado 2019.1)
rem
rem  Usage:
rem      run_xsim.bat        simulate only, prints PASS / FAIL (use this daily)
rem      run_xsim.bat gui    simulate and open the Vivado waveform window
rem
rem  No Vivado project, no mouse clicks. If Vivado lives elsewhere, edit the
rem  VIVADO_HOME line below.
rem
rem  NOTE: keep this file pure ASCII. cmd.exe under "chcp 65001" mis-parses
rem        batch files containing non-ASCII text (it splits a line at a wrong
rem        byte offset and runs half a sentence as a command).
rem ===========================================================================
setlocal

set "VIVADO_HOME=E:\Xilinx\Vivado\2019.1"

if not exist "%VIVADO_HOME%\settings64.bat" (
    echo.
    echo [ERROR] Vivado environment script not found:
    echo         %VIVADO_HOME%\settings64.bat
    echo         Edit this file and fix VIVADO_HOME.
    echo.
    pause
    exit /b 1
)

rem xvlog / xelab / xsim are not on PATH: load the Vivado environment first
call "%VIVADO_HOME%\settings64.bat" >nul 2>&1

cd /d "%~dp0"

echo.
echo ============================================================
echo   Ex 01: synchronous FIFO   (XSim)
echo ============================================================
echo.

echo [1/3] xvlog compile ...
call xvlog fifo.v tb_fifo.v
if errorlevel 1 goto fail
echo.

echo [2/3] xelab elaborate ...
call xelab -debug typical tb_fifo -s sim_fifo
if errorlevel 1 goto fail
echo.

if /I "%1"=="gui" goto gui

echo [3/3] xsim run ...
call xsim sim_fifo -runall
if errorlevel 1 goto fail
echo.
echo ============================================================
echo   "PASS" above means it works.
echo   Waveforms: run_xsim.bat gui
echo ============================================================
echo.
goto :eof

:gui
echo [3/3] opening Vivado waveform window ...
echo.
echo   The waveform does not appear by itself. In the Tcl console type:
echo       run -all
echo   (or click "Run All" in the toolbar).
echo.
call xsim sim_fifo -gui
goto :eof

:fail
echo.
echo [FAILED] the previous step reported an error. The three usual causes:
echo          1. the file was not saved
echo          2. a port or module name is misspelled
echo          3. a semicolon is missing on the previous line
echo.
pause
exit /b 1

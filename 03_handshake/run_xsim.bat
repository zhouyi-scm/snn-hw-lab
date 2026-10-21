@echo off
rem ===========================================================================
rem  Exercise 03: valid/ready handshake register -- XSim (Vivado 2019.1)
rem
rem  Usage:
rem      run_xsim.bat        simulate only, prints PASS / FAIL
rem      run_xsim.bat gui    simulate and open the Vivado waveform window
rem
rem  NOTE: keep this file pure ASCII. cmd.exe under "chcp 65001" mis-parses
rem        batch files that contain non-ASCII text (it splits a line at a
rem        wrong byte offset and tries to run half a sentence as a command).
rem ===========================================================================
setlocal

set "VIVADO_HOME=E:\Xilinx\Vivado\2019.1"

if not exist "%VIVADO_HOME%\settings64.bat" (
    echo.
    echo [ERROR] cannot find %VIVADO_HOME%\settings64.bat
    echo         Open this file in an editor and fix VIVADO_HOME.
    echo.
    pause
    exit /b 1
)

call "%VIVADO_HOME%\settings64.bat" >nul 2>&1

cd /d "%~dp0"

echo.
echo ============================================================
echo   Ex 03: valid/ready handshake register   (XSim)
echo ============================================================
echo.

echo [1/3] xvlog compile ...
call xvlog hs_reg.v tb_hs_reg.v
if errorlevel 1 goto fail
echo.

echo [2/3] xelab elaborate ...
call xelab -debug typical tb_hs_reg -s sim_hs
if errorlevel 1 goto fail
echo.

if /I "%1"=="gui" goto gui

echo [3/3] xsim run ...
call xsim sim_hs -runall
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
echo   After the window opens, type:   run -all
echo   Watch: s_valid / s_ready / m_valid / m_ready handshakes,
echo          and the back-pressure hold when m_ready = 0.
echo.
call xsim sim_hs -gui
goto :eof

:fail
echo.
echo [FAILED] the previous step reported an error.
echo.
pause
exit /b 1

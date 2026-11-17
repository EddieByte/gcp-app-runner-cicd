@echo off
rem ===========================================================================
rem get-service-ip.cmd - Windows wrapper for get-service-ip.sh
rem
rem Lets the same Bash script run from Command Prompt (cmd) and PowerShell.
rem It finds Git Bash and runs scripts\get-service-ip.sh with every argument
rem passed through, then returns the script's exit code unchanged.
rem There is ONE implementation (the .sh file); this file only launches it.
rem
rem Usage (cmd or PowerShell, from the repo root):
rem   scripts\get-service-ip.cmd dev
rem   scripts\get-service-ip.cmd prod --no-check
rem   scripts\get-service-ip.cmd --help
rem
rem Exit codes: same as get-service-ip.sh, plus 2 if Git Bash isn't found.
rem ===========================================================================
setlocal

set "SCRIPT=%~dp0get-service-ip.sh"
set "BASH_EXE="

rem 1. Usual Git for Windows install locations.
for %%P in ("%ProgramFiles%\Git\bin\bash.exe" "%ProgramFiles(x86)%\Git\bin\bash.exe" "%LocalAppData%\Programs\Git\bin\bash.exe") do (
  if not defined BASH_EXE if exist %%P set "BASH_EXE=%%~P"
)

rem 2. Otherwise, work it out from wherever git.exe is on the PATH.
if not defined BASH_EXE (
  for /f "delims=" %%G in ('where git 2^>nul') do (
    if not defined BASH_EXE if exist "%%~dpG..\bin\bash.exe" set "BASH_EXE=%%~dpG..\bin\bash.exe"
  )
)

rem Deliberately NOT using C:\Windows\System32\bash.exe: that is WSL, which has
rem its own separate gcloud installation and login.
if not defined BASH_EXE (
  echo [ERROR] Git Bash not found. Install Git for Windows ^(https://git-scm.com^), or run scripts/get-service-ip.sh from WSL or Linux. 1>&2
  exit /b 2
)

"%BASH_EXE%" "%SCRIPT%" %*
exit /b %ERRORLEVEL%

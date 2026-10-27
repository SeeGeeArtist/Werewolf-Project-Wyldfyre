@echo off
rem Copies the repository's WTAGarou mod into the Project Zomboid mods folder.
rem Multiplayer hosting/joining breaks when mods\WTAGarou is a junction or
rem symlink (see docs\HOSTING_JUNCTION_CHECKSUM.md), so the mods folder must
rem hold a real copy. Run this after every pull or rebuild. Safe to re-run.
setlocal
for %%I in ("%~dp0..") do set "SRC=%%~fI"
set "DST=%UserProfile%\Zomboid\mods\WTAGarou"

rem A junction/symlink at the destination has the reparse-point attribute (L).
rem rmdir on a junction removes only the link, never the repository files.
for %%A in ("%DST%") do set "ATTR=%%~aA"
if defined ATTR if not "%ATTR:l=%"=="%ATTR%" (
    echo Removing junction %DST%
    rmdir "%DST%"
)

echo Mirroring %SRC% -> %DST%
robocopy "%SRC%" "%DST%" /MIR /XD docs tests tools .git /XF *.md /NFL /NDL /NJH /NJS /NP
if %ERRORLEVEL% GEQ 8 (
    echo robocopy failed with code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
echo Done. mods\WTAGarou is a real folder; host or join as usual.
exit /b 0

@echo off
setlocal
REM WTAGarou - stage the Steam Workshop item folder (0.4.97).
REM
REM Builds %USERPROFILE%\Zomboid\Workshop\WTAGarou\ exactly the way the
REM in-game Workshop uploader wants it:
REM   workshop.txt, preview.png, Contents\mods\WTAGarou\{42,common}
REM from this repository, with nothing but runtime files (no docs, tests,
REM tools, source art, repo metadata). Run it from anywhere; it works out
REM the repo path from its own location. Re-run after every version bump,
REM then Main menu > Workshop > Create/Update Item > WTAGarou.
REM
REM The engine refuses *.exe *.dll *.bat *.app *.dylib *.sh *.so *.zip
REM anywhere under Contents, and a preview that is not a 256 or 512 square
REM PNG under 1,024,000 bytes. python3 tools\check_workshop_staging.py
REM runs the same rules plus the asset-permission inventory.

set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"
set "DEST=%USERPROFILE%\Zomboid\Workshop\WTAGarou"
set "MOD=%DEST%\Contents\mods\WTAGarou"

echo Staging %REPO% -^> %DEST%
if exist "%DEST%\Contents" rmdir /s /q "%DEST%\Contents"
mkdir "%MOD%" 2>nul

REM /MIR mirrors; /XF excludes files that must not ship.
robocopy "%REPO%\42" "%MOD%\42" /MIR /NFL /NDL /NJH /NJS /XF "poster - full.png" "world-on-fire-glyph.png" "*.base.glb" "*.md" "*.bat" "*.sh" "*.py" "*.zip" "*.psd" "*.blend" "*.blend1" "Thumbs.db" ".DS_Store" /XD ".git"
if errorlevel 8 goto :fail
robocopy "%REPO%\common" "%MOD%\common" /MIR /NFL /NDL /NJH /NJS /XF "*.base.glb" "*.md" "*.bat" "*.sh" "*.py" "*.zip" "*.psd" "*.blend" "*.blend1" "Thumbs.db" ".DS_Store" /XD ".git"
if errorlevel 8 goto :fail

copy /y "%REPO%\workshop\preview.png" "%DEST%\preview.png" >nul
REM workshop.txt: once the item exists the staged copy holds its Workshop id
REM (the uploader writes it), so keep that one. Until then (no id yet, line
REM is exactly "id=") refresh it from the repo so title/description/tags
REM edits reach the uploader.
if not exist "%DEST%\workshop.txt" (
    copy /y "%REPO%\workshop\workshop.txt" "%DEST%\workshop.txt" >nul
) else (
    findstr /b /x /c:"id=" "%DEST%\workshop.txt" >nul && copy /y "%REPO%\workshop\workshop.txt" "%DEST%\workshop.txt" >nul
)
echo workshop.txt id line:
findstr /b "id=" "%DEST%\workshop.txt"

echo.
echo Forbidden file types under Contents (must print nothing):
dir /s /b "%DEST%\Contents\*.exe" "%DEST%\Contents\*.dll" "%DEST%\Contents\*.bat" "%DEST%\Contents\*.app" "%DEST%\Contents\*.dylib" "%DEST%\Contents\*.sh" "%DEST%\Contents\*.so" "%DEST%\Contents\*.zip" 2>nul
echo.
echo mod.info:
findstr /b "id= modversion= versionMin= require= javaJarFile=" "%MOD%\42\mod.info"
echo.
echo Java supplement SHA-256 (compare with the commit's java\build output):
certutil -hashfile "%MOD%\42\media\java\client\WTAGarouVisuals.jar" SHA256 | findstr /v "hash"
echo.
echo Staged. Open Project Zomboid: Main menu ^> Workshop ^> Create New Item (or Update) ^> WTAGarou.
exit /b 0

:fail
echo robocopy failed.
exit /b 1

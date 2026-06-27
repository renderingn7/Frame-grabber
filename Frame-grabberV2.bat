@echo off
setlocal enabledelayedexpansion
title Video Screenshots

rem percent sign as a variable for safe comparisons
set "PCT=%%"
rem temp file for reading duration
set "TMPF=%TEMP%\vss_dur_%RANDOM%.txt"

echo =======================================================
echo   Video screenshots extractor
echo =======================================================
echo.

rem -------- Find ffmpeg --------
set "FFMPEG="
where ffmpeg >nul 2>&1 && set "FFMPEG=ffmpeg"
if not defined FFMPEG if exist "%~dp0ffmpeg.exe" set "FFMPEG=%~dp0ffmpeg.exe"

if not defined FFMPEG (
    echo ffmpeg not found. Trying to install via winget...
    echo.
    winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    echo.
    where ffmpeg >nul 2>&1 && set "FFMPEG=ffmpeg"
)

if not defined FFMPEG (
    echo.
    echo ====================================================
    echo  ffmpeg was not found and could not be installed.
    echo   1^) Download from https://ffmpeg.org/download.html
    echo      and put ffmpeg.exe NEXT TO this .bat file.
    echo   2^) Or install manually:  winget install ffmpeg
    echo ====================================================
    echo.
    pause
    goto :eof
)

rem -------- Find ffprobe (optional, for percent times) --------
set "FFPROBE="
where ffprobe >nul 2>&1 && set "FFPROBE=ffprobe"
if not defined FFPROBE if exist "%~dp0ffprobe.exe" set "FFPROBE=%~dp0ffprobe.exe"

rem -------- Folder --------
set "FOLDER=%~2"
if not defined FOLDER (
    echo Drag the video folder into this window and press Enter
    echo ^(or paste the path^):
    echo.
    set /p "FOLDER=Folder: "
)
set "FOLDER=!FOLDER:"=!"
if "!FOLDER:~-1!"=="\" set "FOLDER=!FOLDER:~0,-1!"

if not exist "!FOLDER!\" (
    echo.
    echo ERROR: folder not found:
    echo   !FOLDER!
    echo.
    pause
    goto :eof
)

rem -------- Times list --------
set "TIMES=%~1"
if not defined TIMES (
    echo.
    echo Enter one or more times separated by spaces.
    echo   seconds:  10   1.5
    echo   percent:  25%PCT%   50%PCT%
    echo   example:  5 25%PCT% 50%PCT% 120
    echo.
    set /p "TIMES=Times: "
)
set "TIMES=!TIMES:,= !"
set "TIMES=!TIMES:;= !"

set "NEED_DUR=0"
echo !TIMES! | findstr /C:"%PCT%" >nul && set "NEED_DUR=1"

echo.
echo Folder: !FOLDER!
echo Times:  !TIMES!
echo ffmpeg: !FFMPEG!
if "!NEED_DUR!"=="1" (
    if defined FFPROBE (echo ffprobe: !FFPROBE!) else (echo ffprobe: not found - will read duration from ffmpeg)
)
echo.
echo Working...
echo.

set /a OK=0
set /a ERR=0
set /a FILES=0

for %%E in (mp4 mkv avi mov wmv flv webm m4v mpeg mpg ts) do (
    for /f "delims=" %%F in ('dir /b /a-d "!FOLDER!\*.%%E" 2^>nul') do (
        set /a FILES+=1
        set "SRC=!FOLDER!\%%F"
        set "BASE=%%~nF"
        echo   == %%F

        set "DUR_INT="
        if "!NEED_DUR!"=="1" call :get_duration "!SRC!"

        for %%T in (!TIMES!) do (
            set "TOK=%%T"
            set "TIMEARG="
            set "LABEL="

            if "!TOK:~-1!"=="!PCT!" (
                set "PVAL=!TOK:~0,-1!"
                for /f "tokens=1,2 delims=." %%a in ("!PVAL!.") do (
                    set "W=%%a"
                    set "FR=%%b"
                )
                for /f "tokens=* delims=0" %%z in ("!W!") do set "W=%%z"
                if "!W!"=="" set "W=0"
                set "FD=!FR:~0,1!"
                if "!FD!"=="" set "FD=0"
                if defined DUR_INT (
                    set /a "PCT_T=W*10+FD"
                    set /a "TIMEARG=DUR_INT*PCT_T/1000"
                    if !TIMEARG! GEQ !DUR_INT! if !DUR_INT! GTR 0 set /a "TIMEARG=DUR_INT-1"
                    set "LABEL=!W!pct"
                    if not "!FR!"=="" set "LABEL=!W!_!FR!pct"
                ) else (
                    echo      skip !TOK!  ^(could not read duration^)
                )
            ) else (
                set "TIMEARG=!TOK!"
                set "LABEL=!TOK:.=_!s"
            )

            if defined TIMEARG (
                set "OUT=!FOLDER!\!BASE!_!LABEL!.jpg"
                "!FFMPEG!" -ss !TIMEARG! -i "!SRC!" -frames:v 1 -q:v 2 -y "!OUT!" >nul 2>&1
                if exist "!OUT!" (
                    echo      OK   !BASE!_!LABEL!.jpg   ^(at !TIMEARG!s^)
                    set /a OK+=1
                ) else (
                    echo      FAIL !TOK!   ^(beyond video length or unreadable^)
                    set /a ERR+=1
                )
            )
        )
    )
)

if exist "!TMPF!" del "!TMPF!" >nul 2>&1

echo.
echo =======================================================
if !FILES!==0 (
    echo   No video files found in the folder.
) else (
    echo   Done!  Files: !FILES!   Saved: !OK!   Failed: !ERR!
)
echo =======================================================
echo.
pause
goto :eof


rem ============ subroutine: get integer-second duration ============
:get_duration
set "DUR_INT="
set "RAWDUR="

if defined FFPROBE (
    "!FFPROBE!" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "%~1" 1>"!TMPF!" 2>nul
    if exist "!TMPF!" set /p RAWDUR=<"!TMPF!"
)

if defined RAWDUR (
    for /f "delims=." %%a in ("!RAWDUR!") do set "DUR_INT=%%a"
    for /f "tokens=* delims=0" %%z in ("!DUR_INT!") do set "DUR_INT=%%z"
    if "!DUR_INT!"=="" set "DUR_INT=0"
    goto :eof
)

rem fallback: parse "Duration: HH:MM:SS.xx" from ffmpeg -i (stderr -> temp file)
"!FFMPEG!" -i "%~1" 2>"!TMPF!" >nul
set "DLINE="
for /f "tokens=2 delims= " %%d in ('findstr /C:"Duration:" "!TMPF!"') do (
    set "DLINE=%%d"
    goto :gotdur
)
:gotdur
if not defined DLINE goto :eof
set "DLINE=!DLINE:,=!"
for /f "tokens=1-3 delims=:" %%h in ("!DLINE!") do (
    set "HH=%%h"
    set "MM=%%i"
    set "SSF=%%j"
)
for /f "delims=." %%s in ("!SSF!") do set "SS=%%s"
for /f "tokens=* delims=0" %%z in ("!HH!") do set "HH=%%z"
for /f "tokens=* delims=0" %%z in ("!MM!") do set "MM=%%z"
for /f "tokens=* delims=0" %%z in ("!SS!") do set "SS=%%z"
if "!HH!"=="" set "HH=0"
if "!MM!"=="" set "MM=0"
if "!SS!"=="" set "SS=0"
set /a "DUR_INT=HH*3600+MM*60+SS"
goto :eof

@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Скриншоты из видео

rem ============================================================
rem   Извлечение скриншотов из всех видео в папке
rem   на заданной секунде. Работает без Python.
rem   Нужен только ffmpeg (один портативный .exe).
rem ============================================================

echo =======================================================
echo   Извлечение скриншотов из видео
echo =======================================================
echo.

rem -------- Поиск ffmpeg --------
set "FFMPEG="
where ffmpeg >nul 2>&1 && set "FFMPEG=ffmpeg"
if not defined FFMPEG if exist "%~dp0ffmpeg.exe" set "FFMPEG=%~dp0ffmpeg.exe"

if not defined FFMPEG (
    echo ffmpeg не найден. Попробую установить через winget...
    echo.
    winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    echo.
    rem Перепроверяем после установки
    where ffmpeg >nul 2>&1 && set "FFMPEG=ffmpeg"
)

if not defined FFMPEG (
    echo.
    echo ====================================================
    echo  Не удалось найти или установить ffmpeg.
    echo.
    echo  Сделайте одно из:
    echo   1^) Скачайте ffmpeg с https://ffmpeg.org/download.html
    echo      и положите файл ffmpeg.exe РЯДОМ с этим скриптом.
    echo   2^) Установите вручную:  winget install ffmpeg
    echo ====================================================
    echo.
    pause
    exit /b 1
)

rem -------- Папка (аргумент 2 или ввод/перетаскивание) --------
set "FOLDER=%~2"
if not defined FOLDER (
    echo Перетащите папку с видео в это окно и нажмите Enter
    echo ^(или вставьте путь^):
    echo.
    set /p "FOLDER=Папка: "
)
rem убираем кавычки, если путь перетащили
set "FOLDER=!FOLDER:"=!"
rem убираем завершающий обратный слэш
if "!FOLDER:~-1!"=="\" set "FOLDER=!FOLDER:~0,-1!"

if not exist "!FOLDER!\" (
    echo.
    echo Ошибка: папка не найдена:
    echo   !FOLDER!
    echo.
    pause
    exit /b 1
)

rem -------- Время в секундах (аргумент 1 или ввод) --------
set "SECS=%~1"
if not defined SECS (
    echo.
    set /p "SECS=Секунда для скриншота (например 10 или 1.5): "
)

echo.
echo Папка:  !FOLDER!
echo Время:  !SECS! сек
echo ffmpeg: !FFMPEG!
echo.
echo Обрабатываю...
echo.

set /a OK=0
set /a ERR=0
set /a TOTAL=0

for %%F in (
    "!FOLDER!\*.mp4" "!FOLDER!\*.mkv" "!FOLDER!\*.avi" "!FOLDER!\*.mov"
    "!FOLDER!\*.wmv" "!FOLDER!\*.flv" "!FOLDER!\*.webm" "!FOLDER!\*.m4v"
    "!FOLDER!\*.mpeg" "!FOLDER!\*.mpg" "!FOLDER!\*.ts"
) do (
    if exist "%%~fF" (
        set /a TOTAL+=1
        set "OUT=!FOLDER!\%%~nF.jpg"
        echo   -^> %%~nxF
        "!FFMPEG!" -ss !SECS! -i "%%~fF" -frames:v 1 -q:v 2 -y "!OUT!" >nul 2>&1
        if exist "!OUT!" (
            echo      OK: %%~nF.jpg
            set /a OK+=1
        ) else (
            echo      Ошибка ^(видео короче !SECS! сек или не читается^)
            set /a ERR+=1
        )
    )
)

echo.
echo =======================================================
if !TOTAL!==0 (
    echo   Видеофайлы в папке не найдены.
) else (
    echo   Готово!  Успешно: !OK!   ^|   Ошибок: !ERR!
)
echo =======================================================
echo.
pause
endlocal

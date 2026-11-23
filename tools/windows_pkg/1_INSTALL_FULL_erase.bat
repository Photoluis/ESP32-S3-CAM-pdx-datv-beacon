@echo off
rem ESP32-S3-CAM_PDX DATV Beacon - IZ7PDX - GPL-3.0
rem Prima installazione / first installation: cancella la scheda e scrive l'immagine completa a 0x0
rem (bootloader, partizioni, firmware, monoscopio standard, sfondo PiP standard).
cd /d "%~dp0"
title DATV Beacon - FULL install
echo.
echo  ESP32-S3-CAM_PDX DATV Beacon - FULL INSTALL (erases the board / cancella la scheda)
echo  Connect the board to its USB-serial port (marked COM or TTL, not OTG).
echo  Collegate la scheda alla porta USB-seriale (marcata COM o TTL, non OTG).
echo.
rem porta: elenco con i nomi di Windows, COM3 o 3, Invio = ricerca dell'ESP32-S3 (find_port.ps1)
set PORT=
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0find_port.ps1" -Out "%TEMP%\datv_beacon_port.txt"
set /p PORT=<"%TEMP%\datv_beacon_port.txt"
if "%PORT%"=="" ( echo. & echo  No port selected / nessuna porta scelta. & pause & exit /b 1 )
for %%F in (*_full.bin) do set IMG=%%F
if "%IMG%"=="" ( echo ERROR: *_full.bin not found & pause & exit /b 1 )
"%~dp0esptool.exe" --chip esp32s3 --port %PORT% -b 460800 write-flash 0x0 "%IMG%"
if errorlevel 1 (
  echo.
  echo  FAILED. Hold BOOT, press and release RST, release BOOT, then run again.
  echo  NON RIUSCITO. Tenere BOOT, premere e rilasciare RST, rilasciare BOOT e riprovare.
) else (
  echo.
  echo  DONE. Press RST, then connect to Wi-Fi NOCALL-BEACON ^(password beacon13cm^) and open http://192.168.4.1
  echo  FATTO. Premere RST, collegarsi al Wi-Fi NOCALL-BEACON ^(password beacon13cm^) e aprire http://192.168.4.1
)
echo.
pause

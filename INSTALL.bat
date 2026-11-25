@echo off
cd /d "%~dp0"

set device=invalid
set device1=DEVICE1
set device2=DEVICE2
set fastboot=META-INF\fastboot.exe

echo.
echo =======================
echo Flasher by git@zuri1503
echo =======================
echo.

if not exist "%fastboot%" (
    echo [ERROR] %fastboot% not found. Please extract all files!
    pause
    exit /B 1
)

echo Waiting your device...
echo.
for /f "tokens=2" %%D in ('%fastboot% getvar product 2^>^&1 ^| findstr /l /b /c:"product:"') do set device=%%D
if "%device%" neq "%device1%" if "%device%" neq "%device2%" (
    echo [ERROR] ROM: %device1% - %device2%
    echo [ERROR] Your device: %device%
    pause
    exit /B 1
)

set data=0
set /p data="Type 1 to FORMAT data or 0 to KEEP data: "
if /i "%data%"=="1" (
    echo.
    echo [FORMAT] userdata ...
    echo.
    %fastboot% erase userdata
    %fastboot% erase metadata
    %fastboot% erase frp
)

echo.
echo [FLASH] firmware ...
echo.
if exist images\preloader_raw.img (
    %fastboot% flash preloader_a images\preloader_raw.img
    %fastboot% flash preloader_b images\preloader_raw.img
    %fastboot% flash preloader1 images\preloader_raw.img
    %fastboot% flash preloader2 images\preloader_raw.img
)
if exist images\cust.img (
    %fastboot% flash cust images\cust.img
)
%fastboot% --set-active=a
%fastboot% flash boot_a images\boot.img
%fastboot% flash boot_b images\boot.img

echo.
echo [FLASH] super.img ...
echo.
%fastboot% flash super images\super.img

echo.
echo [REBOOT] system ...
echo.
%fastboot% reboot

echo.
echo ==========================
echo Completed to install ROM !
echo ==========================
echo.
pause

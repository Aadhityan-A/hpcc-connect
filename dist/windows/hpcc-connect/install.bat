@echo off
echo ============================================
echo    HPCC Connect - Windows Installer
echo ============================================
echo.

set INSTALL_DIR=%LOCALAPPDATA%\HPCCConnect

echo Installing to: %INSTALL_DIR%
echo.

:: Create install directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copy files
echo Copying files...
xcopy /E /Y /Q "%~dp0*" "%INSTALL_DIR%\" > nul

:: Create Start Menu shortcut
echo Creating shortcuts...
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\HPCC Connect.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\hpcc_connect.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Description = 'SSH Terminal Client with File Browser'; $Shortcut.Save()"

:: Create Desktop shortcut
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\HPCC Connect.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\hpcc_connect.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Description = 'SSH Terminal Client with File Browser'; $Shortcut.Save()"

echo.
echo ============================================
echo    Installation Complete!
echo ============================================
echo.
echo HPCC Connect has been installed.
echo You can find it in your Start Menu or Desktop.
echo.
pause

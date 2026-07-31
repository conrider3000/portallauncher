@echo off
title Instalador Portal Launcher
color 0A
set ADB=C:\Users\falac\AppData\Local\Android\sdk\platform-tools\adb.exe
set APK=build\app\outputs\flutter-apk\app-debug.apk
set IP=192.168.15.3

echo ============================================
echo    INSTALADOR PORTAL LAUNCHER
echo ============================================
echo.
echo 1. Mantenha a tela do celular LIGADA
echo 2. Va em: Config > Op. Dev > Depuracao s/ fio
echo 3. Anote a porta (ex: 34487)
echo.
set /p PORT=Digite a porta agora: 

echo.
echo Conectando a %IP%:%PORT%...
%ADB% kill-server 2>nul
%ADB% start-server
%ADB% connect %IP%:%PORT%

echo Verificando conexao...
%ADB% -s %IP%:%PORT% get-state
if errorlevel 1 (
    echo ERRO: Dispositivo nao encontrado. Tente novamente.
    pause
    exit /b 1
)

echo.
echo Instalando APK...
%ADB% -s %IP%:%PORT% install -r "%APK%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo    INSTALADO COM SUCESSO!
    echo ============================================
    %ADB% -s %IP%:%PORT% shell am start -n "com.portalapp.portal_launcher/.MainActivity"
) else (
    echo.
    echo FALHA na instalacao. Codigo: %ERRORLEVEL%
)

echo.
pause

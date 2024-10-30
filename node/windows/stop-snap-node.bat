@echo off
SETLOCAL

:: Stop docker-compose up -d
docker-compose stop snap_node
docker-compose rm -f snap_node
if %errorlevel% equ 0 (
    echo Docker-compose is running in the background.
) else (
    echo Failed to start docker-compose.
)

ENDLOCAL
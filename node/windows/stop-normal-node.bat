@echo off
SETLOCAL

:: Stop docker-compose up -d
docker-compose stop normal_node
docker-compose rm -f normal_node
if %errorlevel% equ 0 (
    echo Docker-compose is running in the background.
) else (
    echo Failed to start docker-compose.
)

ENDLOCAL
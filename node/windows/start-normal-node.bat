@echo off
SETLOCAL

:: Check if the image exists
docker inspect vcity/validator:latest >nul 2>&1
if %errorlevel% equ 0 (
    echo Image vcity/validator:latest already exists.
) else (
    echo Image vcity/validator:latest does not exist, importing...
    docker load -i myimage.tar
)

:: Run docker-compose up -d
docker-compose up -d normal_node
if %errorlevel% equ 0 (
    echo Docker-compose is running in the background.
) else (
    echo Failed to start docker-compose.
)

ENDLOCAL
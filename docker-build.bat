setlocal
cd %~dp0
call load-env
for /f %%i in ('docker info --format "{{.OSType}}"') do SET DOCKER_OS=%%i
call docker build -t tmp/farah:%PHP_VERSION% --build-arg PHP_VERSION=%PHP_VERSION% %DOCKER_OS%
endlocal
rem pause
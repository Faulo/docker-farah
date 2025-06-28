setlocal
cd %~dp0
call load-env
for /f %%i in ('docker --context dende info --format "{{.OSType}}"') do SET DOCKER_OS=%%i
call docker --context dende build -t tmp/farah:%PHP_VERSION% --build-arg PHP_VERSION=%PHP_VERSION% %DOCKER_OS%
endlocal
pause
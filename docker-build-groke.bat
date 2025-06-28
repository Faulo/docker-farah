setlocal
cd %~dp0
call load-env
for /f %%i in ('docker --context groke info --format "{{.OSType}}"') do SET DOCKER_OS=%%i
call docker --context groke build -t tmp/farah:%PHP_VERSION% --build-arg PHP_VERSION=%PHP_VERSION% %DOCKER_OS%
endlocal
rem pause
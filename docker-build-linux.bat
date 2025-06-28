setlocal
cd %~dp0
call load-env
SET DOCKER_OS=linux
call docker --context groke build -t tmp/farah:%PHP_VERSION% --build-arg PHP_VERSION=%PHP_VERSION% %DOCKER_OS%
endlocal
rem pause
SET PHP_VERSION=8.0
for /f %%i in ('docker info --format "{{.OSType}}"') do SET DOCKER_OS=%%i
call docker build -t faulo/farah:test --build-arg PHP_VERSION=%PHP_VERSION% %DOCKER_OS%
pause
SET PHP_VERSION=8.0
call docker build -t faulo/farah:test --build-arg PHP_VERSION=%PHP_VERSION% .
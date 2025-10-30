if not defined COMPOSER_UPDATE set COMPOSER_UPDATE=install

if /I "%COMPOSER_UPDATE%"=="skip"        goto :case_skip
if /I "%COMPOSER_UPDATE%"=="install"     goto :case_install
if /I "%COMPOSER_UPDATE%"=="install-dev" goto :case_install_dev
if /I "%COMPOSER_UPDATE%"=="lowest"      goto :case_lowest
if /I "%COMPOSER_UPDATE%"=="lowest-dev"  goto :case_lowest_dev
if /I "%COMPOSER_UPDATE%"=="stable"      goto :case_stable
if /I "%COMPOSER_UPDATE%"=="stable-dev"  goto :case_stable_dev
echo Unknown COMPOSER_UPDATE mode: "%COMPOSER_UPDATE%"
goto :continue

:case_skip
  echo Skipping composer update step.
  goto :continue

:case_install
  call composer -d C:\www install --no-interaction --no-dev --optimize-autoloader --classmap-authoritative
  goto :continue

:case_install_dev
  call composer -d C:\www install --no-interaction
  goto :continue

:case_lowest
  call composer -d C:\www update --no-interaction --prefer-lowest --no-dev --optimize-autoloader --classmap-authoritative
  goto :continue

:case_lowest_dev
  call composer -d C:\www update --no-interaction --prefer-lowest
  goto :continue

:case_stable
  call composer -d C:\www update --no-interaction --prefer-stable --no-dev --optimize-autoloader --classmap-authoritative
  goto :continue

:case_stable_dev
  call composer -d C:\www update --no-interaction --prefer-stable
  goto :continue

:continue
powershell -Command "Get-Content -Path '%APPDATA%/Apache24/logs/error.log' -Wait -Tail 10
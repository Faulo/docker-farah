call composer -d C:/www install --no-interaction --no-dev --optimize-autoloader --classmap-authoritative
powershell -Command "Get-Content -Path '%APPDATA%/Apache24/logs/error.log' -Wait -Tail 10
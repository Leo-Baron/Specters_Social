@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM Specters Application Manager - Version Windows
REM Script de démarrage et d'extinction complet de l'application Specters
REM =============================================================================

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%specters-manager.log"
set "PID_FILE=%SCRIPT_DIR%.specters-pids"
set "DOCKER_COMPOSE_FILE=%SCRIPT_DIR%docker-compose.dev.yaml"

REM Variables globales
set "VERBOSE=false"
set "DRY_RUN=false"
set "COMMAND="

REM =============================================================================
REM Fonctions utilitaires
REM =============================================================================

:log
set "level=%1"
set "message=%~2"
set "timestamp=%date% %time%"

if "%level%"=="INFO" (
    echo [INFO]  %message%
) else if "%level%"=="WARN" (
    echo [WARN]  %message%
) else if "%level%"=="ERROR" (
    echo [ERROR] %message%
) else if "%level%"=="SUCCESS" (
    echo [SUCCESS] %message%
) else if "%level%"=="DEBUG" (
    if "%VERBOSE%"=="true" echo [DEBUG] %message%
)

echo [%timestamp%] [%level%] %message% >> "%LOG_FILE%"
goto :eof

:show_banner
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                    SPECTERS MANAGER                          ║
echo ║              Gestionnaire d'application complet             ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
goto :eof

:check_prerequisites
call :log "INFO" "Vérification des prérequis..."

REM Vérifier Node.js
node --version >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Node.js n'est pas installé"
    exit /b 1
)

for /f "tokens=*" %%i in ('node --version') do set "node_version=%%i"
set "node_version=%node_version:v=%"
call :log "DEBUG" "Node.js version: %node_version% ✓"

REM Vérifier pnpm
pnpm --version >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "pnpm n'est pas installé"
    exit /b 1
)

for /f "tokens=*" %%i in ('pnpm --version') do set "pnpm_version=%%i"
call :log "DEBUG" "pnpm version: %pnpm_version% ✓"

REM Vérifier Docker
docker --version >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker n'est pas installé"
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    call :log "ERROR" "Docker n'est pas démarré"
    exit /b 1
)

for /f "tokens=*" %%i in ('docker --version') do set "docker_version=%%i"
call :log "DEBUG" "Docker version: %docker_version% ✓"

REM Vérifier le fichier .env
if not exist "%SCRIPT_DIR%.env" (
    call :log "WARN" "Fichier .env non trouvé, copie depuis .env.example"
    if exist "%SCRIPT_DIR%.env.example" (
        copy "%SCRIPT_DIR%.env.example" "%SCRIPT_DIR%.env" >nul
        call :log "INFO" "Fichier .env créé. Veuillez le configurer avant de continuer."
    ) else (
        call :log "ERROR" "Fichier .env.example non trouvé"
        exit /b 1
    )
)

call :log "SUCCESS" "Tous les prérequis sont satisfaits"
goto :eof

:wait_for_port
set "port=%1"
set "service_name=%2"
set "timeout=%3"
if "%timeout%"=="" set "timeout=60"
set "count=0"

call :log "INFO" "Attente du service %service_name% sur le port %port%..."

:wait_loop
netstat -an | findstr ":%port% " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    call :log "SUCCESS" "%service_name% est disponible sur le port %port%"
    goto :eof
)

if %count% geq %timeout% (
    call :log "ERROR" "Timeout: %service_name% n'est pas disponible sur le port %port%"
    exit /b 1
)

timeout /t 1 /nobreak >nul
set /a count+=1

if !count! geq 10 (
    set /a remainder=!count! %% 10
    if !remainder! equ 0 (
        call :log "DEBUG" "Attente %service_name%... (!count!/%timeout%s)"
    )
)

goto wait_loop

:save_pid
set "service_name=%1"
set "pid=%2"
echo %service_name%:%pid% >> "%PID_FILE%"
call :log "DEBUG" "PID %pid% sauvegardé pour %service_name%"
goto :eof

:cleanup_pid_file
if exist "%PID_FILE%" (
    del "%PID_FILE%"
    call :log "DEBUG" "Fichier PID nettoyé"
)
goto :eof

REM =============================================================================
REM Fonctions Docker
REM =============================================================================

:start_docker_services
call :log "INFO" "Démarrage des services Docker..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] docker-compose -f %DOCKER_COMPOSE_FILE% up -d"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

docker-compose -f "%DOCKER_COMPOSE_FILE%" up -d
if errorlevel 1 (
    call :log "ERROR" "Échec du démarrage des services Docker"
    exit /b 1
)

REM Attendre que les services soient prêts
call :wait_for_port 5432 "PostgreSQL" 30
call :wait_for_port 6379 "Redis" 30

call :log "SUCCESS" "Services Docker démarrés"
goto :eof

:stop_docker_services
call :log "INFO" "Arrêt des services Docker..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] docker-compose -f %DOCKER_COMPOSE_FILE% down"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

docker-compose -f "%DOCKER_COMPOSE_FILE%" down
if not errorlevel 1 (
    call :log "SUCCESS" "Services Docker arrêtés"
) else (
    call :log "WARN" "Problème lors de l'arrêt des services Docker"
)
goto :eof

REM =============================================================================
REM Fonctions de gestion des applications
REM =============================================================================

:install_dependencies
call :log "INFO" "Installation des dépendances..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm install"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

pnpm install
if errorlevel 1 (
    call :log "ERROR" "Échec de l'installation des dépendances"
    exit /b 1
)

call :log "SUCCESS" "Dépendances installées"
goto :eof

:setup_database
call :log "INFO" "Configuration de la base de données..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm run prisma-generate && pnpm run prisma-db-push"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

REM Générer le client Prisma
pnpm run prisma-generate
if errorlevel 1 (
    call :log "ERROR" "Échec de la génération du client Prisma"
    exit /b 1
)

REM Pousser le schéma vers la base de données
pnpm run prisma-db-push
if errorlevel 1 (
    call :log "ERROR" "Échec de la synchronisation de la base de données"
    exit /b 1
)

call :log "SUCCESS" "Base de données configurée"
goto :eof

:start_backend
call :log "INFO" "Démarrage du backend..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm run dev:backend"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

REM Créer le dossier logs s'il n'existe pas
if not exist "logs" mkdir logs

REM Démarrer le backend en arrière-plan
start /b "" cmd /c "pnpm run dev:backend > logs\backend.log 2>&1"

REM Attendre que le backend soit prêt
call :wait_for_port 3000 "Backend" 60
if not errorlevel 1 (
    call :log "SUCCESS" "Backend démarré"
) else (
    call :log "ERROR" "Échec du démarrage du backend"
    exit /b 1
)
goto :eof

:start_frontend
call :log "INFO" "Démarrage du frontend..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm run dev:frontend"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

REM Démarrer le frontend en arrière-plan
start /b "" cmd /c "pnpm run dev:frontend > logs\frontend.log 2>&1"

REM Attendre que le frontend soit prêt
call :wait_for_port 4200 "Frontend" 60
if not errorlevel 1 (
    call :log "SUCCESS" "Frontend démarré"
) else (
    call :log "ERROR" "Échec du démarrage du frontend"
    exit /b 1
)
goto :eof

:start_workers
call :log "INFO" "Démarrage des workers..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm run dev:workers"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

REM Démarrer les workers en arrière-plan
start /b "" cmd /c "pnpm run dev:workers > logs\workers.log 2>&1"

call :log "SUCCESS" "Workers démarrés"
goto :eof

:start_cron
call :log "INFO" "Démarrage du service cron..."

if "%DRY_RUN%"=="true" (
    call :log "INFO" "[DRY RUN] pnpm run dev:cron"
    goto :eof
)

cd /d "%SCRIPT_DIR%"

REM Démarrer le service cron en arrière-plan
start /b "" cmd /c "pnpm run dev:cron > logs\cron.log 2>&1"

call :log "SUCCESS" "Service cron démarré"
goto :eof

REM =============================================================================
REM Fonctions principales
REM =============================================================================

:start_all
call :show_banner
call :log "INFO" "Démarrage complet de l'application Specters..."

REM Créer le dossier de logs
if not exist "%SCRIPT_DIR%logs" mkdir "%SCRIPT_DIR%logs"

REM Nettoyer le fichier PID précédent
call :cleanup_pid_file

REM Vérifier les prérequis
call :check_prerequisites
if errorlevel 1 exit /b 1

REM Démarrer les services Docker
call :start_docker_services
if errorlevel 1 (
    call :log "ERROR" "Échec du démarrage des services Docker"
    exit /b 1
)

REM Installer les dépendances
call :install_dependencies
if errorlevel 1 (
    call :log "ERROR" "Échec de l'installation des dépendances"
    exit /b 1
)

REM Configurer la base de données
call :setup_database
if errorlevel 1 (
    call :log "ERROR" "Échec de la configuration de la base de données"
    exit /b 1
)

REM Démarrer les applications
call :start_backend
call :start_frontend
call :start_workers
call :start_cron

call :log "SUCCESS" "Application Specters démarrée avec succès!"
call :log "INFO" "Frontend disponible sur: http://localhost:4200"
call :log "INFO" "Backend API disponible sur: http://localhost:3000"
call :log "INFO" "PgAdmin disponible sur: http://localhost:8081"
call :log "INFO" "RedisInsight disponible sur: http://localhost:5540"

echo.
echo 🚀 Application Specters démarrée avec succès!
echo 📱 Frontend: http://localhost:4200
echo 🔧 Backend:  http://localhost:3000
echo 🗄️  PgAdmin: http://localhost:8081
echo 📊 Redis:    http://localhost:5540
goto :eof

:stop_all
call :log "INFO" "Arrêt complet de l'application Specters..."

REM Arrêter les processus Node.js
for /f "tokens=1,2 delims=:" %%a in ('type "%PID_FILE%" 2^>nul') do (
    call :log "INFO" "Arrêt de %%a"
    if "%DRY_RUN%"=="false" (
        taskkill /f /im node.exe >nul 2>&1
        taskkill /f /im "nest.exe" >nul 2>&1
        taskkill /f /im "next.exe" >nul 2>&1
    )
)

REM Arrêter les services Docker
call :stop_docker_services

REM Nettoyer le fichier PID
call :cleanup_pid_file

call :log "SUCCESS" "Application Specters arrêtée"
echo 🛑 Application Specters arrêtée avec succès!
goto :eof

:restart_all
call :log "INFO" "Redémarrage de l'application Specters..."
call :stop_all
timeout /t 3 /nobreak >nul
call :start_all
goto :eof

:show_status
echo === État des services Specters ===
echo.

echo Services Docker:
docker-compose -f "%DOCKER_COMPOSE_FILE%" ps 2>nul
echo.

echo État des ports:
set "ports=3000:Backend 4200:Frontend 5432:PostgreSQL 6379:Redis 8081:PgAdmin 5540:RedisInsight"

for %%p in (%ports%) do (
    for /f "tokens=1,2 delims=:" %%a in ("%%p") do (
        netstat -an | findstr ":%%a " | findstr "LISTENING" >nul 2>&1
        if not errorlevel 1 (
            echo ✅ %%b ^(port %%a^)
        ) else (
            echo ❌ %%b ^(port %%a^)
        )
    )
)
goto :eof

:show_logs
set "service=%1"
if "%service%"=="" set "service=all"

if "%service%"=="backend" (
    type "%SCRIPT_DIR%logs\backend.log" 2>nul || call :log "ERROR" "Log backend non trouvé"
) else if "%service%"=="frontend" (
    type "%SCRIPT_DIR%logs\frontend.log" 2>nul || call :log "ERROR" "Log frontend non trouvé"
) else if "%service%"=="workers" (
    type "%SCRIPT_DIR%logs\workers.log" 2>nul || call :log "ERROR" "Log workers non trouvé"
) else if "%service%"=="cron" (
    type "%SCRIPT_DIR%logs\cron.log" 2>nul || call :log "ERROR" "Log cron non trouvé"
) else if "%service%"=="manager" (
    type "%LOG_FILE%" 2>nul || call :log "ERROR" "Log manager non trouvé"
) else (
    call :log "INFO" "Affichage des logs combinés"
    for %%f in ("%SCRIPT_DIR%logs\*.log" "%LOG_FILE%") do (
        if exist "%%f" type "%%f"
    )
)
goto :eof

:show_help
echo Specters Manager - Gestionnaire d'application
echo.
echo Usage:
echo   %~nx0 [COMMAND] [OPTIONS]
echo.
echo Commandes:
echo   start     Démarrer l'application complète
echo   stop      Arrêter l'application complète
echo   restart   Redémarrer l'application complète
echo   status    Afficher l'état des services
echo   logs      Afficher les logs [backend^|frontend^|workers^|cron^|manager^|all]
echo   help      Afficher cette aide
echo.
echo Options:
echo   -v, --verbose    Mode verbeux
echo   -d, --dry-run    Simulation (ne pas exécuter les commandes)
echo.
echo Exemples:
echo   %~nx0 start                 # Démarrer l'application
echo   %~nx0 stop                  # Arrêter l'application
echo   %~nx0 status                # Voir l'état
echo   %~nx0 logs backend          # Voir les logs du backend
echo   %~nx0 start --verbose       # Démarrer en mode verbeux
goto :eof

REM =============================================================================
REM Point d'entrée principal
REM =============================================================================

:main
REM Traitement des arguments
:parse_args
if "%~1"=="" goto execute_command
if "%~1"=="-v" set "VERBOSE=true" & shift & goto parse_args
if "%~1"=="--verbose" set "VERBOSE=true" & shift & goto parse_args
if "%~1"=="-d" set "DRY_RUN=true" & shift & goto parse_args
if "%~1"=="--dry-run" set "DRY_RUN=true" & shift & goto parse_args
if "%~1"=="-h" call :show_help & exit /b 0
if "%~1"=="--help" call :show_help & exit /b 0
if "%~1"=="start" set "COMMAND=start" & shift & goto parse_args
if "%~1"=="stop" set "COMMAND=stop" & shift & goto parse_args
if "%~1"=="restart" set "COMMAND=restart" & shift & goto parse_args
if "%~1"=="status" set "COMMAND=status" & shift & goto parse_args
if "%~1"=="logs" set "COMMAND=logs" & set "LOG_SERVICE=%~2" & shift & shift & goto parse_args
if "%~1"=="help" set "COMMAND=help" & shift & goto parse_args

call :log "ERROR" "Option inconnue: %~1"
call :show_help
exit /b 1

:execute_command
if "%COMMAND%"=="" (
    call :log "ERROR" "Aucune commande spécifiée"
    call :show_help
    exit /b 1
)

REM Initialiser le fichier de log
echo === Specters Manager - %date% %time% === >> "%LOG_FILE%"

REM Exécuter la commande
if "%COMMAND%"=="start" call :start_all
if "%COMMAND%"=="stop" call :stop_all
if "%COMMAND%"=="restart" call :restart_all
if "%COMMAND%"=="status" call :show_status
if "%COMMAND%"=="logs" call :show_logs "%LOG_SERVICE%"
if "%COMMAND%"=="help" call :show_help

goto :eof

REM Exécuter le script principal
call :main %*

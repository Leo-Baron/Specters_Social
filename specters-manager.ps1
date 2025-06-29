# =============================================================================
# Specters Application Manager - Version PowerShell
# Script de démarrage et d'extinction complet de l'application Specters
# =============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "help")]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$LogService = "all",
    
    [switch]$Verbose,
    [switch]$DryRun,
    [switch]$Help
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "specters-manager.log"
$PidFile = Join-Path $ScriptDir ".specters-pids"
$DockerComposeFile = Join-Path $ScriptDir "docker-compose.dev.yaml"

# Variables globales
$Global:VerboseMode = $Verbose
$Global:DryRunMode = $DryRun

# =============================================================================
# Fonctions utilitaires
# =============================================================================

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
        "DEBUG" = "Blue"
    }
    
    $color = $colorMap[$Level]
    if ($Level -eq "DEBUG" -and -not $Global:VerboseMode) {
        return
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
    Add-Content -Path $LogFile -Value "[$timestamp] [$Level] $Message"
}

function Show-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                    SPECTERS MANAGER                          ║" -ForegroundColor Magenta
    Write-Host "║              Gestionnaire d'application complet             ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

function Test-Prerequisites {
    Write-Log "INFO" "Vérification des prérequis..."
    
    # Vérifier Node.js
    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Node.js non trouvé"
        }
        $nodeVersion = $nodeVersion -replace "v", ""
        Write-Log "DEBUG" "Node.js version: $nodeVersion ✓"
    }
    catch {
        Write-Log "ERROR" "Node.js n'est pas installé"
        return $false
    }
    
    # Vérifier pnpm
    try {
        $pnpmVersion = pnpm --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "pnpm non trouvé"
        }
        Write-Log "DEBUG" "pnpm version: $pnpmVersion ✓"
    }
    catch {
        Write-Log "ERROR" "pnpm n'est pas installé"
        return $false
    }
    
    # Vérifier Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker non trouvé"
        }
        Write-Log "DEBUG" "Docker version: $dockerVersion ✓"
        
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker non démarré"
        }
    }
    catch {
        Write-Log "ERROR" "Docker n'est pas installé ou démarré"
        return $false
    }
    
    # Vérifier le fichier .env
    $envFile = Join-Path $ScriptDir ".env"
    $envExampleFile = Join-Path $ScriptDir ".env.example"
    
    if (-not (Test-Path $envFile)) {
        Write-Log "WARN" "Fichier .env non trouvé, copie depuis .env.example"
        if (Test-Path $envExampleFile) {
            Copy-Item $envExampleFile $envFile
            Write-Log "INFO" "Fichier .env créé. Veuillez le configurer avant de continuer."
        }
        else {
            Write-Log "ERROR" "Fichier .env.example non trouvé"
            return $false
        }
    }
    
    Write-Log "SUCCESS" "Tous les prérequis sont satisfaits"
    return $true
}

function Wait-ForPort {
    param(
        [int]$Port,
        [string]$ServiceName,
        [int]$Timeout = 60
    )
    
    Write-Log "INFO" "Attente du service $ServiceName sur le port $Port..."
    
    $count = 0
    while ($count -lt $Timeout) {
        try {
            $connection = Test-NetConnection -ComputerName "localhost" -Port $Port -WarningAction SilentlyContinue
            if ($connection.TcpTestSucceeded) {
                Write-Log "SUCCESS" "$ServiceName est disponible sur le port $Port"
                return $true
            }
        }
        catch {
            # Continuer à attendre
        }
        
        Start-Sleep -Seconds 1
        $count++
        
        if ($count % 10 -eq 0) {
            Write-Log "DEBUG" "Attente $ServiceName... ($count/${Timeout}s)"
        }
    }
    
    Write-Log "ERROR" "Timeout: $ServiceName n'est pas disponible sur le port $Port"
    return $false
}

function Save-Pid {
    param(
        [string]$ServiceName,
        [int]$Pid
    )
    
    Add-Content -Path $PidFile -Value "$ServiceName:$Pid"
    Write-Log "DEBUG" "PID $Pid sauvegardé pour $ServiceName"
}

function Clear-PidFile {
    if (Test-Path $PidFile) {
        Remove-Item $PidFile -Force
        Write-Log "DEBUG" "Fichier PID nettoyé"
    }
}

# =============================================================================
# Fonctions Docker
# =============================================================================

function Start-DockerServices {
    Write-Log "INFO" "Démarrage des services Docker..."
    
    if ($Global:DryRunMode) {
        Write-Log "INFO" "[DRY RUN] docker-compose -f $DockerComposeFile up -d"
        return $true
    }
    
    Push-Location $ScriptDir
    try {
        docker-compose -f $DockerComposeFile up -d
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR" "Échec du démarrage des services Docker"
            return $false
        }
        
        # Attendre que les services soient prêts
        if (-not (Wait-ForPort -Port 5432 -ServiceName "PostgreSQL" -Timeout 30)) {
            return $false
        }
        if (-not (Wait-ForPort -Port 6379 -ServiceName "Redis" -Timeout 30)) {
            return $false
        }
        
        Write-Log "SUCCESS" "Services Docker démarrés"
        return $true
    }
    finally {
        Pop-Location
    }
}

function Stop-DockerServices {
    Write-Log "INFO" "Arrêt des services Docker..."
    
    if ($Global:DryRunMode) {
        Write-Log "INFO" "[DRY RUN] docker-compose -f $DockerComposeFile down"
        return
    }
    
    Push-Location $ScriptDir
    try {
        docker-compose -f $DockerComposeFile down
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SUCCESS" "Services Docker arrêtés"
        }
        else {
            Write-Log "WARN" "Problème lors de l'arrêt des services Docker"
        }
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Fonctions de gestion des applications
# =============================================================================

function Install-Dependencies {
    Write-Log "INFO" "Installation des dépendances..."
    
    if ($Global:DryRunMode) {
        Write-Log "INFO" "[DRY RUN] pnpm install"
        return $true
    }
    
    Push-Location $ScriptDir
    try {
        pnpm install
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR" "Échec de l'installation des dépendances"
            return $false
        }
        
        Write-Log "SUCCESS" "Dépendances installées"
        return $true
    }
    finally {
        Pop-Location
    }
}

function Initialize-Database {
    Write-Log "INFO" "Configuration de la base de données..."
    
    if ($Global:DryRunMode) {
        Write-Log "INFO" "[DRY RUN] pnpm run prisma-generate && pnpm run prisma-db-push"
        return $true
    }
    
    Push-Location $ScriptDir
    try {
        # Générer le client Prisma
        pnpm run prisma-generate
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR" "Échec de la génération du client Prisma"
            return $false
        }
        
        # Pousser le schéma vers la base de données
        pnpm run prisma-db-push
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR" "Échec de la synchronisation de la base de données"
            return $false
        }
        
        Write-Log "SUCCESS" "Base de données configurée"
        return $true
    }
    finally {
        Pop-Location
    }
}

function Start-Service {
    param(
        [string]$ServiceName,
        [string]$Command,
        [int]$Port = 0
    )
    
    Write-Log "INFO" "Démarrage de $ServiceName..."
    
    if ($Global:DryRunMode) {
        Write-Log "INFO" "[DRY RUN] $Command"
        return $true
    }
    
    # Créer le dossier logs s'il n'existe pas
    $logsDir = Join-Path $ScriptDir "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    
    Push-Location $ScriptDir
    try {
        $logPath = Join-Path $logsDir "$ServiceName.log"
        $process = Start-Process -FilePath "cmd" -ArgumentList "/c", $Command, ">", $logPath, "2>&1" -PassThru -WindowStyle Hidden
        
        if ($process) {
            Save-Pid -ServiceName $ServiceName -Pid $process.Id
            
            if ($Port -gt 0) {
                if (Wait-ForPort -Port $Port -ServiceName $ServiceName -Timeout 60) {
                    Write-Log "SUCCESS" "$ServiceName démarré (PID: $($process.Id))"
                    return $true
                }
                else {
                    Write-Log "ERROR" "Échec du démarrage de $ServiceName"
                    return $false
                }
            }
            else {
                Write-Log "SUCCESS" "$ServiceName démarré (PID: $($process.Id))"
                return $true
            }
        }
        else {
            Write-Log "ERROR" "Impossible de démarrer $ServiceName"
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Fonctions principales
# =============================================================================

function Start-Application {
    Show-Banner
    Write-Log "INFO" "Démarrage complet de l'application Specters..."
    
    # Créer le dossier de logs
    $logsDir = Join-Path $ScriptDir "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    
    # Nettoyer le fichier PID précédent
    Clear-PidFile
    
    # Vérifier les prérequis
    if (-not (Test-Prerequisites)) {
        return $false
    }
    
    # Démarrer les services Docker
    if (-not (Start-DockerServices)) {
        Write-Log "ERROR" "Échec du démarrage des services Docker"
        return $false
    }
    
    # Installer les dépendances
    if (-not (Install-Dependencies)) {
        Write-Log "ERROR" "Échec de l'installation des dépendances"
        return $false
    }
    
    # Configurer la base de données
    if (-not (Initialize-Database)) {
        Write-Log "ERROR" "Échec de la configuration de la base de données"
        return $false
    }
    
    # Démarrer les applications
    Start-Service -ServiceName "backend" -Command "pnpm run dev:backend" -Port 3000
    Start-Service -ServiceName "frontend" -Command "pnpm run dev:frontend" -Port 4200
    Start-Service -ServiceName "workers" -Command "pnpm run dev:workers"
    Start-Service -ServiceName "cron" -Command "pnpm run dev:cron"
    
    Write-Log "SUCCESS" "Application Specters démarrée avec succès!"
    Write-Log "INFO" "Frontend disponible sur: http://localhost:4200"
    Write-Log "INFO" "Backend API disponible sur: http://localhost:3000"
    Write-Log "INFO" "PgAdmin disponible sur: http://localhost:8081"
    Write-Log "INFO" "RedisInsight disponible sur: http://localhost:5540"
    
    Write-Host ""
    Write-Host "🚀 Application Specters démarrée avec succès!" -ForegroundColor Green
    Write-Host "📱 Frontend: http://localhost:4200" -ForegroundColor Cyan
    Write-Host "🔧 Backend:  http://localhost:3000" -ForegroundColor Cyan
    Write-Host "🗄️  PgAdmin: http://localhost:8081" -ForegroundColor Cyan
    Write-Host "📊 Redis:    http://localhost:5540" -ForegroundColor Cyan
    
    return $true
}

function Stop-Application {
    Write-Log "INFO" "Arrêt complet de l'application Specters..."
    
    # Arrêter les processus Node.js
    if (Test-Path $PidFile) {
        $pids = Get-Content $PidFile
        foreach ($line in $pids) {
            $parts = $line -split ":"
            if ($parts.Length -eq 2) {
                $serviceName = $parts[0]
                $pid = [int]$parts[1]
                
                Write-Log "INFO" "Arrêt de $serviceName (PID: $pid)"
                if (-not $Global:DryRunMode) {
                    try {
                        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Log "DEBUG" "Processus $serviceName (PID: $pid) déjà arrêté"
                    }
                }
            }
        }
    }
    
    # Nettoyer les processus orphelins
    Write-Log "INFO" "Nettoyage des processus orphelins..."
    if (-not $Global:DryRunMode) {
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    
    # Arrêter les services Docker
    Stop-DockerServices
    
    # Nettoyer le fichier PID
    Clear-PidFile
    
    Write-Log "SUCCESS" "Application Specters arrêtée"
    Write-Host "🛑 Application Specters arrêtée avec succès!" -ForegroundColor Green
}

function Restart-Application {
    Write-Log "INFO" "Redémarrage de l'application Specters..."
    Stop-Application
    Start-Sleep -Seconds 3
    Start-Application
}

function Show-Status {
    Write-Host "=== État des services Specters ===" -ForegroundColor Magenta
    Write-Host ""
    
    # Vérifier les services Docker
    Write-Host "Services Docker:" -ForegroundColor Blue
    Push-Location $ScriptDir
    try {
        docker-compose -f $DockerComposeFile ps 2>$null
    }
    finally {
        Pop-Location
    }
    Write-Host ""
    
    # Vérifier les ports
    Write-Host "État des ports:" -ForegroundColor Blue
    $ports = @{
        3000 = "Backend"
        4200 = "Frontend"
        5432 = "PostgreSQL"
        6379 = "Redis"
        8081 = "PgAdmin"
        5540 = "RedisInsight"
    }
    
    foreach ($port in $ports.Keys) {
        $serviceName = $ports[$port]
        try {
            $connection = Test-NetConnection -ComputerName "localhost" -Port $port -WarningAction SilentlyContinue
            if ($connection.TcpTestSucceeded) {
                Write-Host "✅ $serviceName (port $port)" -ForegroundColor Green
            }
            else {
                Write-Host "❌ $serviceName (port $port)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ $serviceName (port $port)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Vérifier les processus
    Write-Host "Processus actifs:" -ForegroundColor Blue
    if (Test-Path $PidFile) {
        $pids = Get-Content $PidFile
        foreach ($line in $pids) {
            $parts = $line -split ":"
            if ($parts.Length -eq 2) {
                $serviceName = $parts[0]
                $pid = [int]$parts[1]
                
                try {
                    $process = Get-Process -Id $pid -ErrorAction Stop
                    Write-Host "✅ $serviceName (PID: $pid)" -ForegroundColor Green
                }
                catch {
                    Write-Host "❌ $serviceName (PID: $pid - arrêté)" -ForegroundColor Red
                }
            }
        }
    }
    else {
        Write-Host "⚠️  Aucun fichier PID trouvé" -ForegroundColor Yellow
    }
}

function Show-Logs {
    param([string]$Service = "all")
    
    $logsDir = Join-Path $ScriptDir "logs"
    
    switch ($Service.ToLower()) {
        "backend" {
            $logPath = Join-Path $logsDir "backend.log"
            if (Test-Path $logPath) {
                Get-Content $logPath -Tail 50
            }
            else {
                Write-Log "ERROR" "Log backend non trouvé"
            }
        }
        "frontend" {
            $logPath = Join-Path $logsDir "frontend.log"
            if (Test-Path $logPath) {
                Get-Content $logPath -Tail 50
            }
            else {
                Write-Log "ERROR" "Log frontend non trouvé"
            }
        }
        "workers" {
            $logPath = Join-Path $logsDir "workers.log"
            if (Test-Path $logPath) {
                Get-Content $logPath -Tail 50
            }
            else {
                Write-Log "ERROR" "Log workers non trouvé"
            }
        }
        "cron" {
            $logPath = Join-Path $logsDir "cron.log"
            if (Test-Path $logPath) {
                Get-Content $logPath -Tail 50
            }
            else {
                Write-Log "ERROR" "Log cron non trouvé"
            }
        }
        "manager" {
            if (Test-Path $LogFile) {
                Get-Content $LogFile -Tail 50
            }
            else {
                Write-Log "ERROR" "Log manager non trouvé"
            }
        }
        default {
            Write-Log "INFO" "Affichage des logs combinés"
            if (Test-Path $logsDir) {
                Get-ChildItem -Path $logsDir -Filter "*.log" | ForEach-Object {
                    Write-Host "=== $($_.Name) ===" -ForegroundColor Yellow
                    Get-Content $_.FullName -Tail 20
                    Write-Host ""
                }
            }
            if (Test-Path $LogFile) {
                Write-Host "=== Manager Log ===" -ForegroundColor Yellow
                Get-Content $LogFile -Tail 20
            }
        }
    }
}

function Show-Help {
    Write-Host "Specters Manager - Gestionnaire d'application" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Blue
    Write-Host "  .\specters-manager.ps1 [COMMAND] [OPTIONS]"
    Write-Host ""
    Write-Host "Commandes:" -ForegroundColor Blue
    Write-Host "  start     Démarrer l'application complète"
    Write-Host "  stop      Arrêter l'application complète"
    Write-Host "  restart   Redémarrer l'application complète"
    Write-Host "  status    Afficher l'état des services"
    Write-Host "  logs      Afficher les logs [backend|frontend|workers|cron|manager|all]"
    Write-Host "  help      Afficher cette aide"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Blue
    Write-Host "  -Verbose    Mode verbeux"
    Write-Host "  -DryRun     Simulation (ne pas exécuter les commandes)"
    Write-Host ""
    Write-Host "Exemples:" -ForegroundColor Blue
    Write-Host "  .\specters-manager.ps1 start                 # Démarrer l'application"
    Write-Host "  .\specters-manager.ps1 stop                  # Arrêter l'application"
    Write-Host "  .\specters-manager.ps1 status                # Voir l'état"
    Write-Host "  .\specters-manager.ps1 logs backend          # Voir les logs du backend"
    Write-Host "  .\specters-manager.ps1 start -Verbose        # Démarrer en mode verbeux"
}

# =============================================================================
# Point d'entrée principal
# =============================================================================

# Initialiser le fichier de log
Add-Content -Path $LogFile -Value "=== Specters Manager - $(Get-Date) ==="

# Traitement des commandes
if ($Help -or $Command -eq "help" -or -not $Command) {
    Show-Help
    exit 0
}

switch ($Command.ToLower()) {
    "start" {
        if (Start-Application) {
            exit 0
        } else {
            exit 1
        }
    }
    "stop" {
        Stop-Application
        exit 0
    }
    "restart" {
        Restart-Application
        exit 0
    }
    "status" {
        Show-Status
        exit 0
    }
    "logs" {
        Show-Logs -Service $LogService
        exit 0
    }
    default {
        Write-Log "ERROR" "Commande inconnue: $Command"
        Show-Help
        exit 1
    }
}

#!/bin/bash

# =============================================================================
# Specters Application Manager
# Script de démarrage et d'extinction complet de l'application Specters
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/specters-manager.log"
PID_FILE="$SCRIPT_DIR/.specters-pids"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.dev.yaml"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
VERBOSE=false
DRY_RUN=false

# =============================================================================
# Fonctions utilitaires
# =============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") [[ $VERBOSE == true ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    SPECTERS MANAGER                          ║"
    echo "║              Gestionnaire d'application complet             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_prerequisites() {
    log "INFO" "Vérification des prérequis..."
    
    # Vérifier Node.js
    if ! command -v node &> /dev/null; then
        log "ERROR" "Node.js n'est pas installé"
        exit 1
    fi
    
    local node_version=$(node --version | sed 's/v//')
    local required_version="20.0.0"
    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        log "ERROR" "Node.js version $node_version détectée. Version >= $required_version requise"
        exit 1
    fi
    log "DEBUG" "Node.js version: $node_version ✓"
    
    # Vérifier pnpm
    if ! command -v pnpm &> /dev/null; then
        log "ERROR" "pnpm n'est pas installé"
        exit 1
    fi
    log "DEBUG" "pnpm version: $(pnpm --version) ✓"
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker n'est pas installé"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log "ERROR" "Docker n'est pas démarré"
        exit 1
    fi
    log "DEBUG" "Docker version: $(docker --version) ✓"
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log "ERROR" "Docker Compose n'est pas installé"
        exit 1
    fi
    log "DEBUG" "Docker Compose disponible ✓"
    
    # Vérifier le fichier .env
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        log "WARN" "Fichier .env non trouvé, copie depuis .env.example"
        if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            log "INFO" "Fichier .env créé. Veuillez le configurer avant de continuer."
        else
            log "ERROR" "Fichier .env.example non trouvé"
            exit 1
        fi
    fi
    
    log "SUCCESS" "Tous les prérequis sont satisfaits"
}

wait_for_port() {
    local port=$1
    local service_name=$2
    local timeout=${3:-60}
    local count=0
    
    log "INFO" "Attente du service $service_name sur le port $port..."
    
    while ! nc -z localhost $port 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            log "ERROR" "Timeout: $service_name n'est pas disponible sur le port $port"
            return 1
        fi
        sleep 1
        ((count++))
        if [[ $((count % 10)) -eq 0 ]]; then
            log "DEBUG" "Attente $service_name... ($count/${timeout}s)"
        fi
    done
    
    log "SUCCESS" "$service_name est disponible sur le port $port"
    return 0
}

check_port_available() {
    local port=$1
    if nc -z localhost $port 2>/dev/null; then
        return 1  # Port occupé
    fi
    return 0  # Port libre
}

save_pid() {
    local service_name=$1
    local pid=$2
    echo "$service_name:$pid" >> "$PID_FILE"
    log "DEBUG" "PID $pid sauvegardé pour $service_name"
}

load_pids() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE"
    fi
}

cleanup_pid_file() {
    if [[ -f "$PID_FILE" ]]; then
        rm "$PID_FILE"
        log "DEBUG" "Fichier PID nettoyé"
    fi
}

# =============================================================================
# Fonctions Docker
# =============================================================================

start_docker_services() {
    log "INFO" "Démarrage des services Docker..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] docker-compose -f $DOCKER_COMPOSE_FILE up -d"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    if ! docker-compose -f "$DOCKER_COMPOSE_FILE" up -d; then
        log "ERROR" "Échec du démarrage des services Docker"
        return 1
    fi
    
    # Attendre que les services soient prêts
    wait_for_port 5432 "PostgreSQL" 30
    wait_for_port 6379 "Redis" 30
    
    log "SUCCESS" "Services Docker démarrés"
    return 0
}

stop_docker_services() {
    log "INFO" "Arrêt des services Docker..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] docker-compose -f $DOCKER_COMPOSE_FILE down"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down; then
        log "SUCCESS" "Services Docker arrêtés"
    else
        log "WARN" "Problème lors de l'arrêt des services Docker"
    fi
}

# =============================================================================
# Fonctions de gestion des applications
# =============================================================================

install_dependencies() {
    log "INFO" "Installation des dépendances..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm install"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    if ! pnpm install; then
        log "ERROR" "Échec de l'installation des dépendances"
        return 1
    fi
    
    log "SUCCESS" "Dépendances installées"
    return 0
}

setup_database() {
    log "INFO" "Configuration de la base de données..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm run prisma-generate && pnpm run prisma-db-push"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Générer le client Prisma
    if ! pnpm run prisma-generate; then
        log "ERROR" "Échec de la génération du client Prisma"
        return 1
    fi
    
    # Pousser le schéma vers la base de données
    if ! pnpm run prisma-db-push; then
        log "ERROR" "Échec de la synchronisation de la base de données"
        return 1
    fi
    
    log "SUCCESS" "Base de données configurée"
    return 0
}

start_backend() {
    log "INFO" "Démarrage du backend..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm run dev:backend"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Démarrer le backend en arrière-plan
    nohup pnpm run dev:backend > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
    local backend_pid=$!
    save_pid "backend" $backend_pid
    
    # Attendre que le backend soit prêt
    if wait_for_port 3000 "Backend" 60; then
        log "SUCCESS" "Backend démarré (PID: $backend_pid)"
        return 0
    else
        log "ERROR" "Échec du démarrage du backend"
        return 1
    fi
}

start_frontend() {
    log "INFO" "Démarrage du frontend..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm run dev:frontend"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Démarrer le frontend en arrière-plan
    nohup pnpm run dev:frontend > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
    local frontend_pid=$!
    save_pid "frontend" $frontend_pid
    
    # Attendre que le frontend soit prêt
    if wait_for_port 4200 "Frontend" 60; then
        log "SUCCESS" "Frontend démarré (PID: $frontend_pid)"
        return 0
    else
        log "ERROR" "Échec du démarrage du frontend"
        return 1
    fi
}

start_workers() {
    log "INFO" "Démarrage des workers..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm run dev:workers"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Démarrer les workers en arrière-plan
    nohup pnpm run dev:workers > "$SCRIPT_DIR/logs/workers.log" 2>&1 &
    local workers_pid=$!
    save_pid "workers" $workers_pid
    
    log "SUCCESS" "Workers démarrés (PID: $workers_pid)"
    return 0
}

start_cron() {
    log "INFO" "Démarrage du service cron..."
    
    if [[ $DRY_RUN == true ]]; then
        log "INFO" "[DRY RUN] pnpm run dev:cron"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    
    # Démarrer le service cron en arrière-plan
    nohup pnpm run dev:cron > "$SCRIPT_DIR/logs/cron.log" 2>&1 &
    local cron_pid=$!
    save_pid "cron" $cron_pid
    
    log "SUCCESS" "Service cron démarré (PID: $cron_pid)"
    return 0
}

# =============================================================================
# Fonctions principales
# =============================================================================

start_all() {
    show_banner
    log "INFO" "Démarrage complet de l'application Specters..."
    
    # Créer le dossier de logs
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Nettoyer le fichier PID précédent
    cleanup_pid_file
    
    # Vérifier les prérequis
    check_prerequisites
    
    # Démarrer les services Docker
    if ! start_docker_services; then
        log "ERROR" "Échec du démarrage des services Docker"
        exit 1
    fi
    
    # Installer les dépendances
    if ! install_dependencies; then
        log "ERROR" "Échec de l'installation des dépendances"
        exit 1
    fi
    
    # Configurer la base de données
    if ! setup_database; then
        log "ERROR" "Échec de la configuration de la base de données"
        exit 1
    fi
    
    # Démarrer les applications
    start_backend
    start_frontend
    start_workers
    start_cron
    
    log "SUCCESS" "Application Specters démarrée avec succès!"
    log "INFO" "Frontend disponible sur: http://localhost:4200"
    log "INFO" "Backend API disponible sur: http://localhost:3000"
    log "INFO" "PgAdmin disponible sur: http://localhost:8081"
    log "INFO" "RedisInsight disponible sur: http://localhost:5540"
    
    echo ""
    echo -e "${GREEN}🚀 Application Specters démarrée avec succès!${NC}"
    echo -e "${CYAN}📱 Frontend: http://localhost:4200${NC}"
    echo -e "${CYAN}🔧 Backend:  http://localhost:3000${NC}"
    echo -e "${CYAN}🗄️  PgAdmin: http://localhost:8081${NC}"
    echo -e "${CYAN}📊 Redis:    http://localhost:5540${NC}"
}

stop_all() {
    log "INFO" "Arrêt complet de l'application Specters..."
    
    # Arrêter les processus Node.js
    if [[ -f "$PID_FILE" ]]; then
        while IFS=':' read -r service_name pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                log "INFO" "Arrêt de $service_name (PID: $pid)"
                if [[ $DRY_RUN == false ]]; then
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        log "WARN" "Arrêt forcé de $service_name"
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                fi
            else
                log "DEBUG" "Processus $service_name (PID: $pid) déjà arrêté"
            fi
        done < "$PID_FILE"
    fi
    
    # Nettoyer les processus orphelins
    log "INFO" "Nettoyage des processus orphelins..."
    if [[ $DRY_RUN == false ]]; then
        pkill -f "nest start" 2>/dev/null || true
        pkill -f "next dev" 2>/dev/null || true
        pkill -f "specters" 2>/dev/null || true
    fi
    
    # Arrêter les services Docker
    stop_docker_services
    
    # Nettoyer le fichier PID
    cleanup_pid_file
    
    log "SUCCESS" "Application Specters arrêtée"
    echo -e "${GREEN}🛑 Application Specters arrêtée avec succès!${NC}"
}

restart_all() {
    log "INFO" "Redémarrage de l'application Specters..."
    stop_all
    sleep 3
    start_all
}

show_status() {
    echo -e "${PURPLE}=== État des services Specters ===${NC}"
    echo ""
    
    # Vérifier les services Docker
    echo -e "${BLUE}Services Docker:${NC}"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps 2>/dev/null; then
        echo ""
    else
        echo -e "${RED}❌ Services Docker non démarrés${NC}"
        echo ""
    fi
    
    # Vérifier les ports
    echo -e "${BLUE}État des ports:${NC}"
    local ports=("3000:Backend" "4200:Frontend" "5432:PostgreSQL" "6379:Redis" "8081:PgAdmin" "5540:RedisInsight")
    
    for port_info in "${ports[@]}"; do
        IFS=':' read -r port service <<< "$port_info"
        if nc -z localhost "$port" 2>/dev/null; then
            echo -e "${GREEN}✅ $service (port $port)${NC}"
        else
            echo -e "${RED}❌ $service (port $port)${NC}"
        fi
    done
    
    echo ""
    
    # Vérifier les processus
    echo -e "${BLUE}Processus actifs:${NC}"
    if [[ -f "$PID_FILE" ]]; then
        while IFS=':' read -r service_name pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}✅ $service_name (PID: $pid)${NC}"
            else
                echo -e "${RED}❌ $service_name (PID: $pid - arrêté)${NC}"
            fi
        done < "$PID_FILE"
    else
        echo -e "${YELLOW}⚠️  Aucun fichier PID trouvé${NC}"
    fi
}

show_logs() {
    local service=${1:-"all"}
    
    case $service in
        "backend")
            tail -f "$SCRIPT_DIR/logs/backend.log" 2>/dev/null || log "ERROR" "Log backend non trouvé"
            ;;
        "frontend")
            tail -f "$SCRIPT_DIR/logs/frontend.log" 2>/dev/null || log "ERROR" "Log frontend non trouvé"
            ;;
        "workers")
            tail -f "$SCRIPT_DIR/logs/workers.log" 2>/dev/null || log "ERROR" "Log workers non trouvé"
            ;;
        "cron")
            tail -f "$SCRIPT_DIR/logs/cron.log" 2>/dev/null || log "ERROR" "Log cron non trouvé"
            ;;
        "manager")
            tail -f "$LOG_FILE" 2>/dev/null || log "ERROR" "Log manager non trouvé"
            ;;
        "all"|*)
            log "INFO" "Affichage des logs combinés (Ctrl+C pour arrêter)"
            tail -f "$SCRIPT_DIR/logs/"*.log "$LOG_FILE" 2>/dev/null || log "ERROR" "Aucun log trouvé"
            ;;
    esac
}

show_help() {
    echo -e "${PURPLE}Specters Manager - Gestionnaire d'application${NC}"
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${BLUE}Commandes:${NC}"
    echo "  start     Démarrer l'application complète"
    echo "  stop      Arrêter l'application complète"
    echo "  restart   Redémarrer l'application complète"
    echo "  status    Afficher l'état des services"
    echo "  logs      Afficher les logs [backend|frontend|workers|cron|manager|all]"
    echo "  help      Afficher cette aide"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  -v, --verbose    Mode verbeux"
    echo "  -d, --dry-run    Simulation (ne pas exécuter les commandes)"
    echo ""
    echo -e "${BLUE}Exemples:${NC}"
    echo "  $0 start                 # Démarrer l'application"
    echo "  $0 stop                  # Arrêter l'application"
    echo "  $0 status                # Voir l'état"
    echo "  $0 logs backend          # Voir les logs du backend"
    echo "  $0 start --verbose       # Démarrer en mode verbeux"
}

# =============================================================================
# Point d'entrée principal
# =============================================================================

main() {
    # Traitement des options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            start|stop|restart|status|logs|help)
                COMMAND=$1
                shift
                break
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Vérifier qu'une commande a été fournie
    if [[ -z "${COMMAND:-}" ]]; then
        log "ERROR" "Aucune commande spécifiée"
        show_help
        exit 1
    fi
    
    # Initialiser le fichier de log
    echo "=== Specters Manager - $(date) ===" >> "$LOG_FILE"
    
    # Exécuter la commande
    case $COMMAND in
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$1"
            ;;
        help)
            show_help
            ;;
        *)
            log "ERROR" "Commande inconnue: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Gestion des signaux pour un arrêt propre
trap 'log "INFO" "Signal reçu, arrêt en cours..."; stop_all; exit 0' SIGINT SIGTERM

# Exécuter le script principal
main "$@"

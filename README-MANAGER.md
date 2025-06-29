# 🚀 Specters Manager - Guide d'utilisation

Script de démarrage et d'extinction complet pour l'application Specters.

## 📋 Prérequis

- **Node.js** >= 20.0.0
- **pnpm** (gestionnaire de paquets)
- **Docker** et **Docker Compose**
- **netcat** (nc) pour la vérification des ports

## 🎯 Utilisation rapide

```bash
# Démarrer l'application complète
./specters-manager.sh start

# Arrêter l'application complète
./specters-manager.sh stop

# Redémarrer l'application
./specters-manager.sh restart

# Voir l'état des services
./specters-manager.sh status

# Voir les logs
./specters-manager.sh logs
```

## 📖 Commandes détaillées

### Démarrage
```bash
./specters-manager.sh start [OPTIONS]
```
- Démarre les services Docker (PostgreSQL, Redis, PgAdmin, RedisInsight)
- Installe les dépendances avec pnpm
- Configure la base de données avec Prisma
- Démarre tous les services de l'application

### Arrêt
```bash
./specters-manager.sh stop [OPTIONS]
```
- Arrête gracieusement tous les processus Node.js
- Arrête les conteneurs Docker
- Nettoie les processus orphelins

### État des services
```bash
./specters-manager.sh status
```
Affiche :
- État des conteneurs Docker
- État des ports (3000, 4200, 5432, 6379, 8081, 5540)
- Processus actifs avec leurs PIDs

### Logs
```bash
./specters-manager.sh logs [SERVICE]
```
Services disponibles :
- `backend` - Logs du backend NestJS
- `frontend` - Logs du frontend Next.js
- `workers` - Logs des workers
- `cron` - Logs du service cron
- `manager` - Logs du gestionnaire
- `all` - Tous les logs (par défaut)

## ⚙️ Options

- `-v, --verbose` : Mode verbeux avec logs détaillés
- `-d, --dry-run` : Simulation sans exécution réelle
- `-h, --help` : Afficher l'aide

## 🌐 Services et ports

Une fois démarré, l'application sera disponible sur :

| Service | URL | Description |
|---------|-----|-------------|
| **Frontend** | http://localhost:4200 | Interface utilisateur principale |
| **Backend** | http://localhost:3000 | API REST |
| **PgAdmin** | http://localhost:8081 | Interface d'administration PostgreSQL |
| **RedisInsight** | http://localhost:5540 | Interface d'administration Redis |

### Identifiants PgAdmin
- **Email** : admin@admin.com
- **Mot de passe** : admin

## 📁 Structure des logs

Les logs sont stockés dans le dossier `logs/` :
```
logs/
├── backend.log     # Logs du backend
├── frontend.log    # Logs du frontend
├── workers.log     # Logs des workers
├── cron.log        # Logs du service cron
└── specters-manager.log  # Logs du gestionnaire
```

## 🔧 Fonctionnalités avancées

### Vérification automatique des prérequis
Le script vérifie automatiquement :
- Version de Node.js (>= 20.0.0)
- Présence de pnpm
- État de Docker
- Fichier .env (créé automatiquement depuis .env.example si absent)

### Gestion des PIDs
- Sauvegarde automatique des PIDs dans `.specters-pids`
- Arrêt gracieux avec SIGTERM puis SIGKILL si nécessaire
- Nettoyage des processus orphelins

### Attente des services
- Vérification que chaque service est opérationnel avant de continuer
- Timeout configurable pour chaque service
- Logs détaillés du processus de démarrage

## 🚨 Dépannage

### Ports déjà utilisés
Si des ports sont déjà utilisés, le script vous l'indiquera. Vous pouvez :
1. Arrêter les services qui utilisent ces ports
2. Modifier les ports dans les fichiers de configuration

### Services qui ne démarrent pas
1. Vérifiez les logs : `./specters-manager.sh logs [service]`
2. Vérifiez la configuration dans le fichier `.env`
3. Utilisez le mode verbeux : `./specters-manager.sh start --verbose`

### Problèmes Docker
1. Vérifiez que Docker est démarré : `docker info`
2. Vérifiez les permissions Docker
3. Redémarrez Docker si nécessaire

## 📝 Exemples d'utilisation

```bash
# Démarrage en mode verbeux
./specters-manager.sh start --verbose

# Simulation de démarrage (test)
./specters-manager.sh start --dry-run

# Voir les logs du backend en temps réel
./specters-manager.sh logs backend

# Redémarrage complet
./specters-manager.sh restart

# Vérifier l'état après démarrage
./specters-manager.sh status
```

## 🔄 Intégration avec les scripts existants

Le script est compatible avec les commandes pnpm existantes :
- `pnpm run dev` → `./specters-manager.sh start`
- `pnpm run dev:docker` → Inclus dans le démarrage
- Scripts PM2 → Remplacés par la gestion des PIDs

## 🛡️ Sécurité

- Arrêt propre avec gestion des signaux (Ctrl+C)
- Vérification des permissions avant exécution
- Logs détaillés pour audit
- Mode dry-run pour tester sans risque

---

**💡 Conseil** : Ajoutez un alias dans votre shell pour un accès rapide :
```bash
alias specters='./specters-manager.sh'
```

Puis utilisez simplement :
```bash
specters start
specters stop
specters status

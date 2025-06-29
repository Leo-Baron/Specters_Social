# Installation Node.js pour Specters

## ✅ Installation terminée

Node.js et pnpm ont été installés avec succès sur votre système :

- **Node.js** : v24.3.0
- **npm** : v11.4.2  
- **pnpm** : v10.6.1

## 🚀 Démarrage rapide

Pour démarrer l'application en mode développement, utilisez le script fourni :

```bash
./start-dev.sh
```

Ce script :
- Configure automatiquement le PATH pour Node.js et pnpm
- Vérifie que les outils sont disponibles
- Démarre l'application avec `pnpm run dev`

## 📋 Scripts disponibles

Vous pouvez également utiliser directement les commandes pnpm :

```bash
# Configuration du PATH (nécessaire à chaque session bash)
export PATH="/c/Program Files/nodejs:/c/Users/maiso/AppData/Roaming/npm:$PATH"

# Démarrage en mode développement (tous les services)
pnpm run dev

# Démarrage individuel des services
pnpm run dev:frontend    # Frontend Next.js
pnpm run dev:backend     # Backend NestJS
pnpm run dev:workers     # Workers
pnpm run dev:cron        # Tâches cron

# Build de production
pnpm run build

# Autres commandes utiles
pnpm install             # Installer les dépendances
pnpm run update-plugins  # Mettre à jour les plugins
```

## 🔧 Configuration permanente du PATH (optionnel)

Pour éviter de configurer le PATH à chaque session, vous pouvez l'ajouter de façon permanente :

### Option 1 : Fichier .bashrc
```bash
echo 'export PATH="/c/Program Files/nodejs:/c/Users/maiso/AppData/Roaming/npm:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Option 2 : Variables d'environnement Windows
1. Ouvrir les "Variables d'environnement système"
2. Ajouter à la variable PATH :
   - `C:\Program Files\nodejs`
   - `C:\Users\maiso\AppData\Roaming\npm`

## 📱 Services démarrés

Quand vous lancez `pnpm run dev`, les services suivants démarrent :

- **Frontend** : Interface utilisateur Next.js
- **Backend** : API NestJS  
- **Workers** : Processus en arrière-plan
- **Extension** : Extension navigateur

## ⚠️ Notes importantes

- Le projet utilise Node.js v24.3.0 mais recommande v20.x (warning normal)
- Certaines dépendances peuvent avoir des warnings de compatibilité (normal)
- Assurez-vous d'avoir configuré le fichier `.env` avant le premier démarrage

## 🆘 Dépannage

Si vous rencontrez des problèmes :

1. Vérifiez que Node.js est accessible :
   ```bash
   export PATH="/c/Program Files/nodejs:/c/Users/maiso/AppData/Roaming/npm:$PATH"
   node --version
   pnpm --version
   ```

2. Réinstallez les dépendances si nécessaire :
   ```bash
   rm -rf node_modules
   pnpm install
   ```

3. Utilisez le script `start-dev.sh` qui configure automatiquement l'environnement

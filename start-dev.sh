#!/bin/bash

# Script pour démarrer l'application Specters en mode développement
# Ce script configure automatiquement le PATH pour Node.js et pnpm

echo "🚀 Démarrage de l'application Specters..."
echo "📦 Configuration de l'environnement Node.js..."

# Configuration du PATH pour Node.js et pnpm
export PATH="/c/Program Files/nodejs:/c/Users/maiso/AppData/Roaming/npm:$PATH"

# Vérification que Node.js et pnpm sont disponibles
echo "🔍 Vérification des outils..."
node --version
pnpm --version

echo "🏗️  Démarrage de l'application en mode développement..."
echo "📱 Frontend, Backend, Workers et Extension vont démarrer en parallèle..."

# Démarrage de l'application
pnpm run dev

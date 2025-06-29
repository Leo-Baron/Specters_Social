# Scripts de Seed pour les Comptes de Test

Ce dossier contient les scripts pour créer des comptes de test dans la base de données.

## Script de Seed Principal

Le fichier `seed.ts` crée automatiquement :

- **Organisation de test** : "Test Organization"
- **Utilisateur de test** : Léo Baron
  - Email : `leovbaron@me.com`
  - Mot de passe : `test123`
  - Rôle : SUPERADMIN
  - Statut : Activé

## Comment exécuter le script

### Option 1 : Depuis la racine du projet
```bash
pnpm run prisma-seed
```

### Option 2 : Directement avec ts-node
```bash
cd libraries/nestjs-libraries/src/database/prisma
npx ts-node seed.ts
```

### Option 3 : Avec tsx (si installé)
```bash
cd libraries/nestjs-libraries/src/database/prisma
npx tsx seed.ts
```

## Prérequis

1. La base de données doit être configurée et accessible
2. Les variables d'environnement doivent être définies (DATABASE_URL, JWT_SECRET)
3. Le schéma Prisma doit être synchronisé avec la base de données

## Sécurité

⚠️ **Important** : Ce script est destiné uniquement au développement et aux tests. Ne jamais l'exécuter en production.

## Résolution des problèmes

Si vous rencontrez des erreurs :

1. Vérifiez que la base de données est accessible
2. Assurez-vous que les variables d'environnement sont correctement définies
3. Exécutez `pnpm run prisma-generate` pour régénérer le client Prisma
4. Vérifiez que le schéma est synchronisé avec `pnpm run prisma-db-push`

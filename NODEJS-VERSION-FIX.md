# Node.js Version Fix for Specters Application

## Problem
Your Specters application requires Node.js version 20.x.x, but you currently have Node.js v24.3.0 installed. This causes compatibility issues, particularly with the backend NestJS application.

## Current Status
✅ **Working Services:**
- Docker services (PostgreSQL, Redis, PgAdmin, RedisInsight)
- Frontend (http://localhost:4200) - **FULLY FUNCTIONAL**
- Database connections

❌ **Not Working:**
- Backend (crashes due to Node.js version incompatibility)

## Solution: Install Node.js 20.x.x

### Option 1: Using Node Version Manager (NVM) for Windows (Recommended)

1. **Download and Install NVM for Windows:**
   ```bash
   # Download from: https://github.com/coreybutler/nvm-windows/releases
   # Install nvm-setup.exe (latest version)
   ```

2. **Open a new Command Prompt or Git Bash as Administrator and run:**
   ```bash
   # Install Node.js 20.17.0 (recommended version)
   nvm install 20.17.0
   
   # Use Node.js 20.17.0
   nvm use 20.17.0
   
   # Verify the version
   node --version
   # Should show: v20.17.0
   ```

3. **Set as default:**
   ```bash
   nvm alias default 20.17.0
   ```

### Option 2: Direct Installation

1. **Download Node.js 20.x.x from official website:**
   - Go to: https://nodejs.org/en/download/
   - Download Node.js 20.x.x LTS version for Windows
   - Run the installer and follow the setup wizard

2. **Verify installation:**
   ```bash
   node --version
   # Should show: v20.x.x
   ```

## After Installing Node.js 20.x.x

1. **Restart your terminal/Git Bash**

2. **Verify pnpm is still working:**
   ```bash
   pnpm --version
   ```
   If pnpm is not found, reinstall it:
   ```bash
   npm install -g pnpm
   ```

3. **Start the application using the fixed script:**
   ```bash
   ./specters-manager-fixed.sh start
   ```

## Quick Test (Current Working State)

Even with the backend issue, you can test the frontend right now:

1. **Open your browser and go to:**
   ```
   http://localhost:4200
   ```

2. **Access the admin tools:**
   - PgAdmin: http://localhost:8081 (admin@admin.com / admin)
   - RedisInsight: http://localhost:5540

## Troubleshooting

### If you still get Node.js version warnings:
```bash
# Clear npm/pnpm cache
pnpm store prune
npm cache clean --force

# Reinstall dependencies
pnpm install
```

### If Prisma issues persist:
```bash
# Clean Prisma files
rm -rf node_modules/.prisma
pnpm run prisma-generate
```

### If backend still crashes:
```bash
# Check logs
cat logs/backend.log

# Try starting backend manually
pnpm run dev:backend
```

## Expected Result After Fix

After installing Node.js 20.x.x, all services should work:

✅ Frontend: http://localhost:4200
✅ Backend API: http://localhost:3000
✅ PgAdmin: http://localhost:8081
✅ RedisInsight: http://localhost:5540
✅ PostgreSQL: localhost:5432
✅ Redis: localhost:6379

## Alternative: Use Docker for Backend (Advanced)

If Node.js version issues persist, you can run the backend in Docker:

1. **Create a Dockerfile for backend:**
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm install -g pnpm
   RUN pnpm install
   COPY . .
   EXPOSE 3000
   CMD ["pnpm", "run", "dev:backend"]
   ```

2. **Add to docker-compose.dev.yaml:**
   ```yaml
   specters-backend:
     build: .
     ports:
       - "3000:3000"
     environment:
       - DATABASE_URL=postgresql://specters-local:specters-local-pwd@specters-postgres:5432/specters-db-local
       - REDIS_URL=redis://specters-redis:6379
     depends_on:
       - specters-postgres
       - specters-redis
     networks:
       - specters-network
   ```

## Summary

The main issue is Node.js version compatibility. The frontend is already working perfectly! Once you install Node.js 20.x.x, the backend should start without issues and you'll have a fully functional Specters application.

**Current working URL:** http://localhost:4200 (Frontend)
**After Node.js fix:** All services will be available

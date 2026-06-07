#!/bin/sh
set -e

echo "----------------------------------------"
echo " LokaGuide Backend - Starting up..."
echo "----------------------------------------"
echo "[1/2] Syncing database schema..."
npx prisma db push

echo "[2/2] Starting NestJS server..."
exec node dist/main
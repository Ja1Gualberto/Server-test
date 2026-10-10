#!/usr/bin/env bash
# Inicia os containers em segundo plano
docker compose up -d
echo "Servidores iniciados com sucesso!"
echo "Para ver os logs do Minecraft: ./logs.sh"
echo "Para vincular o Playit.gg: ./playit-claim.sh"

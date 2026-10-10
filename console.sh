#!/usr/bin/env bash
# Permite rodar comandos diretamente no console do Minecraft
# Exemplo de uso: ./console.sh "op MeuNome" ou sem argumentos para console interativo
if [ -z "$1" ]; then
    docker exec -it mc-otherworld rcon-cli 2>/dev/null || docker attach mc-otherworld
else
    docker exec -i mc-otherworld mc-send-to-console "$@" 2>/dev/null || docker exec -i mc-otherworld rcon-cli "$@"
fi

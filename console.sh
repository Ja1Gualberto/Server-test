#!/usr/bin/env bash
# Permite rodar comandos diretamente no console do Minecraft
# Exemplo de uso: ./console.sh "op MeuNome" ou sem argumentos para console interativo
if [ -z "$1" ]; then
    docker exec -it mc-otherworld rcon-cli
else
    docker exec -i mc-otherworld rcon-cli "$@"
fi

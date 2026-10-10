#!/usr/bin/env bash
# Mostra o link de vinculação do Playit.gg
echo "Buscando link de vinculação do Playit.gg..."
docker logs mc-playit 2>&1 | grep -E "https://playit.gg/claim/[a-zA-Z0-9]+" || docker logs mc-playit

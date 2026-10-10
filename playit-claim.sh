#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ -f .env ] && grep -q "PLAYIT_SECRET_KEY=" .env && [ -n "$(grep "PLAYIT_SECRET_KEY=" .env | cut -d= -f2-)" ]; then
    echo "=========================================================="
    echo "Playit.gg já está configurado no arquivo .env!"
    echo "=========================================================="
    echo "Verificando logs do container mc-playit..."
    docker logs mc-playit 2>&1 | tail -n 15
    exit 0
fi

echo "=========================================================="
echo "           VINCULAÇÃO DO PLAYIT.GG (TÚNEL PÚBLICO)        "
echo "=========================================================="
echo "Gerando link de vinculação exclusivo..."

CODE=$("$DIR/playit-cli" claim generate)
URL=$("$DIR/playit-cli" claim url "$CODE")

echo ""
echo "👉 Abra este link no seu navegador para vincular o servidor:"
echo "   $URL"
echo ""
echo "Aguardando você clicar em 'Claim' no site do Playit.gg..."

SECRET=$("$DIR/playit-cli" claim exchange "$CODE" | tail -n 1)

if [ -n "$SECRET" ]; then
    echo "PLAYIT_SECRET_KEY=$SECRET" > .env
    echo ""
    echo "✅ Vinculado com sucesso ao Playit.gg!"
    echo "Iniciando o container mc-playit..."
    docker compose up -d playit
    echo ""
    echo "Pronto! O túnel Playit.gg está rodando com sucesso."
    echo "Acesse o painel do Playit.gg (https://playit.gg) para gerenciar o túnel e ver seu IP/domínio."
else
    echo "Falha ao obter o segredo de autenticação. Tente rodar o script novamente."
fi

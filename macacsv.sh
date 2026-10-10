#!/usr/bin/env bash
# ==============================================================================
#                       M A C A C S V  -  W R A P P E R
# ==============================================================================
# Gerenciador e utilitário central para o servidor Minecraft: Otherworld [D&D]
# ==============================================================================

# ==============================================================================
# 🎨 ESCOLHA O ESTILO DO BANNER NO TOPO (1, 2 ou 3):
# ==============================================================================
BANNER_STYLE=1

# OPÇÃO 1 - Classic / Big
read -r -d '' BANNER_1 << 'EOF'
  __  __                       _____       
 |  \/  |                     / ____|      
 | \  / | __ _  ___ __ _  ___| (___  __   __
 | |\/| |/ _` |/ __/ _` |/ __|\___ \ \ \ / /
 | |  | | (_| | (_| (_| | (__ ____) | \ V / 
 |_|  |_|\__,_|\___\__,_|\___|_____/   \_/  
EOF

# OPÇÃO 2 - Slant / Modern
read -r -d '' BANNER_2 << 'EOF'
    __  ___                     ______     
   /  |/  /___ _____ ____ _____/ __/ | / / 
  / /|_/ / __ `/ __ `/ __ `/ __/\ \ | |/ /  
 /_/  /_/\__,_/\___/\__,_/\___/___/ |___/   
EOF

# OPÇÃO 3 - Cyber / Block / Minimalist
read -r -d '' BANNER_3 << 'EOF'
  █▀▄▀█ ▄▀█ █▀▀ ▄▀█ █▀▀ █▀ █░█
  █░▀░█ █▀█ █▄▄ █▀█ █▄▄ ▄█ ▀▄▀
EOF

# ==============================================================================
# Configurações de Ambiente e Cores
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Carrega variáveis do .env se existir
if [ -f .env ]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs -d '\n' 2>/dev/null || true)
fi

# Cores ANSI
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[36m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_PURPLE="\033[35m"

print_banner() {
    echo -e "${C_CYAN}${C_BOLD}"
    case "$BANNER_STYLE" in
        2) echo "$BANNER_2" ;;
        3) echo "$BANNER_3" ;;
        *) echo "$BANNER_1" ;;
    esac
    echo -e "${C_PURPLE}  ▶ Gerenciador Oficial do Servidor | Minecraft 1.20.1 Forge${C_RESET}\n"
}

# ==============================================================================
# 10 COMANDOS PRINCIPAIS
# ==============================================================================

cmd_start() {
    print_banner
    echo -e "${C_GREEN}🚀 Iniciando os containers do servidor...${C_RESET}"
    docker compose up -d
    echo -e "\n${C_GREEN}✔ Servidor e Túnel iniciados com sucesso!${C_RESET}"
    echo -e "Acompanhe a inicialização com: ${C_BOLD}./macacsv.sh logs${C_RESET}"
    echo -e "Para testar quando estiver pronto: ${C_BOLD}./macacsv.sh check${C_RESET}"
}

cmd_stop() {
    print_banner
    echo -e "${C_YELLOW}🛑 Parando o servidor e salvando o mundo...${C_RESET}"
    docker compose down
    echo -e "\n${C_GREEN}✔ Servidor desligado com segurança.${C_RESET}"
}

cmd_restart() {
    print_banner
    echo -e "${C_YELLOW}🔄 Reiniciando containers...${C_RESET}"
    docker compose restart
    echo -e "\n${C_GREEN}✔ Reinicialização concluída!${C_RESET}"
}

cmd_status() {
    print_banner
    echo -e "${C_BOLD}📊 Status dos Containers:${C_RESET}"
    docker compose ps
    echo ""
    echo -e "${C_BOLD}💾 Consumo de Memória (RAM) e CPU:${C_RESET}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" mc-otherworld mc-playit 2>/dev/null || true
    echo ""
    echo -e "${C_BOLD}🌐 Túnel Playit.gg:${C_RESET}"
    if docker ps --format '{{.Names}}' | grep -q '^mc-playit$'; then
        echo -e "${C_GREEN}✔ Container mc-playit está online e conectado.${C_RESET}"
        if [ -n "$PLAYIT_DOMAIN" ]; then
            echo -e "  Endereço público: ${C_CYAN}${C_BOLD}$PLAYIT_DOMAIN${C_RESET}"
        fi
    else
        echo -e "${C_RED}✖ Container mc-playit está parado.${C_RESET}"
    fi
}

cmd_check() {
    print_banner
    echo -e "${C_BOLD}🔍 DIAGNÓSTICO DO SERVIDOR (STATUS & CONECTIVIDADE):${C_RESET}\n"

    ERRORS=0

    # 1. Checa container Minecraft
    echo -n "  1. Container Minecraft (mc-otherworld): "
    if docker ps --format '{{.Names}}' | grep -q '^mc-otherworld$'; then
        echo -e "${C_GREEN}✔ Em execução${C_RESET}"
    else
        echo -e "${C_RED}✖ Parado ou não iniciado${C_RESET}"
        ERRORS=$((ERRORS + 1))
    fi

    # 2. Checa porta TCP 25565 e latência
    echo -n "  2. Porta do Jogo (TCP 25565): "
    PING_RES=$(python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2.0)
start = time.time()
res = s.connect_ex(('127.0.0.1', 25565))
lat = (time.time() - start) * 1000
s.close()
if res == 0:
    print(f'OK:{lat:.1f}')
else:
    print('FAIL')
" 2>/dev/null || echo "FAIL")

    if [[ "$PING_RES" == OK* ]]; then
        LAT=$(echo "$PING_RES" | cut -d: -f2)
        echo -e "${C_GREEN}✔ Aberta e respondendo (${LAT}ms)${C_RESET}"
    else
        echo -e "${C_RED}✖ Não está aceitando conexões${C_RESET}"
        ERRORS=$((ERRORS + 1))
    fi

    # 3. Consulta RCON para verificar se o Forge está responsivo
    echo -n "  3. Resposta do Forge (RCON): "
    PLAYER_LIST=$(docker exec -i mc-otherworld rcon-cli list 2>/dev/null || true)
    if [ -n "$PLAYER_LIST" ]; then
        echo -e "${C_GREEN}✔ Ativo e responsivo${C_RESET}"
        echo -e "     ${C_CYAN}↳ $PLAYER_LIST${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Sem resposta do RCON (pode estar iniciando ou congelado)${C_RESET}"
    fi

    # 4. Checa container do Playit
    echo -n "  4. Agente do Túnel (mc-playit): "
    if docker ps --format '{{.Names}}' | grep -q '^mc-playit$'; then
        echo -e "${C_GREEN}✔ Conectado ao Playit.gg${C_RESET}"
    else
        echo -e "${C_RED}✖ Parado${C_RESET}"
        ERRORS=$((ERRORS + 1))
    fi

    # 5. Checa resolução do domínio público
    DOMAIN="${PLAYIT_DOMAIN:-}"
    if [ -n "$DOMAIN" ]; then
        echo -n "  5. Túnel Público ($DOMAIN): "
        RESOLV=$(python3 -c "
import socket
try:
    ip = socket.gethostbyname('$DOMAIN')
    print('OK:' + ip)
except:
    print('FAIL')
" 2>/dev/null || echo "FAIL")
        if [[ "$RESOLV" == OK* ]]; then
            PUB_IP=$(echo "$RESOLV" | cut -d: -f2)
            echo -e "${C_GREEN}✔ Online na Internet (IP: $PUB_IP)${C_RESET}"
        else
            echo -e "${C_YELLOW}⚠ Domínio não resolveu DNS ainda${C_RESET}"
        fi
    fi

    echo ""
    if [ "$ERRORS" -eq 0 ]; then
        echo -e "  ${C_GREEN}${C_BOLD}✨ RESULTADO: O SERVIDOR ESTÁ 100% ATIVO E PRONTO PARA JOGAR!${C_RESET}\n"
    else
        echo -e "  ${C_RED}${C_BOLD}⚠ RESULTADO: O SERVIDOR ENCONTROU $ERRORS PROBLEMA(S).${C_RESET}\n"
        echo -e "  Dica: Execute ${C_BOLD}./macacsv.sh logs${C_RESET} para diagnosticar."
    fi
}

cmd_link() {
    print_banner
    echo -e "${C_BOLD}🌐 ENDEREÇO DE CONEXÃO DO SERVIDOR:${C_RESET}\n"

    DOMAIN="${PLAYIT_DOMAIN:-}"
    PORT="${PLAYIT_PORT:-}"

    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(python3 -c "
import subprocess, re, binascii
logs = subprocess.run(['docker', 'logs', 'mc-playit'], capture_output=True, text=True).stderr
hex_matches = re.findall(r'[0-9a-f]{20,}', logs)
for h in hex_matches:
    try:
        raw = binascii.unhexlify(h)
        m = re.search(rb'[a-zA-Z0-9.-]+\.(?:ply\.gg|joinmc\.link)', raw)
        if m:
            print(m.group(0).decode())
            break
    except: pass
" 2>/dev/null || true)
    fi

    if [ -n "$DOMAIN" ]; then
        echo -e "  ${C_GREEN}${C_BOLD}▶ Para seus amigos (Endereço Público):${C_RESET}"
        echo -e "    ${C_CYAN}${C_BOLD}$DOMAIN${C_RESET}"
        if [ -n "$PORT" ]; then
            echo -e "    ${C_YELLOW}(ou com porta explícita: $DOMAIN:$PORT)${C_RESET}"
        fi
        echo ""
        echo -e "  ${C_PURPLE}${C_BOLD}▶ Para você (se jogar no mesmo PC):${C_RESET}"
        echo -e "    ${C_CYAN}localhost:25565${C_RESET}"
        echo ""
        echo -e "  ${C_BOLD}Dica:${C_RESET} No Minecraft, vá em Multijogador > Adicionar Servidor e cole o endereço público acima!"
    else
        echo -e "${C_YELLOW}⚠ Endereço ainda não detectado.${C_RESET}"
        echo -e "Verifique se o túnel está ativo em: ${C_BOLD}https://playit.gg/account/agents${C_RESET}"
    fi
    echo ""
}

cmd_logs() {
    TARGET="${1:-minecraft}"
    if [ "$TARGET" = "playit" ]; then
        echo -e "${C_CYAN}📋 Acompanhando logs do Playit.gg (Ctrl+C para sair):${C_RESET}"
        docker logs -f mc-playit
    else
        echo -e "${C_CYAN}📋 Acompanhando logs do Minecraft (Ctrl+C para sair):${C_RESET}"
        docker logs -f mc-otherworld
    fi
}

cmd_console() {
    if [ -z "$1" ]; then
        print_banner
        echo -e "${C_YELLOW}Abrindo console interativo do Minecraft (digite 'exit' para sair)...${C_RESET}"
        docker exec -it mc-otherworld rcon-cli 2>/dev/null || docker attach mc-otherworld
    else
        echo -e "${C_CYAN}Enviando comando para o servidor: ${C_BOLD}$*${C_RESET}"
        docker exec -i mc-otherworld rcon-cli "$@" 2>/dev/null || docker exec -u 1000 -i mc-otherworld mc-send-to-console "$@"
    fi
}

cmd_backup() {
    print_banner
    mkdir -p "$DIR/backups"
    BACKUP_NAME="backup_world_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${C_YELLOW}📦 Solicitando salvamento do mundo no Minecraft...${C_RESET}"
    docker exec -i mc-otherworld rcon-cli "save-all" 2>/dev/null || true
    sleep 2
    echo -e "${C_CYAN}Compactando pasta data/world em backups/$BACKUP_NAME...${C_RESET}"
    tar -czf "$DIR/backups/$BACKUP_NAME" -C "$DIR/data" world
    echo -e "${C_GREEN}✔ Backup criado com sucesso!${C_RESET}"
    echo -e "Arquivo: ${C_BOLD}$DIR/backups/$BACKUP_NAME${C_RESET} ($(du -h "$DIR/backups/$BACKUP_NAME" | cut -f1))"
}

cmd_setup() {
    print_banner
    echo -e "${C_BOLD}🛠️ Validação e Instalação de Dependências:${C_RESET}\n"
    
    # 1. Checa Docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${C_GREEN}✔ Docker detectado:${C_RESET} $(docker --version)"
    else
        echo -e "${C_RED}✖ Docker não instalado!${C_RESET}"
        if command -v pacman >/dev/null 2>&1; then
            echo -e "Instalando via pacman..."
            sudo pacman -S --needed docker docker-compose
        else
            echo "Por favor, instale o Docker para o seu sistema."
            exit 1
        fi
    fi

    # 2. Checa serviço do Docker
    if systemctl is-active --quiet docker; then
        echo -e "${C_GREEN}✔ Serviço Docker está em execução.${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Iniciando serviço Docker...${C_RESET}"
        sudo systemctl enable --now docker
    fi

    # 3. Permissões de grupo
    if groups | grep -q docker; then
        echo -e "${C_GREEN}✔ Usuário atual possui permissão no grupo docker.${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Adicionando usuário ao grupo docker...${C_RESET}"
        sudo usermod -aG docker "$USER"
        echo -e "Execute ${C_BOLD}newgrp docker${C_RESET} para aplicar as permissões."
    fi

    # 4. Checa configuração do Playit
    if [ -f .env ] && grep -q "PLAYIT_SECRET_KEY=" .env; then
        echo -e "${C_GREEN}✔ Chave do Playit.gg configurada no arquivo .env.${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠ Playit não vinculado. Iniciando assistente...${C_RESET}"
        ./playit-claim.sh
    fi

    echo -e "\n${C_GREEN}✔ Ambiente pronto para uso!${C_RESET}"
}

cmd_help() {
    print_banner
    echo -e "${C_BOLD}Uso:${C_RESET} ./macacsv.sh ${C_CYAN}<comando>${C_RESET} [argumentos]\n"
    echo -e "${C_BOLD}Comandos Disponíveis (Menu dos 10 Principais):${C_RESET}"
    echo -e "  ${C_CYAN}1. start${C_RESET}              Inicia os containers do Minecraft e do Playit"
    echo -e "  ${C_CYAN}2. stop${C_RESET}               Para o servidor com segurança (salva chunks e mundo)"
    echo -e "  ${C_CYAN}3. restart${C_RESET}            Reinicia os serviços"
    echo -e "  ${C_CYAN}4. status${C_RESET}             Exibe saúde, containers ativos e consumo de RAM/CPU"
    echo -e "  ${C_CYAN}5. check${C_RESET}              Diagnóstico completo: testa se o server está ativo e sem travar"
    echo -e "  ${C_CYAN}6. link${C_RESET}               Mostra o endereço público (IP/domínio) para amigos entrarem"
    echo -e "  ${C_CYAN}7. logs [alvo]${C_RESET}        Acompanha logs ao vivo (padrão: minecraft; ou: playit)"
    echo -e "  ${C_CYAN}8. console <cmd>${C_RESET}      Envia comandos ao console (ex: console \"op MeuNick\")"
    echo -e "  ${C_CYAN}9. backup${C_RESET}             Gera backup compactado (.tar.gz) da pasta world"
    echo -e "  ${C_CYAN}10. setup${C_RESET}             Verifica/instala dependências (Docker, permissões)"
    echo ""
    echo -e "${C_BOLD}Atalhos Úteis:${C_RESET}"
    echo -e "  ${C_CYAN}./macacsv ip${C_RESET}          Atalho para './macacsv link'"
    echo -e "  ${C_CYAN}./macacsv ping${C_RESET}        Atalho para './macacsv check'"
    echo ""
}

# ==============================================================================
# Roteamento dos Comandos
# ==============================================================================
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    start)              cmd_start "$@" ;;
    stop)               cmd_stop "$@" ;;
    restart)            cmd_restart "$@" ;;
    status)             cmd_status "$@" ;;
    check|ping|health)  cmd_check "$@" ;;
    link|ip|playit)     cmd_link "$@" ;;
    logs)               cmd_logs "$@" ;;
    console)            cmd_console "$@" ;;
    backup)             cmd_backup "$@" ;;
    setup)              cmd_setup "$@" ;;
    help|--help|-h)     cmd_help ;;
    *)
        echo -e "${C_RED}Comando desconhecido: '$COMMAND'${C_RESET}"
        echo -e "Execute ${C_BOLD}./macacsv.sh help${C_RESET} para ver a lista de comandos."
        exit 1
        ;;
esac

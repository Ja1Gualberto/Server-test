# ⚔️ Servidor Minecraft: Otherworld [D&D] (Forge 1.20.1)

Ambiente isolado, seguro e automatizado em contêineres Docker para hospedar o modpack **Otherworld [D&D]**, integrado com túnel público **Playit.gg** e sistema de autenticação local **LTS Auth**.

---

## 📌 Sumário
- [Arquitetura Geral](#-arquitetura-geral)
- [Estrutura de Arquivos](#-estrutura-de-arquivos)
- [Como Funciona](#-como-funciona)
- [Como Rodar o Servidor](#-como-rodar-o-servidor)
- [Guia de Manutenção](#-guia-de-manutenção)
  - [Rotina de Backups](#1-rotina-de-backups)
  - [Ajuste de Memória RAM](#2-ajuste-de-memória-ram)
  - [Atualização ou Remoção de Mods](#3-atualização-ou-remoção-de-mods)
  - [Resolução de Problemas (Troubleshooting)](#4-resolução-de-problemas-troubleshooting)
- [Segurança & Login (LTS Auth)](#-segurança--login-lts-auth)
- [Conexão e Túnel (Playit.gg)](#-conexão-e-túnel-playitgg)

---

## 🏗️ Arquitetura Geral

O servidor é orquestrado via **Docker Compose** e composto por dois serviços desacoplados:

```
                  +----------------------------------------------+
                  |                 INTERNET                     |
                  +----------------------+-----------------------+
                                         |
                                         v
                         +-------------------------------+
                         |   Túnel Anycast Playit.gg     |
                         |   (ex: seunome.gl.joinmc.link)|
                         +---------------+---------------+
                                         |
   [Máquina Host (CachyOS)]              v
  +--------------------------------------------------------------+
  |  Container 1: mc-playit (Agent)                              |
  |  - Roda em network_mode: "host"                              |
  |  - Redireciona tráfego UDP/TCP para 127.0.0.1:25565          |
  +--------------------------------------+-----------------------+
                                         |
                                         v
  +--------------------------------------------------------------+
  |  Container 2: mc-otherworld (Minecraft)                      |
  |  - Imagem: itzg/minecraft-server:java17                     |
  |  - Forge: 47.4.20 | Minecraft: 1.20.1                        |
  |  - Memória: 8GB com Aikar's Flags otimizadas                 |
  |  - Volume: ./data (persistência total de mundo, mods e logs) |
  +--------------------------------------------------------------+
```

---

## 📂 Estrutura de Arquivos

```
Server-test/
├── docker-compose.yml   # Definição dos containers, portas, limites e variáveis
├── .env                 # Armazena segredos (ex: PLAYIT_SECRET_KEY) [NÃO commitar]
├── .gitignore           # Evita versionar o mundo, mods e segredos
├── start.sh             # Script para ligar os containers
├── stop.sh              # Script para encerrar o servidor salvando o mundo
├── logs.sh              # Acompanhamento do console em tempo real
├── console.sh           # Envio de comandos para o servidor (ex: op, whitelist)
├── playit-claim.sh      # Assistente de geração e vinculação do túnel Playit
├── playit-cli           # Utilitário CLI do Playit para geração de tokens
├── playit_data/         # Cache e configurações locais do Playit
└── data/                # Volume persistente do Minecraft
    ├── world/           # Arquivos do mapa gerado
    ├── mods/            # Arquivos .jar de todos os mods (+ LTS Auth)
    ├── config/          # Configurações individuais de cada mod
    ├── defaultconfigs/  # Configurações padrão carregadas no mundo
    ├── logs/            # Histórico de logs (latest.log, debug.log)
    └── server.properties# Propriedades centrais do servidor
```

---

## ⚙️ Como Funciona

1. **Ciclo de Inicialização**:
   - Ao executar `./start.sh`, o Docker Compose inicializa a imagem `itzg/minecraft-server:java17`.
   - O contêiner verifica se a versão do Forge (`47.4.20`) está instalada em `data/libraries`. Caso positivo, ele pula a instalação e executa imediatamente o `run.sh` com o Java 17.
   - Aplica as flags do **Aikar** (`USE_AIKAR_FLAGS=TRUE`), garantindo gerenciamento de lixo (G1GC) otimizado para servidores modded pesados.
   - O contêiner `mc-playit` se conecta aos nós globais da rede Playit.gg usando a chave salva em `.env` e direciona os jogadores diretamente para a porta 25565.

2. **Persistência de Dados**:
   - Tudo o que acontece dentro do jogo é gravado na pasta `./data` da sua máquina host. Mesmo se o container for recriado, atualizado ou excluído, nenhum progresso do mapa, itens ou baús é perdido.

3. **Modo Offline & LTS Auth**:
   - O servidor opera com `online-mode=false` para que amigos com qualquer launcher possam jogar juntos.
   - Para impedir que alguém use o nickname de outro jogador ou de um administrador, o mod **LTS Auth** intercepta a conexão e congela o jogador até que ele forneça sua senha registrada.

---

## 🚀 Como Rodar o Servidor

### Iniciar
```bash
./start.sh
```
Inicia ambos os serviços em segundo plano.

### Ver Logs (Console em tempo real)
```bash
./logs.sh
```
*Dica: Pressione `Ctrl + C` para sair do monitoramento sem desligar o servidor.*

### Enviar Comandos para o Console
```bash
# Dar permissão de Admin (OP)
./console.sh "op SeuNick"

# Ver jogadores conectados
./console.sh "list"

# Mudar clima ou horário
./console.sh "weather clear"
./console.sh "time set day"
```

### Parar o Servidor
```bash
./stop.sh
```
*O Docker Compose concede até 60 segundos de tolerância (`stop_grace_period: 60s`) para o Forge salvar todos os chunks e descarregar o mundo sem risco de corrupção.*

---

## 🛠️ Guia de Manutenção

### 1. Rotina de Backups

Recomenda-se realizar backups periódicos da pasta `world` (ou de toda a pasta `data`). 

Para criar um backup compactado rapidamente:
```bash
# Pare o servidor ou avise no console para salvar com "./console.sh save-all"
tar -czvf "backup-$(date +%Y%m%d_%H%M%S).tar.gz" data/world
```

### 2. Ajuste de Memória RAM

Se você notar travamentos por falta de memória ou se tiver mais memória disponível, você pode editar a variável `MEMORY` no [`docker-compose.yml`](docker-compose.yml):

```yaml
    environment:
      MEMORY: "10G" # Altere de 8G para o valor desejado
```
Em seguida, aplique a alteração:
```bash
docker compose up -d
```

### 3. Atualização ou Remoção de Mods

- **Adicionar mod**: Baixe o arquivo `.jar` compatível com **Forge 1.20.1** e coloque em [`data/mods/`](data/mods/).
- **Remover mod**: Remova ou renomeie a extensão do arquivo (ex: `mod.jar.disabled`).
- Após alterações em mods, reinicie o container:
  ```bash
  docker compose restart minecraft
  ```

### 4. Resolução de Problemas (Troubleshooting)

- **O servidor não inicia ou dá Crash**:
  - Verifique os relatórios de erro mais recentes em:
    ```bash
    cat data/crash-reports/crash-*.txt | tail -n 50
    ```
  - Verifique o log detalhado:
    ```bash
    tail -n 100 data/logs/latest.log
    ```

- **Amigos não conseguem conectar pelo Playit**:
  - Verifique o status do container:
    ```bash
    docker logs mc-playit
    ```
  - Se disser `email_not_verified`, valide seu e-mail no painel do [Playit.gg](https://playit.gg).
  - Confirme se o túnel criado no site aponta para **Minecraft Java** na porta local **25565**.

- **Problema de permissão de arquivos**:
  - Caso modifique arquivos manualmente e o Docker reclame de permissão:
    ```bash
    chmod -R u+rwX data/
    ```

---

## 🔐 Segurança & Login (LTS Auth)

| Comando | Descrição |
| :--- | :--- |
| `/register <senha> <senha>` | Cadastra a senha na primeira vez que o jogador entra. |
| `/login <senha>` | Autentica o jogador nas próximas sessões. |
| `/changepassword <antiga> <nova>` | Permite ao jogador alterar sua própria senha. |

*Configurações avançadas do mod podem ser ajustadas em `data/config/lts_auth.json` (tempo de timeout de login, restrição de movimentação, etc.).*

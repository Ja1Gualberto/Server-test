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

3. **Modo Offline & AuthMod**:
   - O servidor opera com `online-mode=false` para que amigos com qualquer launcher possam jogar juntos.
   - Para impedir roubo de contas ou privilégios de administrador, o **AuthMod** congela o jogador em modo espectador até que ele forneça sua senha registrada.

---

## 🚀 Como Rodar e Gerenciar (Wrapper MacacSv)

O projeto conta com o wrapper executável [`./macacsv.sh`](macacsv.sh) (ou simplesmente `./macacsv`) com os 10 comandos essenciais:

```bash
./macacsv.sh <comando>
```

| # | Comando | Atalho | Descrição |
| :-: | :--- | :--- | :--- |
| 1 | `./macacsv.sh start` | - | Inicia o Minecraft e o Playit em segundo plano. |
| 2 | `./macacsv.sh stop` | - | Para os containers salvando todos os chunks com segurança. |
| 3 | `./macacsv.sh restart` | - | Reinicia ambos os serviços. |
| 4 | `./macacsv.sh status` | - | Exibe saúde dos containers, portas, consumo de RAM e CPU. |
| 5 | `./macacsv.sh check` | `./macacsv ping` | **Diagnóstico completo**: testa porta TCP 25565, latência, RCON e se o Forge está travado. |
| 6 | `./macacsv.sh link` | `./macacsv ip` | **Endereço do Servidor**: exibe o domínio público para amigos e local para você. |
| 7 | `./macacsv.sh logs` | - | Acompanha logs do Minecraft ao vivo (`logs playit` para o túnel). |
| 8 | `./macacsv.sh console <cmd>` | - | Envia comandos ao console (ex: `./macacsv console "op SeuNick"`). |
| 9 | `./macacsv.sh backup` | - | Gera um arquivo compactado `.tar.gz` do mundo com data/hora em `backups/`. |
| 10 | `./macacsv.sh setup` | - | Valida e instala dependências de sistema (Docker, grupo, túnel). |

> [!TIP]
> Você pode alterar entre as **3 opções de arte ASCII** do banner no topo editando a variável `BANNER_STYLE=1` (1, 2 ou 3) na linha 10 do [`macacsv.sh`](macacsv.sh).


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

## 🔐 Segurança & Login (AuthMod)

O servidor utiliza o **AuthMod (ForgeGuardAuth)** para proteger contas com criptografia PBKDF2:

- **Trava Total**: Ao entrar, o jogador fica congelado em modo Espectador (não anda, não pula, não quebra blocos, não abre baús e não toma dano).
- **Sem Kick por Tempo**: O jogador não é expulso por demorar para digitar a senha.
- **Proteção contra Força Bruta**: Bloqueio temporário se errar a senha repetidamente.

### Comandos para Jogadores:
| Comando | Descrição |
| :--- | :--- |
| `/register <senha>` | Cadastra a senha na primeira vez que o jogador entra. |
| `/login <senha>` | Autentica o jogador nas próximas sessões. |
| `/changepassword <antiga> <nova>` | Altera a própria senha. |

### Comandos Administrativos (Console ou OP):
| Comando | Descrição |
| :--- | :--- |
| `./console.sh "authmod changepassword <jogador> <novaSenha>"` | Redefine a senha de um jogador (mesmo offline). |
| `./console.sh "authmod resetpassword <jogador>"` | Deleta o registro do jogador para que ele cadastre uma nova. |

### Configuração do Mod:
O arquivo de configuração fica localizado em:
`data/world/serverconfig/authmod-server.toml`

```toml
[auth]
    minPasswordLength = 6        # Tamanho mínimo da senha (4 a 64)
    maxLoginAttempts = 3         # Tentativas antes de bloquear temporariamente
    lockoutSeconds = 60          # Tempo de bloqueio em segundos
    language = "auto"           # Idioma automático ou "en"/"ru"
```

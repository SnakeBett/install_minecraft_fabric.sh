#!/bin/bash

# Cores aprimoradas
COLOR_RESET='\033[0m'
COLOR_RED='\033[1;91m'
COLOR_GREEN='\033[1;92m'
COLOR_YELLOW='\033[1;93m'
COLOR_BLUE='\033[1;94m'
COLOR_CYAN='\033[1;96m'
COLOR_WHITE='\033[1;97m'
COLOR_MAGENTA='\033[1;95m'

# Elementos visuais
SEPARATOR="================================================="
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"
ARROW="\xBB"

# Exibir cabeçalho
show_header() {
    clear
    echo -e "${COLOR_MAGENTA}"
    echo " Fabric Minecraft Server Installer "
    echo -e "${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${SEPARATOR}${COLOR_RESET}"
}

# Exibir mensagens
show_error() { echo -e "${COLOR_RED}${CROSS} Erro: $1${COLOR_RESET}" >&2; }
show_success() { echo -e "${COLOR_GREEN}${TICK} $1${COLOR_RESET}"; }
show_info() { echo -e "${COLOR_BLUE}${ARROW} $1${COLOR_RESET}"; }

# Verificar dependências
check_dependencies() {
    local packages=("curl" "wget" "jq" "openjdk-17-jre" "iproute2" "screen")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            show_info "Instalando dependência: $pkg..."
            if ! apt-get install -y "$pkg"; then
                show_error "Falha ao instalar $pkg"
                exit 1
            fi
        fi
    done
}

# Obter IP do servidor
get_server_ip() {
    hostname -I | awk '{print $1}'
}

# Obter versões mais recentes
get_latest_versions() {
    show_info "Obtendo versões mais recentes..."
    MC_LATEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')
    FABRIC_LATEST=$(curl -s https://meta.fabricmc.net/v2/versions/loader | jq -r '.[0].version')
    FABRIC_INSTALLER_URL=$(curl -s https://meta.fabricmc.net/v2/versions/installer | jq -r '.[0].url')
}

# Instalar servidor
install_server() {
    show_header
    get_latest_versions

    echo -e "${COLOR_CYAN}${SEPARATOR}"
    echo -e " Versões Recomendadas:"
    echo -e " • Minecraft: ${MC_LATEST}"
    echo -e " • Fabric Loader: ${FABRIC_LATEST}"
    echo -e "${SEPARATOR}${COLOR_RESET}\n"

    read -p "Nome do Servidor: " SERVER_NAME
    read -p "Mensagem do Servidor (MOTD): " SERVER_MOTD
    read -p "Dificuldade (peaceful, easy, normal, hard): " SERVER_DIFFICULTY
    read -p "Modo do servidor (survival, creative, adventure, spectator): " SERVER_GAMEMODE
    read -p "Online Mode (true para original, false para pirata): " ONLINE_MODE
    read -p "Versão do Minecraft (Enter para ${MC_LATEST}): " MC_VERSION
    MC_VERSION=${MC_VERSION:-$MC_LATEST}
    read -p "Quantidade de RAM para alocar (GB): " RAM_GB

    # Criar diretório do servidor
    SERVER_DIR="${HOME}/${SERVER_NAME}"
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit

    show_info "Baixando o servidor oficial do Minecraft..."
    wget -q "https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar" -O server.jar

    show_info "Baixando o instalador do Fabric..."
    wget -O fabric-installer.jar "$FABRIC_INSTALLER_URL"

    show_info "Executando o instalador do Fabric..."
    java -jar fabric-installer.jar server -mcversion "$MC_VERSION" -downloadMinecraft -dir "$SERVER_DIR"

    if [ ! -f "fabric-server-launch.jar" ]; then
        show_error "Falha ao instalar o Fabric! Verifique se a versão do Minecraft está correta."
        exit 1
    fi

    show_info "Aceitando os termos do Minecraft (EULA)..."
    echo "eula=true" > eula.txt

    show_info "Criando arquivo server.properties..."
    cat <<EOF > server.properties
#Minecraft server properties
#$(date)
allow-flight=true
allow-nether=true
broadcast-console-to-ops=true
broadcast-rcon-to-ops=true
difficulty=${SERVER_DIFFICULTY}
enable-command-block=true
enable-jmx-monitoring=false
enable-query=false
enable-rcon=false
enable-status=true
enforce-whitelist=true
entity-broadcast-range-percentage=100
force-gamemode=false
function-permission-level=2
gamemode=${SERVER_GAMEMODE}
generate-structures=true
generator-settings=
hardcore=false
level-name=world
level-seed=
level-type=default
max-build-height=256
max-players=10
max-tick-time=120000
max-world-size=29999984
motd=${SERVER_MOTD}
network-compression-threshold=256
online-mode=${ONLINE_MODE}
op-permission-level=4
player-idle-timeout=0
prevent-proxy-connections=false
pvp=true
query.port=25565
rate-limit=0
rcon.password=
rcon.port=25575
resource-pack=
resource-pack-sha1=
server-ip=
server-port=25565
snooper-enabled=false
spawn-animals=true
spawn-monsters=true
spawn-npcs=true
spawn-protection=16
sync-chunk-writes=true
text-filtering-config=
use-native-transport=true
view-distance=10
white-list=false
EOF

    show_info "Criando script de inicialização..."
    cat <<EOF > start.sh
#!/bin/bash
java -Xmx${RAM_GB}G -Xms2G -jar fabric-server-launch.jar nogui
EOF

    chmod +x start.sh

    show_success "Instalação concluída!"

    SERVER_IP=$(get_server_ip)
    SERVER_PORT=25565
    echo -e "\n${COLOR_GREEN}Salve o IP e porta do servidor:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}IP: ${SERVER_IP}\nPorta: ${SERVER_PORT}${COLOR_RESET}"
    
    show_info "Para iniciar o servidor e mantê-lo rodando, use os seguintes comandos:"
    echo -e "${COLOR_CYAN}1. Criar e entrar na sessão do servidor: screen -S minecraft${COLOR_RESET}"
    echo -e "${COLOR_CYAN}2. Iniciar o servidor dentro do screen: ./start.sh${COLOR_RESET}"
    echo -e "${COLOR_CYAN}3. Para sair do screen sem encerrar o servidor: Pressione CTRL + A, depois D${COLOR_RESET}"
    echo -e "${COLOR_CYAN}4. Para voltar ao servidor: screen -r minecraft${COLOR_RESET}"
}

# Iniciar
main() {
    trap 'show_error "Instalação cancelada pelo usuário!"; exit 1' INT
    check_dependencies
    install_server
}

main

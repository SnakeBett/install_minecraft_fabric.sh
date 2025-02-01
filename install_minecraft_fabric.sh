#!/bin/bash

# Cores aprimoradas
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[1;92m'
COLOR_BLUE='\033[1;94m'
COLOR_CYAN='\033[1;96m'
COLOR_MAGENTA='\033[1;95m'

# Elementos visuais
SEPARATOR="================================================="
TICK="\xE2\x9C\x85"
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
show_success() { echo -e "${COLOR_GREEN}${TICK} $1${COLOR_RESET}"; }
show_info() { echo -e "${COLOR_BLUE}${ARROW} $1${COLOR_RESET}"; }

# Verificar e instalar dependências
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

# Obter versões mais recentes
get_latest_versions() {
    show_info "Obtendo versões mais recentes..."
    MC_LATEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')
    FABRIC_LATEST=$(curl -s https://meta.fabricmc.net/v2/versions/loader | jq -r '.[0].version')
    FABRIC_INSTALLER_URL=$(curl -s https://meta.fabricmc.net/v2/versions/installer | jq -r '.[0].url')
}

# Criar alias para iniciar o servidor com 'start'
setup_alias() {
    ALIAS_CMD="alias start='cd /minecraft && ./start.sh'"
    if ! grep -Fxq "$ALIAS_CMD" ~/.bashrc; then
        echo "$ALIAS_CMD" >> ~/.bashrc
        source ~/.bashrc
    fi
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

    read -p "Nome do Servidor (MOTD): " SERVER_MOTD
    read -p "Dificuldade (peaceful, easy, normal, hard) [default: normal]: " SERVER_DIFFICULTY
    SERVER_DIFFICULTY=${SERVER_DIFFICULTY:-normal}
    read -p "Versão do Minecraft (Enter para ${MC_LATEST}): " MC_VERSION
    MC_VERSION=${MC_VERSION:-$MC_LATEST}
    read -p "Versão do Fabric (Enter para ${FABRIC_LATEST}): " FABRIC_VERSION
    FABRIC_VERSION=${FABRIC_VERSION:-$FABRIC_LATEST}
    read -p "Porta do Servidor (Enter para 25565): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-25565}
    read -p "Quantidade de RAM para alocar (GB): " RAM_GB

    # Criar diretório do servidor em /minecraft
    SERVER_DIR="/minecraft"
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit

    show_info "Baixando o servidor oficial do Minecraft..."
    wget -q "https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar" -O server.jar

    show_info "Baixando o instalador do Fabric..."
    wget -O fabric-installer.jar "$FABRIC_INSTALLER_URL"

    show_info "Executando o instalador do Fabric..."
    java -jar fabric-installer.jar server -mcversion "$MC_VERSION" -loader "$FABRIC_VERSION" -downloadMinecraft -dir "$SERVER_DIR"

    if [ ! -f "fabric-server-launch.jar" ]; then
        show_error "Falha ao instalar o Fabric! Verifique se a versão do Minecraft e Fabric está correta."
        exit 1
    fi

    show_info "Aceitando os termos do Minecraft (EULA)..."
    echo "eula=true" > eula.txt

    show_info "Criando script de inicialização..."
    cat <<EOF > start.sh
#!/bin/bash
java -Xmx${RAM_GB}G -Xms2G -jar fabric-server-launch.jar nogui --port ${SERVER_PORT}
EOF

    chmod +x start.sh

    # Configurar alias para rodar com 'start'
    setup_alias

    show_success "Instalação concluída! Para iniciar o servidor, basta digitar: ${COLOR_GREEN}start${COLOR_RESET}"

    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "\n${COLOR_GREEN}IP do Servidor:${COLOR_RESET} ${COLOR_BLUE}${SERVER_IP}:${SERVER_PORT}${COLOR_RESET}"
}

# Iniciar
main() {
    check_dependencies
    install_server
}

main

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
    FABRIC_LATEST=$(curl -s https://meta.fabricmc.net/v2/versions/installer | jq -r '.[0].version')
}

# Instalar servidor
install_server() {
    show_header
    get_latest_versions

    echo -e "${COLOR_CYAN}${SEPARATOR}"
    echo -e " Versões Recomendadas:"
    echo -e " • Minecraft: ${MC_LATEST}"
    echo -e " • Fabric: ${FABRIC_LATEST}"
    echo -e "${SEPARATOR}${COLOR_RESET}\n"

    read -p "Nome do Servidor: " SERVER_NAME
    read -p "Dificuldade (peaceful, easy, normal, hard): " SERVER_DIFFICULTY
    read -p "Versão do Minecraft (Enter para ${MC_LATEST}): " MC_VERSION
    MC_VERSION=${MC_VERSION:-$MC_LATEST}
    read -p "Versão do Fabric (Enter para ${FABRIC_LATEST}): " FABRIC_VERSION
    FABRIC_VERSION=${FABRIC_VERSION:-$FABRIC_LATEST}
    read -p "Quantidade de RAM para alocar (GB): " RAM_GB

    show_info "Configurando servidor..."
    SERVER_IP=$(get_server_ip)
    SERVER_PORT=25565
    echo -e "\n${COLOR_GREEN}Salve o IP e porta do servidor:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}IP: ${SERVER_IP}\nPorta: ${SERVER_PORT}${COLOR_RESET}"
    
    read -p "Deseja iniciar o servidor agora? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        show_info "Iniciando servidor em uma nova sessão screen..."
        screen -dmS minecraft bash -c "java -Xmx${RAM_GB}G -Xms2G -jar fabric-server-launch.jar nogui"
        show_success "Servidor iniciado! Para reabrir o painel, use: screen -r minecraft"
    else
        show_info "Servidor não foi iniciado. Você pode iniciar manualmente com:"
        echo -e "${COLOR_CYAN}screen -S minecraft -dm java -Xmx${RAM_GB}G -Xms2G -jar fabric-server-launch.jar nogui${COLOR_RESET}"
    fi
}

# Iniciar
main() {
    trap 'show_error "Instalação cancelada pelo usuário!"; exit 1' INT
    check_dependencies
    install_server
}

main

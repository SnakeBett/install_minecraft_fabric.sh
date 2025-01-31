#!/bin/bash

# Cores para melhorar a interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funções para exibição de mensagens
error() { echo -e "${RED}[ERRO] $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCESSO] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
warning() { echo -e "${YELLOW}[AVISO] $1${NC}"; }
debug() { echo -e "${CYAN}[DEBUG] $1${NC}"; }

# Verificações iniciais
check_root() {
    [ "$EUID" -ne 0 ] && error "Execute como root/sudo!"
}

check_os() {
    grep -qi 'ubuntu\|debian' /etc/os-release || error "Sistema não suportado (use Ubuntu/Debian)"
}

check_internet() {
    if ! ping -c 1 google.com &>/dev/null; then
        error "Sem conexão com a internet!"
    fi
}

# Instala dependências
install_dependencies() {
    local packages=("curl" "wget" "jq")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            info "Instalando $pkg..."
            apt-get install -y "$pkg" || error "Falha ao instalar $pkg"
        fi
    done
}

# Instala Java 17
install_java() {
    if ! command -v java &>/dev/null; then
        info "Instalando Java 17..."
        apt-get update >/dev/null
        apt-get install -y openjdk-17-jdk >/dev/null || error "Falha ao instalar Java"
    fi
}

# Valida versão do Minecraft
validate_minecraft_version() {
    local version=$1
    info "Validando versão $version..."
    
    local manifest_url="https://launchermeta.mojang.com/mc/game/version_manifest.json"
    local version_data=$(curl -s "$manifest_url" | jq -r ".versions[] | select(.id == \"$version\")")
    
    [ -z "$version_data" ] && error "Versão do Minecraft inválida!"
    success "Versão $version validada!"
}

# Valida versão do Fabric
validate_fabric_version() {
    local version=$1
    info "Validando versão do Fabric $version..."
    
    local fabric_url="https://maven.fabricmc.net/net/fabricmc/fabric-installer/$version/fabric-installer-$version.jar"
    if ! curl --head --silent --fail "$fabric_url" &>/dev/null; then
        error "Versão do Fabric inválida! Consulte: https://fabricmc.net/develop/"
    fi
    success "Versão do Fabric validada!"
}

# Configura memória
configure_ram() {
    while :; do
        read -p "${CYAN}» Quantos GB de RAM alocar? (ex: 4): ${NC}" RAM_GB
        [[ $RAM_GB =~ ^[0-9]+$ && $RAM_GB -ge 2 ]] && break
        warning "Valor inválido! Mínimo 2GB"
    done
}

# Baixa servidor Minecraft
download_minecraft_server() {
    local version=$1
    info "Baixando Minecraft Server $version..."
    
    local version_url=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | 
                      jq -r ".versions[] | select(.id == \"$version\") | .url")
    
    local server_url=$(curl -s "$version_url" | jq -r ".downloads.server.url")
    wget -q -O server.jar "$server_url" || error "Falha no download!"
}

# Baixa Fabric Installer
download_fabric_installer() {
    local fabric_version=$1
    info "Baixando Fabric Installer $fabric_version..."
    
    wget -q -O fabric-installer.jar \
        "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$fabric_version/fabric-installer-$fabric_version.jar" \
        || error "Falha no download!"
}

# Configuração inicial do servidor
setup_server() {
    info "Configurando servidor..."
    
    # Aceitar EULA
    echo "eula=true" > eula.txt || error "Falha ao criar eula.txt"
    
    # Configurações básicas
    cat > server.properties <<-EOL
        max-players=20
        online-mode=true
        server-port=25565
        enable-rcon=false
        motd=Meu Servidor Fabric
EOL

    success "Configuração completa!"
}

# Main
main() {
    clear
    echo -e "${GREEN}=== Minecraft Fabric Server Installer ===${NC}"
    
    # Verificações
    check_root
    check_os
    check_internet
    install_dependencies
    install_java

    # Entrada do usuário
    echo -e "\n${CYAN}Versões recentes recomendadas:"
    echo -e "• Minecraft: 1.20.1"
    echo -e "• Fabric: 0.14.22${NC}\n"

    read -p "${CYAN}» Versão do Minecraft (ex: 1.20.1): ${NC}" MC_VERSION
    validate_minecraft_version "$MC_VERSION"

    read -p "${CYAN}» Versão do Fabric Installer (ex: 0.14.22): ${NC}" FABRIC_VERSION
    validate_fabric_version "$FABRIC_VERSION"

    configure_ram

    # Download e instalação
    download_minecraft_server "$MC_VERSION"
    download_fabric_installer "$FABRIC_VERSION"
    
    info "Instalando Fabric Server..."
    java -jar fabric-installer.jar server -mcversion "$MC_VERSION" -downloadMinecraft >/dev/null || 
        error "Falha na instalação do Fabric"

    setup_server

    # Resultado final
    echo -e "\n${GREEN}=== Instalação concluída! ==="
    echo -e "Comando para iniciar:"
    echo -e "java -Xmx${RAM_GB}G -Xms${RAM_GB}G -jar fabric-server-launch.jar nogui\n"
    echo -e "Dica: Use 'screen' para manter o servidor rodando em background!"
    echo -e "Exemplo: screen -S minecraft${NC}"
}

main

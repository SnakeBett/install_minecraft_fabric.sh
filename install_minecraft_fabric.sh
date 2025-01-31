#!/bin/bash

# Cores para melhorar a interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens de erro e sair
error() {
    echo -e "${RED}[ERRO] $1${NC}"
    exit 1
}

# Função para exibir mensagens de sucesso
success() {
    echo -e "${GREEN}[SUCESSO] $1${NC}"
}

# Função para exibir informações
info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Função para exibir avisos
warning() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

# Verifica se o usuário tem permissões de root/sudo
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Este script precisa ser executado como root ou com sudo."
    fi
}

# Verifica se o sistema é Linux
check_os() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "Este script só funciona em sistemas Linux."
    fi
}

# Verifica se há conexão com a internet
check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        error "Sem conexão com a internet. Verifique sua rede."
    fi
}

# Instala o Java 17 se não estiver instalado
install_java() {
    if ! command -v java &> /dev/null; then
        info "Java não encontrado. Instalando Java 17..."
        sudo apt update || error "Falha ao atualizar pacotes."
        sudo apt install -y openjdk-17-jdk || error "Falha ao instalar o Java."
        success "Java 17 instalado com sucesso."
    else
        info "Java já está instalado."
    fi
}

# Pergunta ao usuário a quantidade de RAM
ask_ram() {
    while true; do
        read -p "Quantos GB de RAM a sua VPS tem? (ex: 2, 4, 8): " RAM_GB
        if [[ $RAM_GB =~ ^[0-9]+$ ]] && [ $RAM_GB -ge 2 ]; then
            break
        else
            warning "Por favor, insira um número válido (mínimo 2 GB)."
        fi
    done
}

# Baixa o servidor de Minecraft
download_minecraft_server() {
    local version=$1
    info "Baixando Minecraft Server versão $version..."
    wget -O server.jar "https://launcher.mojang.com/v1/objects/$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r ".versions[] | select(.id == \"$version\") | .url" | xargs curl -s | jq -r ".downloads.server.url")" || error "Falha ao baixar o servidor de Minecraft."
    success "Servidor de Minecraft baixado com sucesso."
}

# Baixa o Fabric Installer
download_fabric_installer() {
    local minecraft_version=$1
    local fabric_version=$2
    info "Baixando Fabric Installer para Minecraft $minecraft_version e Fabric $fabric_version..."
    wget -O fabric-installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$fabric_version/fabric-installer-$fabric_version.jar" || error "Falha ao baixar o Fabric Installer."
    success "Fabric Installer baixado com sucesso."
}

# Instala o Fabric Server
install_fabric_server() {
    local minecraft_version=$1
    info "Instalando Fabric Server..."
    java -jar fabric-installer.jar server -mcversion $minecraft_version -downloadMinecraft || error "Falha ao instalar o Fabric Server."
    success "Fabric Server instalado com sucesso."
}

# Configura o arquivo eula.txt
setup_eula() {
    info "Configurando eula.txt..."
    echo "eula=true" > eula.txt || error "Falha ao configurar eula.txt."
    success "eula.txt configurado com sucesso."
}

# Configura o arquivo server.properties
setup_server_properties() {
    info "Configurando server.properties..."
    cat <<EOL > server.properties
# Configurações do servidor de Minecraft
max-players=20
online-mode=true
server-port=25565
EOL
    success "server.properties configurado com sucesso."
}

# Inicia o servidor
start_server() {
    info "Iniciando o servidor de Minecraft..."
    java -Xmx${RAM_GB}G -Xms${RAM_GB}G -jar fabric-server-launch.jar nogui || error "Falha ao iniciar o servidor."
}

# Função principal
main() {
    echo -e "${GREEN}===== Instalador de Servidor de Minecraft com Fabric =====${NC}"
    check_root
    check_os
    check_internet
    install_java
    ask_ram

    read -p "Digite a versão do Minecraft (ex: 1.20.1): " MINECRAFT_VERSION
    read -p "Digite a versão do Fabric Installer (ex: 0.11.2): " FABRIC_VERSION

    download_minecraft_server $MINECRAFT_VERSION
    download_fabric_installer $MINECRAFT_VERSION $FABRIC_VERSION
    install_fabric_server $MINECRAFT_VERSION
    setup_eula
    setup_server_properties

    echo -e "${GREEN}===== Instalação concluída! =====${NC}"
    echo -e "Para iniciar o servidor, use o seguinte comando:"
    echo -e "java -Xmx${RAM_GB}G -Xms${RAM_GB}G -jar fabric-server-launch.jar nogui"
}

# Executa a função principal
main

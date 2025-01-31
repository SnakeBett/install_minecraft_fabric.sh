#!/bin/bash

# Código de cores melhorado
COLOR_RESET='\033[0m'
COLOR_RED='\033[1;91m'
COLOR_GREEN='\033[1;92m'
COLOR_YELLOW='\033[1;93m'
COLOR_BLUE='\033[1;94m'
COLOR_CYAN='\033[1;96m'
COLOR_WHITE='\033[1;97m'
COLOR_MAGENTA='\033[1;95m'

# Elementos visuais
SEPARATOR="═══════════════════════════════════════════════════"
TICK="✅"
CROSS="❌"
ARROW="»"

# Funções de exibição
show_header() {
    clear
    echo -e "${COLOR_MAGENTB}"
    echo "███████╗ █████╗ ██████╗ ██╗███╗   ██╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██║████╗  ██║██╔════╝ "
    echo "█████╗  ███████║██████╔╝██║██╔██╗ ██║██║  ███╗"
    echo "██╔══╝  ██╔══██║██╔══██╗██║██║╚██╗██║██║   ██║"
    echo "██║     ██║  ██║██║  ██║██║██║ ╚████║╚██████╔╝"
    echo "╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ "
    echo -e "${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${SEPARATOR}${COLOR_RESET}"
}

show_error() {
    echo -e "\n${COLOR_RED}${CROSS} Erro: $1${COLOR_RESET}" >&2
}

show_success() {
    echo -e "${COLOR_GREEN}${TICK} $1${COLOR_RESET}"
}

show_warning() {
    echo -e "${COLOR_YELLOW}⚠️  Aviso: $1${COLOR_RESET}"
}

show_info() {
    echo -e "${COLOR_BLUE}${ARROW} $1${COLOR_RESET}"
}

show_debug() {
    echo -e "${COLOR_WHITE}🐞 $1${COLOR_RESET}"
}

show_input_prompt() {
    echo -e -n "${COLOR_CYAN}${ARROW} $1${COLOR_RESET}"
}

# Funções de validação
validate_input() {
    while true; do
        read -p "$(show_input_prompt "$2")" input
        if eval "$1 \"\$input\""; then
            eval "$3=\"\$input\""
            break
        fi
    done
}

validate_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
        show_error "Formato de versão inválido. Use o formato X.X.X ou X.X"
        return 1
    }
}

validate_ram() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -ge 2 && "$1" -le 128 ]] || {
        show_error "RAM inválida! Deve ser entre 2-128 GB"
        return 1
    }
}

# Funções principais
check_dependencies() {
    local packages=("curl" "wget" "jq")
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

get_latest_versions() {
    show_info "Obtendo versões mais recentes..."
    MC_LATEST=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')
    FABRIC_LATEST=$(curl -s https://meta.fabricmc.net/v2/versions/installer | jq -r '.[0].version')
}

validate_minecraft_version() {
    local version=$1
    show_info "Verificando versão do Minecraft..."
    local versions
    versions=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.versions[].id')
    if ! grep -q "^$version$" <<< "$versions"; then
        show_error "Versão do Minecraft não encontrada!"
        return 1
    fi
}

validate_fabric_version() {
    local version=$1
    show_info "Verificando versão do Fabric..."
    if ! curl -Is "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$version/fabric-installer-$version.jar" | grep -q "200 OK"; then
        show_error "Versão do Fabric não encontrada!"
        return 1
    fi
}

install_server() {
    show_header
    get_latest_versions
    
    echo -e "${COLOR_CYAN}${SEPARATOR}"
    echo -e " Versões Recomendadas:"
    echo -e " • Minecraft: ${MC_LATEST}"
    echo -e " • Fabric: ${FABRIC_LATEST}"
    echo -e "${SEPARATOR}${COLOR_RESET}\n"

    # Entrada da versão do Minecraft
    validate_input 'validate_version' "Versão do Minecraft (deixe em branco para ${MC_LATEST}): " MC_VERSION
    MC_VERSION=${MC_VERSION:-$MC_LATEST}
    validate_minecraft_version "$MC_VERSION" || return 1

    # Entrada da versão do Fabric
    while true; do
        validate_input 'validate_version' "Versão do Fabric (deixe em branco para ${FABRIC_LATEST}): " FABRIC_VERSION
        FABRIC_VERSION=${FABRIC_VERSION:-$FABRIC_LATEST}
        if validate_fabric_version "$FABRIC_VERSION"; then
            break
        else
            show_warning "Tente novamente ou pressione Ctrl+C para sair"
        fi
    done

    # Configuração de RAM
    validate_input 'validate_ram' "Quantidade de RAM para alocar (GB): " RAM_GB

    # Download do Minecraft
    show_info "Baixando Minecraft Server ${MC_VERSION}..."
    local server_url=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | 
                     jq -r ".versions[] | select(.id == \"$MC_VERSION\") | .url" |
                     xargs curl -s | jq -r ".downloads.server.url")
    wget -q --show-progress -O server.jar "$server_url" || {
        show_error "Falha no download do Minecraft"
        return 1
    }

    # Download do Fabric
    show_info "Baixando Fabric Installer ${FABRIC_VERSION}..."
    wget -q --show-progress -O fabric-installer.jar \
        "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_VERSION}/fabric-installer-${FABRIC_VERSION}.jar" || {
        show_error "Falha no download do Fabric"
        return 1
    }

    # Instalação
    show_info "Instalando Fabric Server..."
    if ! java -jar fabric-installer.jar server -mcversion "$MC_VERSION" -downloadMinecraft -noprofile; then
        show_error "Falha na instalação do Fabric"
        return 1
    fi

    # Configuração
    show_info "Configurando servidor..."
    echo "eula=true" > eula.txt
    cat > server.properties <<EOF
max-players=20
online-mode=true
server-port=25565
motd=Meu Servidor Fabric
EOF

    # Verificação final
    if [ -f "fabric-server-launch.jar" ]; then
        show_success "Instalação concluída com sucesso!"
        echo -e "\n${COLOR_GREEN}Comando para iniciar:"
        echo -e "java -Xmx${RAM_GB}G -Xms2G -jar fabric-server-launch.jar nogui\n"
        echo -e "Dicas:"
        echo -e "• Use 'screen' para executar em segundo plano"
        echo -e "• Configure o server.properties para personalizar"
        echo -e "${SEPARATOR}${COLOR_RESET}"
    else
        show_error "Algo deu errado na instalação!"
        return 1
    fi
}

# Fluxo principal
main() {
    trap 'show_error "Instalação cancelada pelo usuário!"; exit 1' INT
    check_dependencies
    install_server
}

# Iniciar
main

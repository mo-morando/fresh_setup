#!/usr/bin/env bash
###############################################################################
# hbrew_iterm_omzsh.sh
#
# Opinionated zero-touch bootstrap for a modern macOS terminal:
#   • Installs or updates Homebrew and bundles a Brewfile
#   • Installs Oh-My-Zsh, Powerlevel10k, MesloLGS NF fonts
#   • Fetches common Oh-My-Zsh plugins
#   • Downloads selected iTerm2 colour schemes
#
# Usage:
#     chmod +x hbrew_iterm_omzsh.sh
#     ./hbrew_iterm_omzsh.sh   [--brewfile  <path>]
#                              [--colors    <dir> ]
#                              [--fonts     <dir> ]
#
# Exit codes:
#   1  – Unsupported OS
#   2  – Homebrew install failed
#   3  – Brewfile bundle failed
#   4  – Brewfile missing
#   5  – Oh-My-Zsh install failed
#   6  – Powerlevel10k install failed
#   7  – Zsh plugin install failed
#   8  – Verification failed
# 
# Author:  Michael Morando https://github.com/mo-morando
# License: MIT
###############################################################################

IFS=$'\n\t'

# Colors for outputs
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly NC=$'\033[0m' # No color

# ─────────────────────────────────── Globals ──────────────────────────────────
# Setting up some PATHS
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly LOG_FILE="${HOME}/terminal_setup.log"
# readonly LOG_FILE="${HOME}/log/setup/terminal_setup.log"
# Defaults – may be overridden via CLI flags
readonly BREWFILE="${HOME}/fresh_setup/hbrew_ohmyzsh/Brewfile"
readonly COLOR_DIR="${HOME}/iterm2/colors"
readonly FONT_DIR="${HOME}/Library/Fonts"

readonly Z_CUST="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
readonly HB_BIN="/opt/homebrew/bin/brew"
readonly PWLV10k_THMS="/themes/powerlevel10k"

# Arrays for loops
# Powerlevel10k fonts
FONTS=(
    MesloLGS_NF_{Regular,Bold,Italic,Italic}
)
readonly FONTS

# oh-my-zsh plugins
readonly ZSH_PLUGINS=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

# iTerm2 color schemes
readonly COLOR_SCHEMES=(
    Afterglow
    Embark
    IC_Orange_PPL
    Monokai%20Pro%20Spectrum
    Firefly%20Traditional
    CyberpunkScarletProtocol
)

# ────────────────────────────── Helper functions ─────────────────────────────
#_ Functions to output and log useful information
log() {
    local level="$1" message="$2" color="${3:-}"
    # echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${3:-NC}[${level}]${NC} ${message}" | tee -a "${LOG_FILE}"
    printf '[%s] %s%s%s %s\n' "$(date '+%F %T')" "${color}" "[${level}]" "${NC}" "${message}" | tee -a "$LOG_FILE"
    # printf '[%s] %s%s%s %s\n' "$(date '+%F %T')" "${3:-}" "[$1]" "${NC}" "$2"
}

print_status() {
    log "INFO" "$1" "${GREEN}"
}

print_warning() {
    log "WARNING" "$1" "${YELLOW}"
}

print_error() {
    log "ERROR" "$1" "${RED}"
}

error_exit() {
    local err_code=${1:-1} message="${2:-Script failed}"
    print_error "${message}"
    echo -e "${RED}Error code: ${err_code}${NC}" | tee -a "$LOG_FILE"
    exit "$err_code"
}

# Final print message
print_final() {
    echo ""
    print_status "✨ Setup completed successfully!"
    print_warning "Please complete the following manual steps:"
    cat <<EOF | tee -a "$LOG_FILE"

    1. Restart iTerm2 or open a new terminal window
    2. Font configuration
    2. Go to iTerm2 → Preferences → Profiles → Text
    3. Set Font to 'MesloLGS NF'
    4. Import the IC_Orange_PPL color scheme:
       - Press ⌘+i in iTerm2
       - Go to Colors tab > Color Presets > Import
       - Select ${COLOR_DIR}/IC_Orange_PPL
       - Choose IC_Orange_PPL from Color Presets
    5. Run 'p10k configure' to customize your prompt

EOF
    print_status "Enjoy your enhanced terminal experience! 🎉"
    echo ""
    echo ""
}
# # Final print message
# print_final() {
#     echo ""
#     print_status "✨ Setup completed successfully!"
#     print_warning "Please complete the following manual steps:"
#     echo "1. Restart iTerm2 or open a new terminal window"
#     echo "2. Font configuration"
#     echo "2. Go to iTerm2 → Preferences → Profiles → Text"
#     echo "3. Set Font to 'MesloLGS NF'"
#     echo "4. Import the IC_Orange_PPL color scheme:"
#     echo "   - Press ⌘+i in iTerm2"
#     echo "   - Go to Colors tab > Color Presets > Import"
#     echo "   - Select ${COLOR_DIR}/IC_Orange_PPL"
#     echo "   - Choose IC_Orange_PPL from Color Presets"
#     echo "5. Run 'p10k configure' to customize your prompt"
#     echo ""
#     print_status "Enjoy your enhanced terminal experience! 🎉"
#     echo ""
#     echo ""
# }

# pl_font_msg() {
#     echo "✅ Fonts installed successfully!"
#     echo "🔧 Next steps:"
#     echo "1. Restart iTerm2 or your terminal"
#     echo "2. Go to iTerm2 → Preferences → Profiles → Text"
#     echo "3. Set Font to 'MesloLGS NF'"
#     echo "4. Run 'p10k configure' to set up your prompt"
# }

# Utility functions
exists() {
    print_status "Checking if '${1}' exists..."
    command -v "${1}" &>/dev/null
}

dir_exists() {
    print_status "Checking if directory '${1}' exists..."
    [[ -d "${1}" ]]
    # TODO: Verbose?
}

ensure_dir() {
    if ! dir_exists "${1}"; then
        print_status "Directory ${1} does not exist"
        print_status "Making directory: ${1}"
        mkdir -p "${1}"
    else
        print_warning "Directory '${1}' exists"
    fi
}

retry() {
    local retries=$1 delay=$2
    shift 2
    local attempt=1
    local exit_code

    while [[ $attempt -le $retries ]]; do
        "$@"
        exit_code="$?"

        if [[ $exit_code -eq 0 ]]; then
            [[ $attempt -gt 1 ]] && print_status "Command succeeded on attempt $attempt"
            return 0
        fi

        if [[ $attempt -lt $retries ]]; then
            print_warning "Command failed (exit code ${exit_code}), retrying in ${delay}s... (attempt ${attempt}/${retries})"
            sleep "${delay}"
        else
            print_error "All $retries attempts failed. Last exit code: $exit_code"
        fi

        ((attempt++))
    done

    return "$exit_code"
}

# ───────────────────────────── Workflow functions ────────────────────────────
# Confirm you are running a macOS
check_macos() {
    if [[ $OSTYPE != "darwin"* ]]; then
        error_exit 1 "This script is design for the macOS. Exiting..."
    fi
}

# Download Homebrew if not installed
install_addpath_hbrew() {
    if ! exists brew; then
        print_status "Homebrew is not installed. Installing Homebrew..."
        retry 3 5 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit 2 "Homebrew download failed"

        # Add Homebrew to Path for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" && -x "${hb_bin}" ]]; then
            local hb_bin="${1:-/opt/homebrew/bin/brew}"
            local zsh_custom_dir="${2:-${HOME}/.oh-my-zsh/custom}"
            eval "$(${hb_bin} shellenv)"
            grep -q "$hb_bin" ~/.zprofile 2>/dev/null || echo "eval \"\$({$hb_bin} shellenv)\"" >>~/.zprofile
        else
            print_warning "Failed to evaluate Homebrew environment"
        fi
    else
        print_warning "Homebrew is already installed."
    fi
}

# Brew install files using a Brewfile
# This includes iTerm2 and is needed for the rest of the scripts
install_brewfile() {
    if [[ -f "$BREWFILE" ]]; then
        print_status "Installing files from Brewfile..."
        #retry 3 10 brew bundle --file="$BREWFILE" || error_exit 3 "Brewfile installation failed"
    else
        error_exit 4 "Brewfile not found at '$BREWFILE'. Brewfile required for full installation."
    fi
}

# Download colors for iTerm2
# download_colour <schemeName>
download_iterm_color() {
    local url out_file base_url="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/"
    if [[ ! -f "${COLOR_DIR}/${1}" ]]; then
        url="${base_url}${1}".itermcolors
        out_file="${COLOR_DIR}"/"${1}".itermcolors
        print_status "Downloading color scheme: '${1}'"
        retry 3 5 curl -L "${url}" -o "${out_file}" || error_exit 8 "Download failed : '${url}'"
    else
        print_warning "Iterm2 color scheme: '{1}' already exists. Skipping color scheme downloads."
    fi
}

#_ Install Oh My Zsh
# install_zsh_plugin <name>
install_ohmyzsh() {
    if ! dir_exists "$HOME/.oh-my-zsh"; then
        print_status "Oh My Zsh is not installed. Installing Oh My Zsh..."
        retry 3 5 sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || error_exit 5 "Oh My Zsh download failed"
    else
        print_warning "Oh My Zsh is already installed. Skipping installation"
    fi
}

#- Install Powerlevel10k Theme
install_powerlevel10k() {
    local zsh_custom_dir="${1:-${HOME}/.oh-my-zsh/custom}"
    local powerlevel10k="${2:-${ZSH_CUSTOM}/themes/powerlevel10k}"
    if ! dir_exists "${zsh_custom_dir}${powerlevel10k}"; then
        print_status "Powerlevel10k theme not installed. Installing theme now.."
        retry 3 5 git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$powerlevel10k" || error_exit 6 "Powerlevel10k theme download failed"
    else
        print_warning "Powerlevel10k theme already installed. Skipping download"
    fi
}

# Function to download Powerlevel10k fonts used for Oh My ZSH
# download_font <Meslo…>
download_iterm_font() {
    # URL-encode spaces as %20
    local name url file_path
    name=$(echo "${1}" | sed 's/_/%20/g')
    url="https://github.com/romkatv/powerlevel10k-media/raw/master/${name}.ttf"
    file_path="${FONT_DIR}/${1}.ttf"

    if [[ ! -f "${file_path}" ]]; then
        print_status "Downloading font: '${1}' to directory: '${file_path}'"
        retry 3 5 curl -fsSL -o "${file_path}" "${url}" || print_warning "Downloading powerlevel10k font ${1} failed."
    else
        print_warning "Powerlevel10k font ${1} already downloaded. Skipping."
    fi
}

# Function to install oh-my-zsh plugins
# install_zsh_plugin <name>
install_zsh_plugin() {
    local plugin="/plugins/zsh-autosuggestions"
    local zsh_custom_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"

    if ! dir_exists "${zsh_custom_dir}${plugin}"; then
        print_status "Plugin '${plugin}' not installed. Installing..."
        retry 3 5 git clone https://github.com/zsh-users/zsh-autosuggestions "${zsh_custom_dir}"/plugins/zsh-autosuggestions || error_exit 7 "zsh-autosuggestion did not download"
    else
        print_warning "Plugin '${plugin}' already installed. Skipping installation..."
    fi
}

# Verify installations
verify_installs() {
    print_status "Verifying installation…"
    exists brew || error_exit 8 "Homebrew missing"
    dir_exists "$HOME/.oh-my-zsh" || error_exit 8 "Oh-My-Zsh missing"
    dir_exists "${Z_CUST}${PWLV10k_THMS}" || error_exit 8 "Powerlevel10k theme missing"
    print_status "✔ All components verified – enjoy! ✨"
    print_final
}

# ──────────────────────────────── CLI parsing ────────────────────────────────
while (("$#" > 0)); do
    case "$1" in
    --brewfile)
        BREWFILE=$2
        shift 2
        ;;
    --colors)
        COLOR_DIR=$2
        shift 2
        ;;
    --fonts)
        FONT_DIR=$2
        shift 2
        ;;
    -h | --help)
        sed -n '2,29p' "$0";
        exit 0
        ;;
    *)
        error_exit 1 "Unknown flag passed: '$1'"
        ;;
    esac
done

# ────────────────────────────────── Main ─────────────────────────────────────
main() {
    set -euo pipefail # Exit on any error, unset variables, and failed pipes
    
    print_status "Running ${SCRIPT_NAME}"
    echo ""
    echo ""
    print_status "🥳 Starting Terminal Setup! 🎉"
    echo ""
    echo ""

    check_macos
    install_addpath_hbrew "$HB_BIN" "$Z_CUST"
    install_brewfile
    install_ohmyzsh
    install_powerlevel10k "$Z_CUST" "$PWLV10k_THMS"

    # Download color schemes loop
    print_status "Fetching iTerm2 colour schemes…"
    ensure_dir "$COLOR_DIR"
    for scheme in "${COLOR_SCHEMES[@]}"; do
        download_iterm_color "$scheme"
    done

    # Installing Font for Powerlevel10k loop
    print_status "Downloading MesloLGS NF fonts…"
    ensure_dir "$FONT_DIR"
    for font in "${FONTS[@]}"; do
        download_iterm_font "$font"
    done

    # Install ZSH plugins loop
    print_status "Installing zsh plugins…"
    for plugin in "${ZSH_PLUGINS[@]}"; do
        install_zsh_plugin "$plugin"
    done

    verify_installs
}

# Only execute main when run, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

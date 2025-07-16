#!/usr/bin/env bash
###############################################################################
# install_miniforge_mamba.sh
#
# Professional Miniforge/Mamba installation script for macOS:
#   • Detects system architecture and downloads appropriate installer
#   • Installs Miniforge with mamba package manager
#   • Configures shell initialization
#   • Verifies successful installation
#   • Provides comprehensive logging and error handling
#
# Usage:
#     chmod +x install_miniforge_mamba.sh
#     ./install_miniforge_mamba.sh [--install-path <path>]
#                                  [--no-init]
#                                  [--keep-installer]
#                                  [--dry-run]
#                                  [--force]
#
# Flags:
#   --install-path    Custom installation directory (default: ~/miniforge3)
#   --no-init         Skip shell initialization setup
#   --keep-installer  Don't remove installer file after installation
#   --dry-run         Show what would be done without making changes
#   --force           Skip confirmation prompts
#
# Exit codes:
#   0  – Success
#   1  – Unsupported OS
#   2  – User cancelled
#   3  – Download failed
#   4  – Installation failed
#   5  – Verification failed
#   6  – Shell initialization failed
#
# Author:  Michael Morando http://github.com/mo-morando
# License: MIT
###############################################################################

set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────── Colors ──────────────────────────────────
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly CYAN=$'\033[0;36m'
readonly NC=$'\033[0m'

# ─────────────────────────────────── Globals ──────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly LOG_FILE="${HOME}/mamba_install.log"
BACKUP_DIR="${HOME}/.miniforge_backup_$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR

# Default configuration
INSTALL_PATH="$HOME/miniforge3"
NO_INIT=false
KEEP_INSTALLER=false
DRY_RUN=false
FORCE=false

# System detection variables
OS=""
ARCH=""
INSTALLER=""

# ────────────────────────────── Helper Functions ─────────────────────────────
log() {
    local level="$1" message="$2" color="${3:-}"
    printf '[%s] %s%s%s %s\n' "$(date '+%F %T')" "${color}" "[${level}]" "${NC}" "${message}" | tee -a "$LOG_FILE"
}

print_info() {
    log "INFO" "$1" "${GREEN}"
}

print_warn() {
    log "WARNING" "$1" "${YELLOW}"
}

print_error() {
    log "ERROR" "$1" "${RED}"
}

print_dry_run() {
    log "DRY-RUN" "$1" "${BLUE}"
}

print_detect() {
    log "DETECT" "$1" "${CYAN}"
}

error_exit() {
    local err_code=${1:-$?} message="${2:-Script failed}"
    print_error "${message}"
    echo -e "${RED}Error code: $err_code${NC}" | tee -a "$LOG_FILE"
    exit "$err_code"
}

exists() {
    print_info "Checking if '${1}' exists..."
    command -v "$1" &>/dev/null
}

confirm() {
    [[ $FORCE == true ]] && return 0
    local prompt="$1"
    echo -n "${YELLOW}${prompt} [y/N]: ${NC}"
    read -r response
    [[ $response =~ ^[Yy]$ ]]
}

execute_or_dry_run() {
    local description="$1"
    shift
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "$description"
        print_detect "Would execute: $*"
    else
        print_info "$description"
        "@"
    fi
}

retry() {
    local retries="$1" delay="$2"
    shift 2
    local attempt=1
    local exit_code

    while [[ "$attempt" -le "$retries" ]]; do
        "$@"
        exit_code="$?"

        if [[ $exit_code -eq 0 ]]; then
            [[ $attempt -gt 1 ]] && print_info "Command succeeded on attempt $attempt"
            return 0
        fi

        if [[ "$attempt" -lt "$retries" ]]; then
            # [[ $attempt -gt 1 ]] && print_info ""
            print_warn "Command failed (exit code ${exit_code}), retrying in ${delay}s... (attempt ${attempt}/${retries})"
            sleep "$delay"
        else
            print_error "All $retries attempts failed. Last exit code: $exit_code"
        fi
        ((attempt++))
    done

    return "$exit_code"
}


#     ------------------------------------------------------------
#     🎉 Installation completed successfully!
#     📂 Miniforge installed to: $INSTALL_PATH
    
#     🚀 You can now use mamba or conda to manage your Python environments and packages.
    
#     💡 You may need to restart your command line interface or run:
#        \`conda init $SHELL_NAME\`
#        This will automatically detect the shell and fully initialize Miniforge.
#        You can then start downloading packages and setting up environments! 😎
#     "------------------------------------------------------------"

    
# EOF
#     exit 0
# }
display_success_message() {
    echo ""
    print_info "═══════════════════════════════════════════════════════════════"
    print_info "                   INSTALLATION COMPLETED                      "
    print_info "═══════════════════════════════════════════════════════════════"
    
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN - No changes were made to your system"
        return
    fi
    
    cat <<EOF | tee -a "$LOG_FILE"

🎉 Miniforge installation completed successfully!
📂 Installation location: $INSTALL_PATH

🚀 Available package managers:
   • mamba - Fast conda-compatible package manager
   • conda - Traditional conda package manager

💡 Next steps:
   1. Restart your terminal or run: exec $SHELL
   2. Verify installation: conda --version && mamba --version
   3. Create your first environment: mamba create -n myenv python=3.11
   4. Activate environment: conda activate myenv

📚 Useful commands:
   • mamba install <package>     - Install packages (faster than conda)
   • conda create -n <name>      - Create new environment
   • conda activate <name>       - Activate environment
   • conda deactivate            - Deactivate current environment
   • mamba list                  - List installed packages

EOF
    
    print_info "Happy coding with Miniforge and Mamba! 🐍✨"
}

# ───────────────────────────── Workflow functions ────────────────────────────
detect_system() {
    print_info "🔍 Detecting system architecture..."

    OS=$(uname) || error_exit 4 "Failed to detect operating system"
    ARCH=$(uname -m) || error_exit 4 "Failed to detect architecture"

    print_detect "Operating System: $OS"
    print_detect "Architecture: $ARCH"

    # Validate macOS
    if [[ $OS != "Darwin" ]]; then
        error_exit 1 "This script only supports macOS. Detected: $OS"
    fi

    # Normalize architecture names for Miniforge
    case $ARCH in
    "x86_64") ARCH="x86_64" ;;
    "arm64" | "aarch64") ARCH="arm64" ;;
    *) error_exit 1 "Unsupported architecture: $ARCH" ;;
    esac

    print_detect "Normalized architecture: $ARCH"
}

check_existing_installation() {
    print_info "🔍 Checking for existing installations..."

    local found_installations=()

    # Check for existing conda/mamba installations
    if exists conda; then
        local conda_base
        conda_base=$(conda info --base 2>/dev/null || echo "unknown")
        print_warn "Found existing conda installation: $conda_base"
        found_installations+=("conda")
    fi

    if exists mamba; then
        print_warn "Found existing mamba installation"
        found_installations+=("mamba")
    fi

    # Check if target directory exists
    if [[ -d "$INSTALL_PATH" ]]; then
        print_warn "Target directory already exists: $INSTALL_PATH"
        found_installations+=("directory")
    fi

    if [[ ${#found_installations[@]} -gt 0 ]]; then
        print_warn "Existing installations detected. This may cause conflicts."
        if ! confirm "Continue with installation anyway?"; then
            error_exit 2 "Installation cancelled by user"
        fi
    else
        print_info "No existing installations found"
    fi
}

# ──────────────────────────── Installation Functions ──────────────────────────
determine_installer() {
    print_info "📝 Determining installer filename..."

    INSTALLER="Miniforge3-${OS}-${ARCH}.sh"
    print_info "Installer filename: $INSTALLER"

    # Verify the URL exists (optional validation)
    local url="https://github.com/conda-forge/miniforge/releases/latest/download/${INSTALLER}"
    print_info "Download URL: $url"
}

download_installer() {
    print_info "📥 Downloading Miniforge installer: '$INSTALLER'..."

    if [[ -f "$INSTALLER" ]]; then
        print_warn "Installer already exists: $INSTALLER"
        if confirm "Re-download installer?"; then
            execute_or_dry_run "Removing existing installer" rm -f "$INSTALLER"
        else
            print_info "Using existing installer"
            return 0
        fi
    fi

    local url="https://github.com/conda-forge/miniforge/releases/latest/download/${INSTALLER}"
    
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would download: $url"
        return 0
    fi

    print_info "Downloading from: $url"
    retry 3 5 curl -fsSL -O "$url" || error_exit 3 "Failed to download installer"
    
    # Verify download
    if [[ ! -f "$INSTALLER" ]]; then
        die 3 "Installer not found after download"
    fi

    local file_size
    file_size="$(stat -f%z "$INSTALLER" 2>/dev/null || echo "0")"
    if [[ file_size -lt 10000000 ]]; then
        print_warn "Downloaded installer seems small ($file_size bytes). This might indicate a download issue."
    fi

    print_info "✅ Download complete: $INSTALLER (${file_size} bytes)"
}

install_miniforge() {
    print_info "📦 Installing Miniforge..."

    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would install Miniforge to: $INSTALL_PATH"
        return 0
    fi

    # Create backup if directory exits
    if [[ -d "$INSTALLER" ]]; then
        print_info "Creating backup of existing installation..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$INSTALL_PATH" "$BACKUP_DIR/miniforge3_backup" || print_warn "Failed to create backup"
    fi

    # Run installer
    print_info "Running installer (batch mode, no prompts)..."
    if bash "$INSTALLER" -b -p "$INSTALL_PATH"; then
        print_info "✅ Installation completed"
    else
        die 4 "Installation failed"
    fi
    
    # Cleanup installer unless requested to keep
    if [[ $KEEP_INSTALLER == false ]]; then
        print_info "Cleaning up installer file..."
        rm -f "$INSTALLER"
    else
        print_info "Keeping installer file: $INSTALLER"
    fi

}

initialize_shell() {

    [[ $NO_INIT == true ]] && { print_info "Skipping shell initialization (--no-init specified)"; return; }

    # Detect shell
    local shell_name
    shell_name=$(basename "$SHELL")
    print_info "Detected shell: $shell_name"
    [[ $DRY_RUN == true ]] && { print_dry_run "Would initialize shell: $shell_name..."; return 0; }
    
    # Initialize conda/mamba for the detected shell
    if [[ -x "$INSTALL_PATH/bin/conda" ]]; then
        print_info "Initializing conda for $shell_name..."
        "$INSTALL_PATH/bin/conda" init "$shell_name" || print_warn "Shell initialization failed"
    else
        print_error "conda binary not found at $INSTALL_PATH/bin/conda"
        return 1
    fi
    
    # Initialize conda/mamba for the detected shell
    if [[ -x "$INSTALL_PATH/bin/mamba" ]]; then
        print_info "Initializing mamba for $shell_name..."
        "$INSTALL_PATH/bin/mamba" init "$shell_name" || print_warn "Shell initialization failed"
    else
        print_error "mamba binary not found at $INSTALL_PATH/bin/mamba"
        return 1
    fi
    
    print_info "✅ Shell initialization complete"
}

verify_install() {
    print_info "🔍 Verifying installation..."

    local issues=0

    # Check installation directory
    if [[ ! -d "$INSTALL_PATH" ]]; then
        print_error "Installation directory not found: $INSTALL_PATH"
        ((++issues))
    fi

    # Check for executables
    local executables=("conda" "mamba")
    for exec in "${executables[@]}"; do
        local exec_path="${INSTALL_PATH}/bin/${exec}"
        if [[ -x "$exec_path" ]]; then
            print_info "✅ Found executable: $exec"

            # Test basic functionality (if not dry run)
            if [[ $DRY_RUN == false ]]; then
                local version
                version=$("$exec_path" --version 2>/dev/null | head -n1 || echo "unknown")
                print_info "  Version: $version"
            fi
        else
            print_error "Executable not found or not executable: $exec_path"
            ((++issues))
        fi
    done

    # Check for key directories
    local key_dirs=("pkgs" "envs" "bin" "lib")
    for dir in "${key_dirs[@]}"; do
        if [[ -d "$INSTALL_PATH/$dir" ]]; then
            print_info "✅ Found directory: $dir"
        else
            print_warn "Directory not found: $dir"
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        print_info "✅ Verification passed - installation successful!"
        return 0
    else
        print_warn "Verification failed with $issues issues"
        return 1
    fi
}


# ──────────────────────────────── CLI parsing ────────────────────────────────
while (("$#" > 0)); do
    case "$1" in
    --miniforge_path)
        INSTALL_PATH="$1"
        shift 2
        ;;
    --no-init)
        NO_INIT="$1"
        shift 2
        ;;
    --keep-installer)
        KEEP_INSTALLER="$1"
        shift 2
        ;;
    --force)
        FORCE="$1"
        shift 2
        ;;
    -h | --help)
        sed -n '2,38p' "$0";
        exit 0;
        shift 2
        ;;
    --dry-run)
            DRY_RUN=true
            shift
            ;;
    *)
        error_exit 10 "Unknown flag passed: '$1'"
        ;;
    esac
done

# ────────────────────────────────── Main ─────────────────────────────────────
main() {
    echo ""
    echo ""
    print_info "Starting Miniforge/Mamba installation 🐍"
    print_info "Running ${SCRIPT_NAME} with args: $*"
    echo ""
    echo ""

    detect_system
    check_existing_installation
    determine_installer
    download_installer

    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN MODE - No changes will be made"
    else
        if ! confirm "Proceed with Miniforge installation to $INSTALL_PATH?"; then
            error_exit 2 "Installation canceled by user"
        fi
    fi

    install_miniforge
    initialize_shell

    if verify_install; then
        display_success_message
    else
        [[ $DRY_RUN == true ]] && print_dry_run "DRY RUN MODE - Nothing was installed."
        error_exit 5 "Installation verification failed"
    fi

}

# Only execute main when run, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash
###############################################################################
# uninstall_miniforge_mamba.sh
#
# Complete uninstaller for Anaconda, Miniconda, Miniforge, Conda, and Mamba:
#   • Removes all Anaconda/Miniconda/Miniforge installations
#   • Removes all conda environments and packages
#   • Removes Mamba and related tools
#   • Cleans shell configuration files
#   • Removes configuration files, caches, and receipts
#   • Restores clean Python environment
#
# Usage:
#     chmod +x uninstall_anaconda_mamba.sh
#     ./uninstall_anaconda_mamba.sh [--keep-cache]
#                                   [--keep-config]
#                                   [--dry-run]
#                                   [--force]
#                                   [--no-backup]
#
# Flags:
#   --keep-cache       Don't remove conda/mamba cache directories
#   --keep-config      Don't remove configuration files (.condarc, etc.)
#   --dry-run          Show what would be removed without actually removing
#   --force            Skip confirmation prompts
#   --no-backup        Skip creating backup of configuration files
#
# Exit codes:
#   0  – Success
#   1  – Unsupported OS
#   2  – User cancelled
#   3  – Backup failed
#   4  – Uninstall failed
#   5  – Permission denied
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
readonly LOG_FILE="${HOME}/miniforge_uninstall.log"
readonly BACKUP_DIR="${HOME}/.miniforge_uninstall_backup_$(date +%Y%m%d_%H%M%S)"

# Default configuration
DRY_RUN=false
KEEP_CACHE=false
KEEP_CONFIG=false
FORCE=false
NO_BACKUP=false

# Installation paths to check
readonly CONDA_PATHS=(
    "$HOME/anaconda"
    "$HOME/anaconda2"
    "$HOME/anaconda3"
    "$HOME/miniconda"
    "$HOME/miniconda2"
    "$HOME/miniconda3"
    "$HOME/miniforge"
    "$HOME/miniforge3"
    "$HOME/mambaforge"
    "/opt/anaconda"
    "/opt/anaconda2"
    "/opt/anaconda3"
    "/opt/miniconda"
    "/opt/miniconda2"
    "/opt/miniconda3"
    "/opt/miniforge"
    "/opt/miniforge3"
    "/opt/mambaforge"
    "/usr/local/anaconda"
    "/usr/local/anaconda2"
    "/usr/local/anaconda3"
    "/usr/local/miniconda"
    "/usr/local/miniconda2"
    "/usr/local/miniconda3"
    "/usr/local/miniforge"
    "/usr/local/miniforge3"
    "/usr/local/mambaforge"
)

# Configuration files and directories
readonly CONFIG_FILES=(
    "$HOME/.condarc"
    "$HOME/.mambarc"
)

readonly CONFIG_DIRS=(
    "$HOME/.conda"
    "$HOME/.continuum"
    "$HOME/.anaconda"
    "$HOME/.anaconda_backup"
    "$HOME/.mamba"
    "$HOME/.mambaforge"
)

readonly CACHE_DIRS=(
    "$HOME/.cache/conda"
    "$HOME/.cache/pip"
    "$HOME/.cache/mamba"
)

readonly SHELL_FILES=(
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.zshenv"
    "$HOME/.profile"
)

readonly APP_DIRS=(
    "/Applications/Anaconda-Navigator.app"
    "/Applications/Anaconda3"
)

# ────────────────────────────── Helper Functions ─────────────────────────────
log() {
    local level="$1" message="$2" color="${3:-}"
    printf '[%s] %s%s%s %s\n' "$(date '+%F %T')" "${color}" "[${level}]" "${NC}" "${message}" | tee -a "${LOG_FILE}"
}

print_info() { log "INFO" "$1" "${GREEN}"; }
print_warn() { log "WARNING" "$1" "${YELLOW}"; }
print_error() { log "ERROR" "$1" "${RED}"; }
print_dry_run() { log "DRY-RUN" "$1" "${BLUE}"; }
print_detect() { log "DETECT" "$1" "${CYAN}"; }

error_exit() {
    local err_code=${1:-1} message="${2:-Script failed}"
    print_error "${message}"
    echo -e "${RED}Error code: ${err_code}${NC}" | tee -a "$LOG_FILE"
    exit "$err_code"
}

exists() {
    command -v "$1" &>/dev/null
}

dir_exists() {
    print_info "Checking if directory '${1}' exists..."
    [[ -d "${1}" ]]
    # TODO: Verbose?
}

ensure_dir() {
    if ! dir_exists "${1}"; then
        print_info "Directory ${1} does not exist"
        print_info "Making directory: ${1}"
        mkdir -p "${1}"
    else
        print_warning "Directory '${1}' exists"
    fi
}

confirm() {
    [[ $FORCE == true ]] && return 0
    local prompt="$1"
    echo -n "${YELLOW}${prompt} [y/N]: ${NC}"
    read -r response
    [[ $response =~ ^[yY]$ ]]
}

execute_or_dry_run() {
    local description="$1"
    shift
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "$description"
        # print_dry_run "Would execute: $*"
        print_dry_run "Would execute: $(printf '%q ' "$@")"
    else
        print_info "$description"
        "$@"
    fi
}

safe_remove() {
    local path="$1" description="$2"

    if [[ -e "$path" ]]; then
        print_detect "Found: $1"
        execute_or_dry_run "$description" rm -rf "$path"
        if [[ $DRY_RUN == false && -e "$path" ]]; then
            print_error "Failed to remove: $1"
            return 1
        fi
    else
        print_info "$description (not found skipping)"
    fi
}

safe_remove_file() {
    local path="$1" description="$2"

    if [[ -f "$path" ]]; then
        print_detect "Found file: $1"
        execute_or_dry_run "$description" rm -f "$path"
        if [[ $DRY_RUN == false && -f "$path" ]]; then
            print_error "Failed to remove file: $1"
            return 1
        fi
    else
        print_info "$description (file not found skipping)"
    fi
}

# ───────────────────────────── System Detection ────────────────────────────
check_macos() {
    [[ $OSTYPE == darwin* ]] || error_exit 1 "This script only supports macOS."
}

detect_installations() {
    print_info "Detecting Anaconda/Mamba installations..."

    local found_installations=()

    # Check for conda command
    if exists conda; then
        local conda_info
        conda_info=$(conda info --base 2>/dev/null || echo "unknown")
        print_detect "Active conda installation: $conda_info"
        found_installations+=("conda")
    fi

    # Check for mamba command
    if exists mamba; then
        print_detect "Active mamba installation"
        found_installations+=("mamba")
    fi

    # Check installation directories
    for path in "${CONDA_PATHS[@]}"; do
        if dir_exists "$path"; then
            print_detect "Installation directory: $path"
            found_installations+=("$path")
        fi
    done

    # Check configuration files
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            print_detect "Configuration file: $file"
        fi
    done

    # Check configuration directories
    for dir in "${CONFIG_DIRS[@]}"; do
        if dir_exists "$dir"; then
            print_detect "Configuration directory: $dir"
        fi
    done

    if [[ ${#found_installations[@]} -eq 0 ]]; then
        print_warn "No Anaconda/Mamba installations detected"
        if ! confirm "Continue with cleanup anyway?"; then
            error_exit 2 "Operation cancelled"
        fi
    fi
}

# ───────────────────────────── Backup Functions ────────────────────────────
create_backup() {
    [[ $NO_BACKUP == true ]] && {
        print_info "Skipping backup (--no-backup specified)"
        return 0
    }
    [[ $DRY_RUN == true ]] && {
        print_dry_run "Would create backup at: $BACKUP_DIR"
        return 0
    }

    print_info "Creating backup at: $BACKUP_DIR"
    ensure_dir "$BACKUP_DIR"

    # Backup shell configuration files
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/config/" 2>/dev/null || true
            print_info "Backed up: $(basename "$file")"
        fi
    done

    # Backup shell configuration files
    for file in "${SHELL_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/shell/" 2>/dev/null || true
            print_info "Backed up: $(basename "$file")"
        fi
    done

    # Backup environment list if conda is available
    if exists conda; then
        conda env list >"$BACKUP_DIR/conda_environment_names.txt" 2>/dev/null || true
        conda list >"$BACKUP_DIR/conda_base_packages.txt" 2>/dev/null || true
        print_info "Backed up conda environment names and base package lists"
    fi

    print_info "Backup created successfully"
}

# ───────────────────────────── Uninstall Functions ────────────────────────────
run_anaconda_clean() {
    print_info "Running anaconda-clean (if available)..."

    if exists conda; then
        print_info "Conda found, attempting to run anaconda-clean..."
        execute_or_dry_run "Installing anaconda-clean" mamba install anaconda-clean --yes 2>/dev/null || true
        execute_or_dry_run "Executing anaconda-clean" anaconda-clean --yes 2>/dev/null || true
    else
        print_info "Conda not found, skipping anaconda-clean"
    fi
}

remove_installations() {
    print_info "Removing installation directories..."

    for path in "${CONDA_PATHS[@]}"; do
        safe_remove "$path" "Removing installation: $(basename "$path")"
    done

    # Remove application directories
    for app in "${APP_DIRS[@]}"; do
        safe_remove "$app" "Removing application: $(basename "$app")"
    done
}
remove_configuration() {
    [[ $KEEP_CONFIG == true ]] && {
        print_info "Keeping configuration files (--keep-config specified)"
        return
    }

    print_info "Removing configuration files and directories..."

    # Remove configuration files
    for file in "${CONFIG_FILES[@]}"; do
        safe_remove_file "$file" "Removing config file: $(basename "$file")"
    done

    # Remove configuration directories
    for dir in "${CONFIG_DIRS[@]}"; do
        safe_remove "$dir" "Removing config directory: $(basename "$dir")"
    done
}

remove_cache() {
    [[ $KEEP_CACHE == true ]] && {
        print_info "Keeping cache directories (--keep-cache specified)"
        return
    }

    print_info "Removing cache directories..."

    for dir in "${CACHE_DIRS[@]}"; do
        safe_remove "$dir" "Removing cache directory: $(basename "$dir")"
    done
}

clean_shell_configuration() {
    print_info "Cleaning shell configuration files..."

    for file in "${SHELL_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            if [[ $DRY_RUN == true ]]; then
                print_dry_run "Would clean conda/mamba configuration from $(basename "$file")"
            else
                # Create backup with timestamp
                local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$file" "$backup_file"

                # Remove conda/mamba initialization blocks
                sed -i '' '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$file" 2>/dev/null || true
                sed -i '' '/# >>> mamba initialize >>>/,/# <<< mamba initialize <<</d' "$file" 2>/dev/null || true

                # Remove conda/mamba related exports and aliases
                sed -i '' '/anaconda/d' "$file" 2>/dev/null || true
                sed -i '' '/miniconda/d' "$file" 2>/dev/null || true
                sed -i '' '/miniforge/d' "$file" 2>/dev/null || true
                sed -i '' '/mambaforge/d' "$file" 2>/dev/null || true
                sed -i '' '/export.*conda/d' "$file" 2>/dev/null || true
                sed -i '' '/export.*mamba/d' "$file" 2>/dev/null || true
                sed -i '' '/alias.*conda/d' "$file" 2>/dev/null || true
                sed -i '' '/alias.*mamba/d' "$file" 2>/dev/null || true

                print_info "Cleaned $(basename "$file") (backup: $(basename "$backup_file"))"

            fi

        fi
    done
}

remove_receipts() {
    print_info "Removing installer receipts and logs..."

    # User receipts
    local user_receipts=(
        "$HOME/Library/Receipts/io.continuum.pkg.anaconda-client.bom"
        "$HOME/Library/Receipts/io.continuum.pkg.anaconda-client.plist"
        "$HOME/Library/Receipts/io.continuum.pkg.anaconda-navigator.bom"
        "$HOME/Library/Receipts/io.continuum.pkg.anaconda-navigator.plist"
    )

    for receipt in "${user_receipts[@]}"; do
        safe_remove_file "$receipt" "Removing user receipt: $(basename "$receipt")"
    done

    # System receipts (requires admin privileges)
    if dir_exists "/Library/Receipts"; then
        print_info "Checking system receipts (may require admin privileges)..."
        if [[ $DRY_RUN == true ]]; then
            print_dry_run "Would remove system receipts for anaconda/conda/mamba"
        else
            sudo find /Library/Receipts -name "*anaconda*" -type f -delete 2>/dev/null || true
            sudo find /Library/Receipts -name "*conda*" -type f -delete 2>/dev/null || true
            sudo find /Library/Receipts -name "*mamba*" -type f -delete 2>/dev/null || true
            print_info "Removed system receipts"
        fi
    fi
}

remove_python_packages() {
    print_info "Removing conda/mamba related Python packages..."

    # Try to remove from system Python
    local packages=(
        "conda"
        "conda-env"
        "conda-build"
        "mamba"
        "micromamba"
        "anaconda-client"
        "anaconda-navigator"
    )

    for pkg in "${packages[@]}"; do
        if [[ $DRY_RUN == true ]]; then
            print_dry_run "Would attempt to remove Python package: $pkg"
        else
            python3 -m pip uninstall "$pkg" -y 2>/dev/null || true
            print_info "Attempted to remove Python package: $pkg"
        fi
    done
}

cleanup_environment() {
    print_info "Cleaning up environment variables..."

    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would clean PATH and environment variables"
        return
    fi

    # Clean PATH for current session
    local clean_path
    clean_path=$(echo "$PATH" | sed -e 's/:*[^:]*anaconda[^:]*//g' -e 's/:*[^:]*miniconda[^:]*//g' -e 's/:*[^:]*miniforge[^:]*//g' -e 's/:*[^:]*mambaforge[^:]*//g' -e 's/^://g' -e 's/:$//g' -e 's/::/:/g')
    export PATH="$clean_path"

    # Unset conda/mamba related environment variables
    unset CONDA_DEFAULT_ENV 2>/dev/null || true
    unset CONDA_EXE 2>/dev/null || true
    unset CONDA_PREFIX 2>/dev/null || true
    unset CONDA_PYTHON_EXE 2>/dev/null || true
    unset CONDA_SHLVL 2>/dev/null || true
    unset MAMBA_EXE 2>/dev/null || true
    unset MAMBA_ROOT_PREFIX 2>/dev/null || true
    unset CONDA_PROMPT_MODIFIER 2>/dev/null || true

    # Kill any remaining conda/mamba processes
    pkill -f conda 2>/dev/null || true
    pkill -f mamba 2>/dev/null || true

    # Clear bash/zsh hash table
    hash -r 2>/dev/null || true

    print_info "Environment cleaned"
}

verify_removal() {
    print_info "Verifying removal..."
    [[ $DRY_RUN == true ]] && { print_dry_run "Would verify the uninstallation process worked..."; return 0; }

    local issues=0

    # Check if commands still exist
    if exists conda; then
        print_warn "conda command still found in PATH"
        ((++issues))
    fi

    if exists mamba; then
        print_warn "mamba command still found in PATH"
        ((++issues))
    fi

    # Check for remaining directories
    for path in "${CONDA_PATHS[@]}"; do
        if dir_exists "$path"; then
            print_warn "Installation directory still exists: $path"
            ((++issues))
        fi
    done

    if [[ $issues -eq 0 ]]; then
        print_info "✓ Verification passed - no conda/mamba traces found"
        return 0
    else
        print_warn "Verification found $issues remaining items"
        return 1
    fi
}

display_summary() {
    echo ""
    print_info "═══════════════════════════════════════════════════════════════"
    print_info "                 ANACONDA/MAMBA UNINSTALL SUMMARY              "
    print_info "═══════════════════════════════════════════════════════════════"

    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN - No changes were made to your system"
    else
        print_info "Uninstall completed successfully!"
        [[ $NO_BACKUP == false ]] && print_info "Backup created at: $BACKUP_DIR"
    fi

    echo ""
    print_warn "Manual steps to complete the cleanup:"
    cat <<EOF | tee -a "$LOG_FILE"

1. Terminal Restart:
   - Close all terminal windows
   - Open a new terminal session
   - Or run: exec zsh (or exec bash)

2. Verify Removal:
   - conda --version    (should show 'command not found')
   - mamba --version    (should show 'command not found')
   - echo \$PATH        (should not contain conda/mamba paths)
   - env | grep -i conda (should show no conda variables)

3. IDE/Editor Configuration:
   - Update Python interpreter settings in IDEs
   - Remove conda/mamba from PATH in development environments
   - Update any project-specific conda/mamba configurations

4. System Python:
   - Consider installing Python via Homebrew: brew install python
   - Or use system Python: /usr/bin/python3
   - Set up virtual environments with: python3 -m venv myenv

EOF

    if [[ $DRY_RUN == false ]]; then
        print_info "All Anaconda/Mamba components have been removed! 🎉"
        print_info "Your system now has a clean Python environment."
    fi
    echo ""
}

# ──────────────────────────────── CLI Parsing ────────────────────────────────
while (("$#" > 0)); do
    case "$1" in
    --keep-cache)
        KEEP_CACHE=true
        shift
        ;;
    --keep-config)
        KEEP_CONFIG=true
        shift
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --force)
        FORCE=true
        shift
        ;;
    --no-backup)
        NO_BACKUP=true
        shift
        ;;
    -h | --help)
        sed -n '2,38p' "$0"
        exit 0
        ;;
    *)
        error_exit 1 "Unknown flag passed: ${1}"
        ;;
    esac
done

# ────────────────────────────────── Main ─────────────────────────────────────
main() {
    print_info "Starting Miniforge/Mamba installation 🐍"
    log "INFO" "Running ${SCRIPT_NAME} with args: $*"

    check_macos
    detect_installations

    # Show what will be removed
    echo ""
    print_warn "This script will remove:"
    print_warn "• All Anaconda/Miniconda/Miniforge installations"
    print_warn "• All conda environments and packages"
    print_warn "• Mamba and related tools"
    [[ $KEEP_CONFIG == false ]] && print_warn "• Configuration files (.condarc, .mambarc)"
    [[ $KEEP_CACHE == false ]] && print_warn "• Cache directories"
    print_warn "• Shell configuration modifications"
    print_warn "• Installer receipts and logs"
    echo ""

    if [[ $DRY_RUN == true ]]; then
        print_dry_run "DRY RUN MODE - No changes will be made"
    else
        if ! confirm "Do you want to proceed with the uninstall?"; then
            error_exit 2 "Uninstall cancelled by user"
        fi

        create_backup
    fi

    # Execute uninstall steps
    run_anaconda_clean
    remove_installations
    remove_configuration
    remove_cache
    clean_shell_configuration
    remove_receipts
    remove_python_packages
    cleanup_environment

    if verify_removal; then
        display_summary
    else
        error_exit 4 "There was a problem with the uninstalling process. Please see log file: $LOG_FILE."
    fi
}

#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

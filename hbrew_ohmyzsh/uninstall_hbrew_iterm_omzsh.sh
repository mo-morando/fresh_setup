#!/usr/bin/env bash
###############################################################################
# uninstall_terminal_setup.sh
#
# Complete uninstaller for hbrew_iterm_omzsh.sh setup:
#   • Removes Oh-My-Zsh and all custom plugins
#   • Removes Powerlevel10k theme and fonts
#   • Removes iTerm2 color schemes
#   • Optionally removes Homebrew and all packages
#     -This includes iTerm2
#   • Restores original shell configuration
#
# Usage:
#     chmod +x uninstall_terminal_setup.sh
#     ./uninstall_terminal_setup.sh [--keep-homebrew]
#                                   [--keep-fonts]
#                                   [--dry-run]
#                                   [--force]
#
# Flags:
#   --keep-homebrew    Don't uninstall Homebrew or packages
#   --keep-fonts       Don't remove downloaded fonts
#   --dry-run          Show what would be removed without actually removing
#   --force            Skip confirmation prompts
#
# Exit codes:
#   0  – Success
#   1  – Unsupported OS
#   2  – User cancelled
#   3  – Backup failed
#   4  – Uninstall failed
#
# Author:  Michael Morando https://github.com/mo-morando
# License: MIT
###############################################################################

set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────── Colors ──────────────────────────────────
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly NC=$'\033[0m'

# ─────────────────────────────────── Globals ──────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly LOG_FILE="${HOME}/terminal_uninstall.log"
readonly BACKUP_DIR="${HOME}/.terminal_backup_$(date +%Y%m%d_%H%M%S)"

# Paths (matching the original script)
readonly Z_HOME="${HOME}/.oh-my-zsh"
readonly COLOR_DIR="${HOME}/iterm2/colors"
readonly FONT_DIR="${HOME}/Library/Fonts"
readonly Z_CUST="${ZSH_CUSTOM:-${Z_HOME}/custom}"
readonly PL10K_DIR="${Z_CUST}/themes/powerlevel10k"
readonly PL10K_CONF="$HOME/.p10k.zsh"
readonly ZSH_PLUGINS_DIR="${Z_CUST}/plugins/"
readonly BREWFILE="${HOME}/fresh_setup/hbrew_ohmyzsh/Brewfile"

# Flags
DRY_RUN=false
KEEP_HOMEBREW=false
KEEP_FONTS=false
FORCE=false

# Arrays (matching original script)
readonly FONTS=(
    MesloLGS_NF_Regular
    MesloLGS_NF_Bold
    MesloLGS_NF_Italic
    MesloLGS_NF_Bold_Italic
)

readonly ZSH_PLUGINS=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

readonly COLOR_SCHEMES=(
    Afterglow
    Embark
    IC_Orange_PPL
    "Monokai Pro Spectrum"
    "Firefly Traditional"
    CyberpunkScarletProtocol
)

# ────────────────────────────── Helper Functions ─────────────────────────────
log() {
    local level="$1" message="$2" color="${3:-}"
    printf '[%s] %s%s%s %s\n' "$(date '+%F %T')" "${color}" "[${level}]" "${NC}" "${message}" | tee -a "$LOG_FILE"
}

print_info()    { log "INFO" "$1" "${GREEN}"; }
print_warn()    { log "WARNING" "$1" "${YELLOW}"; }
print_error()   { log "ERROR" "$1" "${RED}"; }
print_dry_run() { log "DRY-RUN" "$1" "${BLUE}"; }

error_exit() { print_error "$2"; exit "${1:-1}"; }

exists() { command -v "$1" &>/dev/null; }

dir_exists() {
    print_info "Checking if directory '${1}' exists..."
    [[ -d "${1}" ]]
    # TODO: Verbose?
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
        print_dry_run "Would execute: $(printf '%q ' "$@")"
    else
        print_info "$description"
        "$@"
    fi
}

safe_remove() {
    local path="$1"
    local description="$2"
    
    if [[ -e "$path" ]]; then
        execute_or_dry_run "$description" rm -rf "$path"
        if [[ $DRY_RUN == false && -e "$path" ]]; then
            print_error "Failed to remove: $path"
            return 1
        fi
    else
        print_info "$description (not found, skipping)"
    fi
}

# ───────────────────────────── Backup Functions ────────────────────────────
dump_brewfile() {
    [[ -z "$BACKUP_DIR" ]] && {
        print_error "BACKUP_DIR is not set"
        return 1
    }
    mkdir -p "$BACKUP_DIR" || {
        print_error "Failed to create backup directory: $BACKUP_DIR"
        return 1
    }

    local timestamp
    timestamp=$(date +'%Y%m%d_%H%M%S')
    local brewfile_path="$BACKUP_DIR/Brewfile.$timestamp"

    execute_or_dry_run "Dumping current Homebrew state to $brewfile_path" brew bundle dump --file="$brewfile_path" --force || {
        print_error "brew bundle dump failed"
        return 1
    }

}

create_backup() {
    [[ $DRY_RUN == true ]] && return 0
    
    [[ -z "$BACKUP_DIR" ]] && {
        print_error "BACKUP_DIR is not set"
        return 1
    }
    mkdir -p "$BACKUP_DIR" || {
        print_error "Failed to create backup directory: $BACKUP_DIR"
        return 1
    }
    
    print_info "Backup shell configuration files"
    for file in ~/.zshrc ~/.zprofile ~/.p10k.zsh; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    # Backup Oh-My-Zsh custom directory
    if [[ -d "$Z_CUST" ]]; then
        cp -r "$Z_CUST" "$BACKUP_DIR/oh-my-zsh-custom" 2>/dev/null || true
    fi

    # Backing up currently homebrew state
    dump_brewfile

    print_info "Backup created successfully"
}

# ───────────────────────────── Uninstall Functions ────────────────────────────
check_macos() {
    [[ $OSTYPE == darwin* ]] || error_exit 1 "This script only supports macOS."
}

user_permission() {
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN MODE - No changes will be made"
    else
        if ! confirm "Do you want to proceed with the uninstall?"; then
            error_exit 2 "Uninstall cancelled by user"
        fi  
    fi
}

remove_oh_my_zsh() {
    print_info "Completely removing Oh My Zsh..."
    
    # Remove Oh My Zsh directory
    safe_remove "$Z_HOME" "Removing Oh My Zsh directory"
    
    # Remove Oh My Zsh from shell configuration
    for file in ~/.zshrc ~/.zprofile; do
        if [[ -f "$file" ]]; then
            if [[ $DRY_RUN == true ]]; then
                print_dry_run "Would clean Oh My Zsh configuration from $file"
            else
                # Remove Oh My Zsh configuration lines
                sed -i.bak '/# Path to your oh-my-zsh installation/d' "$file" 2>/dev/null || true
                sed -i.bak '/export ZSH=/d' "$file" 2>/dev/null || true
                sed -i.bak '/source \$ZSH\/oh-my-zsh.sh/d' "$file" 2>/dev/null || true
                sed -i.bak '/ZSH_THEME=/d' "$file" 2>/dev/null || true
                sed -i.bak '/plugins=(/,/)/d' "$file" 2>/dev/null || true
                print_info "Cleaned Oh My Zsh configuration from $file"
            fi
        fi
    done
}

remove_powerlevel10k() {
    print_info "Removing Powerlevel10k theme..."
    
    # Remove Powerlevel10k directory
    safe_remove "${PL10K_DIR:-Z_CUST}/themes/powerlevel10k" "Removing Powerlevel10k theme directory"
    
    # Remove Powerlevel10k configuration
    safe_remove "${PL10K_CONF:-HOME/.p10k.zsh}" "Removing Powerlevel10k configuration"
    
    # Clean from shell configuration
    for file in ~/.zshrc ~/.zprofile; do
        if [[ -f "$file" ]]; then
            if [[ $DRY_RUN == true ]]; then
                print_dry_run "Would clean Powerlevel10k configuration from $file"
            else
                sed -i.bak '/# To customize prompt, run `p10k configure`/d' "$file" 2>/dev/null || true
                sed -i.bak '/\[[ ! -f ~\/.p10k.zsh \]\] || source ~\/.p10k.zsh/d' "$file" 2>/dev/null || true
                print_info "Cleaned Powerlevel10k configuration from $file"
            fi
        fi
    done
}

remove_zsh_plugins() {
    print_info "Removing Oh My Zsh plugins..."
    
    for plugin in "${ZSH_PLUGINS[@]}"; do
        local plugin_dir="${ZSH_PLUGINS_DIR}${plugin}"
        safe_remove "$plugin_dir" "Removing plugin: $plugin"
    done
}

remove_fonts() {
    [[ $KEEP_FONTS == true ]] && { print_info "Keeping fonts (--keep-fonts specified)"; return; }
    
    print_info "Removing Powerlevel10k fonts..."
    
    for font in "${FONTS[@]}"; do
        local font_file="${FONT_DIR}/${font}.ttf"
        safe_remove "$font_file" "Removing font: $font"
    done
}

remove_color_schemes() {
    print_info "Removing iTerm2 color schemes..."
    
    for scheme in "${COLOR_SCHEMES[@]}"; do
        local scheme_file="${COLOR_DIR}/${scheme}.itermcolors"
        safe_remove "$scheme_file" "Removing color scheme: $scheme"
    done
    
    # Remove color directory if empty
    if [[ -d "$COLOR_DIR" ]]; then
        execute_or_dry_run "Removing color directory if empty" rmdir "$COLOR_DIR" 2>/dev/null || true
    fi
}

remove_homebrew() {
    [[ $KEEP_HOMEBREW == true ]] && { print_info "Keeping Homebrew (--keep-homebrew specified)"; return; }
    
    if ! exists brew; then
        print_info "Homebrew not found, skipping removal"
        return
    fi
    
    print_info "Starting full homebrew cleanup..."

    # 1. Uninstall every formula (CLI tools)
    execute_or_dry_run "Uninstalling all homebrew formulae..." \
        brew remove --force "$(brew list --formula)" --ignore-dependencies || true
    
    execute_or_dry_run "Removing orphaned dependencies..." \
        brew autoremove || true

    # 2. Uninstall every cask (GUI apps) with --zap
    execute_or_dry_run "Uninstalling all homebrew casks (apps) and removing their ancillary files..." \
        brew uninstall --cask --force --zap "$(brew list --cask)" || true

    # 3. Run Homebrew cleanup
    execute_or_dry_run "Running brew cleanup to remove caches and old downloads..." \
        brew cleanup || true
    
    # 4. Remove packages from Brewfile if it exists
    if [[ -f "$BREWFILE" ]]; then
        execute_or_dry_run "Cleaning up any Brewfile-managed entries..." \
            brew bundle cleanup --file="$BREWFILE" --force || true
    fi
    
    # 5. Run the official uninstall script
    # if [[ $DRY_RUN == true ]]; then
    #     print_dry_run "Would remove Homebrew installation"
    # else
        print_warn "Removing Homebrew itself—this will delete homebrew directories!"
        if confirm "Are you sure you want to remove homebrew completely?"; then
            execute_or_dry_run "Running Homebrew uninstall script..." \
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true
        else
            print_info "Homebrew removal cancelled"
        fi
    # fi
    
    # 6. Clean Homebrew from shell configuration
    for file in ~/.zshrc ~/.zprofile; do
        if [[ -f "$file" ]]; then
            if [[ $DRY_RUN == true ]]; then
                execute_or_dry_run "Cleaning homebrew configuration from $file" \
                sed -i.bak '/eval.*homebrew.*shellenv/d' "$file" 2>/dev/null || true
                # print_info "Cleaned Homebrew configuration from $file"
            fi
        fi
    done

    print_info "✅ Full Homebrew cleanup complete. Please check /Applications for any leftover .app bundles and ~/Library for remaining support or preference files to delete manually."
}

restore_shell() {
    print_info "Restoring shell to system defaults..."
    
    # Reset shell to system default zsh
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would reset shell configuration"
    else
        # Create a minimal .zshrc if it doesn't exist
        if [[ ! -f ~/.zshrc ]]; then
            cat > ~/.zshrc << 'EOF'
# Basic zsh configuration
autoload -U compinit && compinit
EOF
            print_info "Created minimal .zshrc"
        fi
    fi
}

cleanup_directories() {
    print_info "Cleaning up empty directories..."
    
    # Remove setup directory if empty
    local setup_dir="${HOME}/setup/hbrew_ohmyzsh"
    if [[ -d "$setup_dir" ]]; then
        execute_or_dry_run "Removing setup directory if empty" rmdir "$setup_dir" 2>/dev/null || true
    fi
    
    # Remove parent setup directory if empty
    local parent_setup="${HOME}/setup"
    if [[ -d "$parent_setup" ]]; then
        execute_or_dry_run "Removing parent setup directory if empty" rmdir "$parent_setup" 2>/dev/null || true
    fi
    
    # Remove iterm2 directory if empty
    local iterm_dir="${HOME}/iterm2"
    if [[ -d "$iterm_dir" ]]; then
        execute_or_dry_run "Removing iterm2 directory if empty" rmdir "$iterm_dir" 2>/dev/null || true
    fi
}

verify_removal() {
    print_info "Verifying everything was uninstalled properly"
    [[ $DRY_RUN == true ]] && { print_dry_run "Would verify the uninstallation process worked..."; return 0; }

    issues=0

    dirs_array=(
        COLOR_DIR
        Z_HOME
        PL10K_DIR
        PL10K_CONF
        ZSH_PLUGINS_DIR
        "/Applications/iTerm.app"
    )

    for dir in "${dirs_array[@]}"; do
        if dir_exists "$dir"; then
            print_warn "Directory $dir still exists, Oh My ZSH is likely not uninstalled"
            ((++issues))
        fi
    done

    if exists brew; then
        print_warn ""
        ((++issues))
    fi


    if (( issues = 0 )); then
        print_info "Verification passed - installation successful!"
        return 0
    else
        print_warn "There were $issues number of issues. The uninstallation process failed. Please see log $LOG_FILE"
        return 1
    fi

}

start_message() {
    # Show what will be removed
    echo ""
    print_warn "This script will remove:"
    print_warn "• Oh My Zsh and all plugins"
    print_warn "• Powerlevel10k theme"
    print_warn "• homebrew and all the programs and applications it installed"
    print_warn "• iTerm2 color schemes"
    [[ $KEEP_FONTS == false ]] && print_warn "• Powerlevel10k fonts"
    [[ $KEEP_HOMEBREW == false ]] && { print_warn "• Homebrew and all packages"; print_warn "• This includes iTerm2, VS Code, updated git, updated bash, and Spotify"; }
    echo ""
    
}

display_summary() {
    echo ""
    print_info "═══════════════════════════════════════════════════════════════"
    print_info "                     UNINSTALL SUMMARY                        "
    print_info "═══════════════════════════════════════════════════════════════"
    
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN - No changes were made to your system"
    else
        print_info "Uninstall completed successfully!"
        print_info "Backup created at: $BACKUP_DIR"
    fi
    
    echo ""
    print_warn "Manual steps you may need to complete:"
    cat <<EOF | tee -a "$LOG_FILE"

1. Shell Configuration:
   - Restart your terminal or run: exec zsh
   - You may need to manually clean any remaining configurations

2. If you want to completely reset your terminal:
   - Delete remaining config files: rm ~/.zshrc ~/.zprofile
   - Restart terminal to use system defaults

EOF
    
    if [[ $DRY_RUN == false ]]; then
        print_info "All terminal setup components have been removed! 🎉"
    fi
    echo ""
}

# ──────────────────────────────── CLI Parsing ────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-homebrew) KEEP_HOMEBREW=true; shift ;;
        --keep-fonts)    KEEP_FONTS=true; shift ;;
        --dry-run)       DRY_RUN=true; shift ;;
        --force)         FORCE=true; shift ;;
        -h|--help)       sed -n '2,34p' "$0"; exit 0 ;;
        *)               error_exit 1 "Unknown flag: $1" ;;
    esac
done

# ────────────────────────────────── Main ─────────────────────────────────────
main() {
    print_info "Executing $SCRIPT_NAME"
    print_info "Starting terminal setup uninstall 🗑️"
    
    check_macos
    
    start_message
    user_permission
    create_backup
    
    # Execute uninstall steps
    remove_oh_my_zsh
    remove_powerlevel10k
    remove_zsh_plugins
    remove_fonts
    remove_color_schemes
    remove_homebrew
    restore_shell
    cleanup_directories
    
    if verify_removal; then
        display_summary
    else
        error_exit 5 ""
    fi
}

# Only execute main when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

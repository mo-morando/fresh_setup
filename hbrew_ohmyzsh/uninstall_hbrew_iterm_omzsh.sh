#!/usr/bin/env bash
###############################################################################
# uninstall_terminal_setup.sh
#
# Complete uninstaller for hbrew_iterm_omzsh.sh setup:
#   • Removes Oh-My-Zsh and all custom plugins
#   • Removes Powerlevel10k theme and fonts
#   • Removes iTerm2 color schemes
#   • Optionally removes Homebrew and all packages
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
readonly COLOR_DIR="${HOME}/iterm2/colors"
readonly FONT_DIR="${HOME}/Library/Fonts"
readonly Z_CUST="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
readonly BREWFILE="${HOME}/setup/hbrew_ohmyzsh/Brewfile"

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

die() { print_error "$2"; exit "${1:-1}"; }

exists() { command -v "$1" &>/dev/null; }

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
        print_dry_run "Would execute: $*"
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
create_backup() {
    [[ $DRY_RUN == true ]] && return 0
    
    print_info "Creating backup at: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup shell configuration files
    for file in ~/.zshrc ~/.zprofile ~/.p10k.zsh; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    # Backup Oh-My-Zsh custom directory
    if [[ -d "$Z_CUST" ]]; then
        cp -r "$Z_CUST" "$BACKUP_DIR/oh-my-zsh-custom" 2>/dev/null || true
    fi
    
    print_info "Backup created successfully"
}

# ───────────────────────────── Uninstall Functions ────────────────────────────
check_macos() {
    [[ $OSTYPE == darwin* ]] || die 1 "This script only supports macOS."
}

remove_oh_my_zsh() {
    print_info "Removing Oh My Zsh..."
    
    # Remove Oh My Zsh directory
    safe_remove "$HOME/.oh-my-zsh" "Removing Oh My Zsh directory"
    
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
    safe_remove "${Z_CUST}/themes/powerlevel10k" "Removing Powerlevel10k theme directory"
    
    # Remove Powerlevel10k configuration
    safe_remove "$HOME/.p10k.zsh" "Removing Powerlevel10k configuration"
    
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
        local plugin_dir="${Z_CUST}/plugins/${plugin}"
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
    
    print_info "Removing Homebrew packages and Homebrew itself..."
    
    # Remove packages from Brewfile if it exists
    if [[ -f "$BREWFILE" ]]; then
        if [[ $DRY_RUN == true ]]; then
            print_dry_run "Would remove packages from Brewfile"
        else
            # This will remove all packages listed in the Brewfile
            brew bundle cleanup --file="$BREWFILE" --force || true
        fi
    fi
    
    # Remove Homebrew itself
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would remove Homebrew installation"
    else
        print_warn "Removing Homebrew - this will remove ALL homebrew packages!"
        if confirm "Are you sure you want to remove Homebrew completely?"; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || true
        else
            print_info "Homebrew removal cancelled"
        fi
    fi
    
    # Clean Homebrew from shell configuration
    for file in ~/.zshrc ~/.zprofile; do
        if [[ -f "$file" ]]; then
            if [[ $DRY_RUN == true ]]; then
                print_dry_run "Would clean Homebrew configuration from $file"
            else
                sed -i.bak '/eval.*homebrew.*shellenv/d' "$file" 2>/dev/null || true
                print_info "Cleaned Homebrew configuration from $file"
            fi
        fi
    done
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

1. iTerm2 Configuration:
   - Reset iTerm2 font to system default
   - Remove any imported color schemes manually
   - Reset any custom iTerm2 preferences

2. Shell Configuration:
   - Restart your terminal or run: exec zsh
   - You may need to manually clean any remaining configurations

3. If you want to completely reset your terminal:
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
        *)               die 1 "Unknown flag: $1" ;;
    esac
done

# ────────────────────────────────── Main ─────────────────────────────────────
main() {
    print_info "Starting terminal setup uninstall 🗑️"
    
    check_macos
    
    # Show what will be removed
    echo ""
    print_warn "This script will remove:"
    print_warn "• Oh My Zsh and all plugins"
    print_warn "• Powerlevel10k theme"
    print_warn "• iTerm2 color schemes"
    [[ $KEEP_FONTS == false ]] && print_warn "• Powerlevel10k fonts"
    [[ $KEEP_HOMEBREW == false ]] && print_warn "• Homebrew and all packages"
    echo ""
    
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN MODE - No changes will be made"
    else
        if ! confirm "Do you want to proceed with the uninstall?"; then
            die 2 "Uninstall cancelled by user"
        fi
        
        create_backup
    fi
    
    # Execute uninstall steps
    remove_oh_my_zsh
    remove_powerlevel10k
    remove_zsh_plugins
    remove_fonts
    remove_color_schemes
    remove_homebrew
    restore_shell
    cleanup_directories
    
    display_summary
}

# Only execute main when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

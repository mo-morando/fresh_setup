#!/usr/bin/env bash
###############################################################################
# move_r_files.sh
#
# Professional R directory setup script for macOS:
#   • Copies R configuration and files from setup directory to home
#   • Provides comprehensive logging and error handling
#   • Supports dry-run mode for safe testing
#   • Verifies successful file operations
#
# Usage:
#     chmod +x move_r_files.sh
#     ./move_r_files.sh [--dry-run] [--force]
#
# Flags:
#   --dry-run    Show what would be done without making changes
#   --force      Skip confirmation prompts
#
# Exit codes:
#   0  – Success
#   1  – R directory not found in setup location
#   2  – Verification failed
#   10 – Invalid command line arguments
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
readonly R_MAIN_DIR="${HOME}/fresh_setup/R"
readonly R_DIR="$R_MAIN_DIR/r_files"
readonly LOG_FILE="${HOME}/move_r_files.log"
readonly TARGET_DIR="${HOME}/R"

# Default configuration
DRY_RUN=false
FORCE=false

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

confirm() {
    [[ $FORCE == true ]] && return 0
    local prompt="$1"
    echo -n "${YELLOW}${prompt} [y/N]: ${NC}"
    read -r response
    [[ $response =~ ^[Y/y]$ ]]
}

execute_or_dry_run() {
    local description="$1"
    shift
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "$description"
        # print_detect "Would execute: $*"
        print_dry_run "Would execute: $(printf '%q ' "$@")"
    else
        print_info "$description"
        "$@"
    fi
}

display_success_message() {
    echo ""
    print_info "═══════════════════════════════════════════════════════════════"
    print_info "                   R FILES SETUP COMPLETED                     "
    print_info "═══════════════════════════════════════════════════════════════"
    
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN - No changes were made to your system"
        return
    fi
    
    cat <<EOF | tee -a "$LOG_FILE"

🎉 R directory setup completed successfully!
📂 R files copied to: $TARGET_DIR

💡 Your R configuration and files are now available in your home directory.

📚 Next steps:
   • Launch R or RStudio to verify your setup
   • Check that your packages and configurations are working
   • Review any custom settings that may need adjustment

EOF
    
    print_info "Happy coding with R! 📊✨"
}

# ───────────────────────────── Workflow functions ────────────────────────────
check_source_directory() {
    print_info "🔍 Checking source R directory..."
    
    if [[ ! -d "$R_MAIN_DIR" ]]; then
        error_exit 1 "Main R directory not found: '$R_MAIN_DIR'"
    fi
    
    print_info "✅ Found main source R directory: $R_MAIN_DIR"

    if [[ ! -d "$R_DIR" ]]; then
        error_exit 1 "R subdirectory not found: '$R_DIR'"
    fi
    
    print_info "✅ Found R subdirectory: $R_DIR"
    
    # Show what we found
    local file_count
    file_count=$(find "$R_DIR" -type f | wc -l | tr -d ' ')
    print_detect "Found $file_count files in R directory"
}


copy_r_dir() {
    print_info "📁 Setting up R directory..."
    
    if [[ -d "$TARGET_DIR" ]]; then
        print_warn "R directory already exists: '$TARGET_DIR'"
        if ! confirm "Overwrite existing R directory?"; then
            print_info "Skipping R directory copy (user choice)"
            return 0
        fi
        execute_or_dry_run "Removing existing R directory" rm -rf "$TARGET_DIR"
    fi
    
    execute_or_dry_run "Copying R directory to home directory" cp -pr "$R_DIR" "$TARGET_DIR"
    print_info "✅ R directory copy completed"
}

copy_dot_files() {
    local tar_dir=${1:-${TARGET_DIR}} out_dir="${2:-${HOME}}/"
    if [[ ! -d "$tar_dir" ]]; then
        print_error "Target R directory not found: '$tar_dir'"
    else
        
        if confirm "Do you want to also copy these R dotfiles into your home directory?"; then
        # print_info "Moving R dotfiles to home directory: $HOME"
        find_cmd=(find "${tar_dir}" -maxdepth 1 -type f -name ".*" ! -name "." ! -name "..")
        execute_or_dry_run "Moving R dotfiles to home directory: ${out_dir}" "${find_cmd[@]}" -exec cp -p {} "${out_dir}" \;
        else
            print_warn "R dotfiles will not be moved to home directory. User specific."
        fi
    fi
}



verify_install() {
    print_info "🔍 Verifying R directory setup..."
    
    local issues=0
    
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would verify R directory at: $TARGET_DIR"
        return 0
    fi
    
    # Check if target directory exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Target R directory not found: '$TARGET_DIR'"
        ((++issues))
    else
        print_info "✅ Found target R directory: $TARGET_DIR"
        
        # Count files to verify copy worked
        local source_count target_count
        source_count=$(find "$R_DIR" -type f | wc -l | tr -d ' ')
        target_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')
        
        print_detect "Source files: $source_count, Target files: $target_count"
        
        if [[ "$source_count" != "$target_count" ]]; then
            print_warn "File count mismatch between source and target"
            ((++issues))
        else
            print_info "✅ File count verification passed"
        fi
    fi
    
    if ((issues > 0)); then
        error_exit 2 "Verification failed with $issues issues. See log: '$LOG_FILE'"
    else
        print_info "✅ Verification passed - R directory setup successful!"
        return 0
    fi
}

# ──────────────────────────────── CLI parsing ────────────────────────────────
while (("$#" > 0 )); do
    case "$1" in
        --dry-run)
            DRY_RUN=true;
            shift
            ;;
        --force)
        FORCE=true
        shift
        ;;
    -h | --help)
        sed -n '2,27p' "$0"
        exit 0
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
    # print_info "Starting Miniforge/Mamba installation 🐍"
    print_info "Running ${SCRIPT_NAME} with args: $*"
    echo ""
    echo ""

    check_source_directory
    
    if [[ $DRY_RUN == true ]]; then
        print_info "DRY RUN MODE - No changes will be made"
    else
        if ! confirm "Proceed with R directory setup?"; then
            error_exit 2 "Setup canceled by user"
        fi
    fi
    
    copy_r_dir
    
    if verify_install; then
        display_success_message
    else
        [[ $DRY_RUN == true ]] && print_dry_run "DRY RUN MODE - Nothing was changed."
        error_exit 2 "R directory setup verification failed"
    fi
}

# Only execute main when run, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
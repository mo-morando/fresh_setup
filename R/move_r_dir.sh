#!/usr/bin/env bash
###############################################################################
# move_r_dir.sh
#
# R directory setup and synchronization script for macOS
#
# This script automates the process of copying and verifying a curated R
# configuration and file collection from a centralized “fresh setup” directory
# into the user’s home directory. It provides detailed logging, robust error
# handling, optional dry-run simulation, and confirmation prompts, ensuring
# repeatable, safe workflows when bootstrapping R environments.
#
# FEATURES:
#   • Source directory validation: Confirms both the main and subdirectories
#     exist before proceeding.
#   • Dry-run mode (--dry-run): Simulates every operation, showing exactly
#     what would happen without modifying any files.
#   • Force mode (--force): Skips all interactive confirmation prompts.
#   • Idempotent directory copy: Detects existing target directory,
#     prompts for overwrite, and safely replaces it if confirmed.
#   • Dotfile synchronization: Detects hidden R-related config files in
#     the source directory and optionally copies them into $HOME.
#   • Verification step: Compares source vs. target file counts, reporting
#     mismatches or missing files before final success.
#   • Comprehensive, timestamped logging: All INFO, WARNING, DRY-RUN,
#     DETECT, and ERROR messages are appended to ~/move_r_files.log.
#
# USAGE:
#     chmod +x move_r_files.sh
#     ./move_r_files.sh [--dry-run] [--force]
#
# FLAGS:
#     --dry-run    Only print planned actions; do not modify filesystem.
#     --force      Bypass all “Are you sure?” prompts and proceed.
#     -h, --help   Print this header and exit immediately.
#
# EXIT CODES:
#     0   Success: All steps completed and verified (or dry-run simulated).
#     1   Missing source directory: core or “r_files” subdirectory not found.
#     2   File operation failure: failed to copy or remove directories, or
#         verification detected issues.
#     3   Dotfile sync: target R directory missing when attempting dotfile copy.
#     4   Verification failed after operations completed (post-setup check).
#     10  Invalid CLI argument passed.
#
# ENVIRONMENT:
#     HOME          User’s home directory (for target paths and log file).
#     move_r_files.log
#                   Log file in $HOME capturing all script output.
#
# AUTHOR:
#     Michael Morando <https://github.com/mo-morando>
#
# LICENSE:
#     MIT License — see LICENSE file or https://opensource.org/licenses/MIT
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
readonly LOG_FILE="${HOME}/move_r_files.log"

readonly R_MAIN_DIR="${HOME}/fresh_setup/R"
readonly R_DIR="$R_MAIN_DIR/r_files"
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
        return 0
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
    [[ -d "$R_MAIN_DIR" ]] ||
        error_exit 1 "Main R directory not found: '$R_MAIN_DIR'"

    print_info "✅ Found main source R directory: $R_MAIN_DIR"
    [[ -d "$R_DIR" ]] ||
        error_exit 1 "R subdirectory not found: '$R_DIR'"

    # Show what we found
    local file_count
    file_count=$(find "$R_DIR" -type f | wc -l | tr -d ' ')
    print_info "✅ Found R subdirectory: $R_DIR"
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
        execute_or_dry_run "Removing existing R directory" rm -rf "$TARGET_DIR" ||
            error_exit 2 "Failed to remove existing R directory"
    fi

    execute_or_dry_run "Copying R directory to home directory" cp -pr "$R_DIR" "$TARGET_DIR" ||
        error_exit 2 "Failed to copy R directory"

    [[ $DRY_RUN == true ]] || print_info "✅ R directory copy completed"
}

copy_dot_files() {
    local scr_dir=${1:-${TARGET_DIR}}
    local out_dir="${2:-${HOME}}/"
    out_dir="${out_dir%/}"

    if [[ -d "$scr_dir" ]]; then
        # print_info "Moving R dotfiles to home directory: $HOME"

        local dotfiles find_cmd
        find_cmd=(find "${scr_dir}" -maxdepth 1 -type f -name ".*" ! -name "." ! -name "..")
        mapfile -t dotfiles < <("${find_cmd[@]}")

        if [[ "${#dotfiles[@]}" -eq 0 ]]; then
            print_warn "No R dotifles found in '${scr_dir}'"
            return 0
        fi

        if confirm "Do you want to also copy these R dotfiles into your home directory?"; then
            for file in "${dotfiles[@]}"; do
                execute_or_dry_run "Moving R dotfiles to home directory: ${out_dir}" \
                    cp -p "${file}" "${out_dir}/" || print_warn "Failed to move R dotfile $(basename "$file") to home directory"
            done
        # execute_or_dry_run "Moving R dotfiles to home directory: ${out_dir}" "${find_cmd[@]}" -exec cp -p {} "${out_dir}" \;
        else
            print_warn "R dotfiles will not be moved to home directory. User specific."
            return 0
        fi
    else
        error_exit 3 "Target R directory not found: '$scr_dir'"

    fi

    # Verify that files were transferred
    [[ "$DRY_RUN" == TRUE ]] && {
        print_dry_run "In DRY-RUN, skipping R dotfile transfer verification"
        return 0
    }
    # local missing=0
    local filename new_file
    for file in "${dotfiles[@]}"; do
        filename=$(basename "${file}")
        new_file="${out_dir}"/"${filename}"
        if [[ -e "${new_file}" ]]; then
            print_detect "R dotfile was successfully copied to ${new_file}!"
        else
            print_warn "R dotfile '${filename}' was not successfully copied"
        fi
    done
}

verify_install() {
    print_info "🔍 Verifying R directory setup..."
    if [[ $DRY_RUN == true ]]; then
        print_dry_run "Would verify R directory at: $TARGET_DIR"
        return 0
    fi

    local issues=0

    # Check if target directory exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Target R directory not found: '$TARGET_DIR'"
        ((++issues))
    else
        print_info "✅ Found target R directory: $TARGET_DIR"

        # Count files to verify copy worked
        local source_count target_count
        source_count=$(find "$R_DIR" -type f | wc -l | tr -d ' ') ||
            print_warn "Failed to count files in $R_DIR"
        target_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ') ||
            print_warn "Failed to count files in $TARGET_DIR"

        print_detect "Source files: $source_count, Target files: $target_count"

        if [[ -z "$source_count" || -z "$target_count" ]]; then
            print_warn "Unable to verify file counts due to errors"
            ((++issues))
        elif [[ "$source_count" != "$target_count" ]]; then
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
while (("$#" > 0)); do
    case "$1" in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --force)
        FORCE=true
        shift
        ;;
    -h | --help)
        sed -n '2,56p' "$0"
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
    copy_dot_files "${TARGET_DIR}" "${HOME}"

    if verify_install; then
        display_success_message
    else
        [[ $DRY_RUN == true ]] && print_dry_run "DRY RUN MODE - Nothing was changed."
        error_exit 4 "R directory setup verification failed"
    fi
}

# Only execute main when run, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

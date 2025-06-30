#!/bin/bash

set -e # Exit on any error

echo "🥳 Starting Terminal Setup! 🎉"
echo

# Colors for outputs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Functions to print colored outputs
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error_exit(){
    ERROR_CODE=$?
    echo -e "${RED}[✗]${NC} $1" >&2
    echo -e "${RED}Error code: ${ERROR_CODE}${NC}" >&2
    # exit 1
}

# Final print message
print_final() {
    print_status "✨ Setup completed successfully!"
    print_warning "Please complete the following manual steps:"
    echo "1. Restart iTerm2 or open a new terminal window"
    echo "2. Run 'p10k configure' to customize your prompt"
    echo "3. Import the Dracula color scheme:"
    echo "   - Press ⌘+i in iTerm2"
    echo "   - Go to Colors tab > Color Presets > Import"
    echo "   - Select ~/Downloads/iterm2-colors/Dracula.itermcolors"
    echo "   - Choose Dracula from Color Presets"
    echo ""
    print_status "Enjoy your enhanced terminal experience! 🎉"
}

# Confirm you are running a macOS 
if [[ $OSTYPE != "darwin"* ]]; then
    error_exit "This script is design for the macOS. Exiting..."
fi

# Download Homebrew if not installed
if [[ ! -x "$(command -v brew)" ]]; then
    print_status "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Homebrew download failed"

    # Add Homebrew to Path for Apple Silicon Macs
    HB_PATH="/opt/homebrew/bin/brew"
    if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$('"${HB_PATH}"' shellenv)"' >> ~/.zprofile
    eval "$("${HB_PATH}" shellenv)"
    fi
else
    print_warning "Homebrew is already installed."
fi

# Brew install files using a Brewfile
BREWFILE="$HOME/setup/hbrew_ohmyzsh"
if [[ -f "$BREWFILE" ]]; then
    print_status "Installing files from Brewfile..."
    # brew bundle --file="$BREWFILE" || error_exit "Brewfile installation failed"
else
    error_exit "Brewfile not found at '$BREWFILE'. Brewfile required for full installation."
fi

# Install Oh My Zsh if not already installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    print_status "Oh My Zsh is not installed. Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || error_exit "Oh My Zsh download failed"
else
    print_warning "Oh My Zsh is already installed. Skipping installation"
fi

# Install Powerlevel10k Theme
Z_CUST="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PWLV10K_DR="/themes/powerlevel10k"
if [[ ! -d "${Z_CUST}${PWLV10K_DR}" ]]; then
    print_status "Powerlevel10k theme not installed. Installing theme now..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$PWLV10K_DR" || error_exit "Powerlevel10k theme download failed"
else
    print_warning "Powerlevel10k theme already installed. Skipping download."
fi

# Install useful plugins
print_status "Installing zsh plugins..."

# zsh-autosuggestions
# Suggests commands based on history and context.
AUTO_SUG="/plugins/zsh-autosuggestions"
if [[ ! -d "${Z_CUST}${AUTO_SUG}" ]]; then
    print_status "zsh-autosuggestion plugin not installed. Installing..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || error_exit "zsh-autosuggestion did not download"
else
    print_warning "zsh-autosuggestion plugin already installed. Skipping installation..."
fi


# zsh-syntax-highlighting (external)
# Highlights valid commands and flags in real-time.
SYN_HI="/plugins/zsh-syntax-highlighting"
if [[ ! -d "${Z_CUST}${SYN_HI}" ]]; then
    print_status "zsh-syntax-highlighting plugin not installed. Installing..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || error_exit "zsh-syntax-highlighting did not download"
else
    print_warning "zsh-syntax-highlighting plugin already installed. Skipping installation..."
fi

# history-substring-search (external)
# Search command history by typing a substring.
HSUB_SRH="/plugins/zsh-history-substring-search"
if [[ ! -d "${Z_CUST}${HSUB_SRH}" ]]; then
    print_status "zsh-history-substring-search zsh plugin not installed. Installing..."
    git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search || error_exit "zsh-history-substring-search did not download"
else
    print_warning "zsh-history-substring-search zsh plugin already installed. Skipping installation..."
fi

# Download iTerm2 color scheme I like
CLR_SCH="${HOME}/iterm2/colors"
if [[ ! -d "$CLR_SCH" ]]; then
    print_status "Creating iTerm2 color directory at: '"${CLR_SCH}"'"
    mkdir -p "${CLR_SCH}"
    color_list=(Afterglow Embark IC_Orange_PPL Monokai%20Pro%20Spectrum Firefly%20Traditional CyberpunkScarletProtocol)
    base_url="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/"
    for color in "${color_list[@]}"; do
        url="${base_url}${color}".itermcolors
        out_file="${CLR_SCH}"/"${color}".itermcolors
        print_status "Downloading color scheme: "${color}""
        curl -L "${url}" -o "${out_file}" || error_exit "Download failed : "${url}""
    done 
else
    print_warning "'"${CLR_SCH}"' directory already exists, but did not check for specific color schemes. Skipping color scheme downloads."
fi

echo
print_final
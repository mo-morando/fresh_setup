#!/bin/bash

# Fuction to handle errors
error_exit() {
    err_code=$?
    echo "❌ Error: $1" >&2
    echo "❌ Error code: $err_code" >&2
    exit 1
}

# Function for final success message
SHELL_NAME=$(basename "$SHELL")
INSTALL_PATH="$HOME/miniforge3"
final_success() {
    echo "------------------------------------------------------------"
    echo "🎉 Installation completed successfully!"
    rm -f "$INSTALLER"  # Clean up installer file
    echo "📂 Miniforge installed to: $INSTALL_PATH"
    echo
    echo "🚀 You can now use mamba or conda to manage your Python environments and packages."
    echo
    echo "💡 You may need to restart your command line interface or run:"
    echo "   conda init $SHELL_NAME"  # Automatically detect the shell
    echo "   to fully initialize Miniforge for your shell."
    echo "------------------------------------------------------------"
    exit 0
}

echo "🔍 Detecting your operating system and architecture..."
OS=$(uname) || error_exit "Failed to detect OS"
ARCH=$(uname -m) || error_exit "Failed to detect architecture"
echo "  ✅ Operating System: $OS"
echo "  ✅ Architecture: $ARCH"

INSTALLER="Miniforge3-$OS-$ARCH.sh"
echo "  📝 Installer needed filename: $INSTALLER"

if [[ ! -f "$INSTALLER" ]]; then
    echo "  🕵️‍♀️ Installer file not found..."
    echo "📥 Downloading Miniforge installer..."
    curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/${INSTALLER}" || error_exit "Download failed"
    echo "✅ Download complete: $INSTALLER"
else 
    echo "✅ Installer already exists, skipping download."
fi

if [[ ! -f "$INSTALLER" ]]; then
    error_exit "Installer file not found: $INSTALLER"
fi

echo "📦 Installing Miniforge..."
if bash "$INSTALLER" -b -p "$INSTALL_PATH"; then
    # Optional: Check if mamba or conda was installed
    if [[ -x "$INSTALL_PATH/bin/mamba" ]] || [[ -x "$INSTALL_PATH/bin/conda" ]]; then
        final_success
    else
        error_exit "Installation completed but mamba/conda not found in $INSTALL_PATH/bin"
    fi
else
    error_exit "💣 Installation failed"
fi
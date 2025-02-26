#!/bin/bash

# This script installs cscs-cl and configures the user.env path

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install cscs-cl to /usr/local/bin
echo "Installing cscs-cl..."
curl -sL https://raw.githubusercontent.com/swiss-ai/reasoning_getting-started/main/cscs-cl | sudo install /dev/stdin /usr/local/bin/cscs-cl

# Update the user.env path in cscs-cl
echo "Configuring user.env path..."
sudo sed -i.bak "s|local user_env=.*|local user_env=\"${SCRIPT_DIR}/user.env\"|" /usr/local/bin/cscs-cl
sudo rm -f /usr/local/bin/cscs-cl.bak

echo "Setup complete! You can now use the \`cscs-cl\` command. Configuration location: ${SCRIPT_DIR}/user.env"

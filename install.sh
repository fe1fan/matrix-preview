#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Get real user (not root)
REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" = "root" ]; then
    echo "Error: Cannot determine the actual user"
    exit 1
fi
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Help message
print_usage() {
    echo "Usage:"
    echo "  Install Server: $0 server"
    echo "  Install Monitor: $0 monitor --url <your-server-url>"
    exit 1
}

# Parse arguments
COMPONENT=""
URL=""

case "$1" in
    server)
        COMPONENT="server"
        ;;
    monitor)
        COMPONENT="monitor"
        if [ "$2" != "--url" ] || [ -z "$3" ]; then
            echo "Error: Monitor installation requires a server url"
            print_usage
        fi
        URL="$3"
        ;;
    *)
        print_usage
        ;;
esac

# Detect architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Configuration
REMOTE_BASE_URL="https://github.com/fe1fan/matrix-preview/releases/download/preview/"  # TODO: Replace with actual URL
VERSION="latest"  # TODO: Replace with version handling logic if needed
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/matrix"
USER_CONFIG_DIR="${REAL_HOME}/.config/matrix"

# Create necessary directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${USER_CONFIG_DIR}"
chown -R "${REAL_USER}:${REAL_USER}" "${USER_CONFIG_DIR}"

install_server() {
    echo "Installing Matrix Server..."
    # Download and install binary
    curl -L "${REMOTE_BASE_URL}/matrix-server-${ARCH}" -o "${INSTALL_DIR}/matrix-server"
    chmod +x "${INSTALL_DIR}/matrix-server"

    # Create systemd service
    cat > /etc/systemd/system/matrix-server.service << EOF
[Unit]
Description=Matrix Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/matrix-server
Restart=always
User=${REAL_USER}
Environment=CONFIG_DIR=${CONFIG_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable matrix-server.service
    systemctl start matrix-server.service

    echo "Matrix Server has been installed and service is running."
}

install_monitor() {
    echo "Installing Matrix Monitor..."
    # Download and install binary
    curl -L "${REMOTE_BASE_URL}/matrix-monitor-${ARCH}" -o "${INSTALL_DIR}/matrix-monitor"
    chmod +x "${INSTALL_DIR}/matrix-monitor"

    # Create monitor config with url
    mkdir -p "${CONFIG_DIR}/monitor"
    cat > "${CONFIG_DIR}/monitor/config.json" << EOF
{
    "url": "${URL}"
}
EOF

    # Create systemd service
    cat > /etc/systemd/system/matrix-monitor.service << EOF
[Unit]
Description=Matrix Monitor
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/matrix-monitor
Restart=always
User=${REAL_USER}
Environment=CONFIG_DIR=${CONFIG_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable matrix-monitor.service
    systemctl start matrix-monitor.service

    echo "Matrix Monitor has been installed and service is running."
    echo "Monitor configuration is located at ${CONFIG_DIR}/monitor/config.json"
}

# Install selected component
case ${COMPONENT} in
    server)
        install_server
        ;;
    monitor)
        install_monitor
        ;;
esac

# Copy configuration files if they exist in the current directory
if [ -d "./settings_json" ]; then
    cp -r ./settings_json/* "${CONFIG_DIR}/"
    cp -r ./settings_json/* "${USER_CONFIG_DIR}/"
fi

echo "Installation completed successfully!"
echo "Matrix Server and Monitor have been installed and services are running."
echo "Configuration files are located in ${CONFIG_DIR} and ${USER_CONFIG_DIR}"

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
    echo "  Uninstall Server: $0 server"
    echo "  Uninstall Monitor: $0 monitor"
    exit 1
}

# Parse arguments
COMPONENT="$1"
case ${COMPONENT} in
    server|monitor)
        ;;
    *)
        print_usage
        ;;
esac

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/matrix"
USER_CONFIG_DIR="${REAL_HOME}/.config/matrix"

uninstall_server() {
    echo "Uninstalling Matrix Server..."

    # Stop and disable service
    if systemctl is-active --quiet matrix-server.service; then
        systemctl stop matrix-server.service
    fi
    if systemctl is-enabled --quiet matrix-server.service; then
        systemctl disable matrix-server.service
    fi

    # Remove service file
    rm -f /etc/systemd/system/matrix-server.service

    # Remove binary
    rm -f "${INSTALL_DIR}/matrix-server"

    # Clean up server specific config if exists
    rm -rf "${CONFIG_DIR}/server"
    rm -rf "${USER_CONFIG_DIR}/server"

    echo "Matrix Server has been uninstalled."
}

uninstall_monitor() {
    echo "Uninstalling Matrix Monitor..."

    # Stop and disable service
    if systemctl is-active --quiet matrix-monitor.service; then
        systemctl stop matrix-monitor.service
    fi
    if systemctl is-enabled --quiet matrix-monitor.service; then
        systemctl disable matrix-monitor.service
    fi

    # Remove service file
    rm -f /etc/systemd/system/matrix-monitor.service

    # Remove binary and config
    rm -f "${INSTALL_DIR}/matrix-monitor"
    rm -rf "${CONFIG_DIR}/monitor"
    rm -rf "${USER_CONFIG_DIR}/monitor"

    echo "Matrix Monitor has been uninstalled."
}

# Uninstall selected component
case ${COMPONENT} in
    server)
        uninstall_server
        ;;
    monitor)
        uninstall_monitor
        ;;
esac

# Reload systemd
systemctl daemon-reload

# Clean up parent directories if empty
rmdir "${CONFIG_DIR}" 2>/dev/null || true
rmdir "${USER_CONFIG_DIR}" 2>/dev/null || true
rmdir "$(dirname "${USER_CONFIG_DIR}")" 2>/dev/null || true

echo "Uninstallation completed successfully!"

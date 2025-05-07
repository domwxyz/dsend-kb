#!/bin/bash

# Script to install DSend keyboard layout for X11/XKB
# This script requires root privileges

set -e  # Exit on any error

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Installing DSend keyboard layout..."

# Create temporary directory for processing files
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory at $TEMP_DIR"

# Check for local files first (in the same directory as the script)
if [ -f "$SCRIPT_DIR/dsend" ]; then
  echo "Using local dsend file..."
  cp "$SCRIPT_DIR/dsend" "$TEMP_DIR/dsend"
else
  echo "Local dsend file not found, downloading..."
  curl -s -o "$TEMP_DIR/dsend" "https://example.com/dsend"
  if [ ! -f "$TEMP_DIR/dsend" ] || [ ! -s "$TEMP_DIR/dsend" ]; then
    echo "Failed to download dsend file"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

if [ -f "$SCRIPT_DIR/evdev_entry.xml" ]; then
  echo "Using local evdev_entry.xml file..."
  cp "$SCRIPT_DIR/evdev_entry.xml" "$TEMP_DIR/evdev_entry.xml"
else
  echo "Local evdev_entry.xml file not found, downloading..."
  curl -s -o "$TEMP_DIR/evdev_entry.xml" "https://example.com/evdev_entry.xml"
  if [ ! -f "$TEMP_DIR/evdev_entry.xml" ] || [ ! -s "$TEMP_DIR/evdev_entry.xml" ]; then
    echo "Failed to download evdev_entry.xml file"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

echo "Installing symbol file..."
cp "$TEMP_DIR/dsend" /usr/share/X11/xkb/symbols/
chmod 644 /usr/share/X11/xkb/symbols/dsend

EVDEV_PATH="/usr/share/X11/xkb/rules/evdev.xml"

echo "Adding layout to evdev.xml..."
# Find the closing </layoutList> tag and insert DSend layout entry before it
LAYOUT_ENTRY=$(cat "$TEMP_DIR/evdev_entry.xml")
sed -i "/<\/layoutList>/i\\$LAYOUT_ENTRY" "$EVDEV_PATH"

echo "Updating XKB registry..."
if command -v xkbcomp &> /dev/null; then
    xkbcomp -I/usr/share/X11/xkb -R/usr/share/X11/xkb keymap/xorg $DISPLAY 2>/dev/null || true
fi

echo "Cleaning up..."
rm -rf "$TEMP_DIR"

# Ask if user wants to set DSend as default
read -p "Do you want to set DSend as the default keyboard layout? (y/n): " SET_DEFAULT
if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
    echo "Setting DSend as the default keyboard layout..."
    
    # Create localectl config
    if command -v localectl &> /dev/null; then
        # For systems using systemd
        localectl set-x11-keymap dsend
    else
        # For systems not using systemd, update Xorg config
        mkdir -p /etc/X11/xorg.conf.d/
        cat > /etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "dsend"
EndSection
EOF
    fi
    
    # Update console keymap if possible
    if [ -d "/etc/console-setup" ]; then
        sed -i 's/^XKBLAYOUT.*/XKBLAYOUT="dsend"/' /etc/default/keyboard
    fi
    
    echo "Default keyboard layout set to DSend. You may need to log out and back in for changes to take effect."
fi

echo "DSend keyboard layout installed successfully!"
echo "You can select it from your desktop environment's keyboard settings or use:"
echo "  setxkbmap dsend"
echo "to activate it for the current session."

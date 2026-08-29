#!/bin/bash
# Klipper MCU Build Script for BTT SKR Mini E3 V3.0 (STM32G0B1RE)

set -e

echo "=== Pulling latest Klipper and starting compilation ==="
cd ~/klipper

# Clean previous builds
make clean

# Create make configuration
cat << 'EOF' > .config
CONFIG_LOW_LEVEL_OPTIONS=y
CONFIG_MACH_STM32=y
CONFIG_BOARD_DIRECTORY="stm32"
CONFIG_MCU="stm32g0b1xx"
CONFIG_FLASH_SIZE=0x80000
CONFIG_CLOCK_FREQ=64000000
CONFIG_FLASH_APPLICATION_ADDRESS_8000=y
CONFIG_STM32_USB_PA11_PA12=y
EOF

# Build klipper.bin firmware
make

echo ""
echo "=== Compilation Complete! ==="
echo "Firmware file generated at: ~/klipper/out/klipper.bin"
echo ""
echo "=== MCU USB Device Discovery ==="
ls -la /dev/serial/by-id/ || echo "No USB serial devices found yet. Connect SKR board to Pi via USB."

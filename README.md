# SYSTEM ARCHITECTURE & PROJECT OVERVIEW: CR-10S UPGRADE

## 1. HARDWARE BASE & POWER TOPOLOGY

* **Base Frame & Kinematics:** Creality CR-10S (300x300mm build volume).
* **Motherboard:** BIGTREETECH SKR Mini E3 V3.0 (STM32G0B1RE).
* **Host Computer:** Raspberry Pi 4B running MainsailOS.
* *Hardware Quirk:* Uses a standard USB-A to USB-C "dumb" charger to bypass the 2018 Pi 4 USB-C resistor flaw.

* **Power Environment (Split Voltage):**
  * **12V Rail:** Powered by the original CR-10S Power Supply Unit (PSU) for heated bed and chassis fans.
  * **24V Rail:** Powered by a 24V DC-DC converter, feeding the SKR Mini E3 V3.0 motherboard and Sprite Extruder Pro toolhead.

---

## 2. WIRING & PINOUT MAPPING (SKR Mini E3 V3.0)

The hardware has been custom-wired to isolate 12V and 24V components safely:

### USB Serial Identifier
```ini
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_4B0031001250564837383520-if00
```

### Extruder / Toolhead (Creality Sprite Extruder Pro - 24V)
* **Heater Cartridge (50W/24V):** Connected to `PC8` (HE0) and `VBB` (+). Custom 18/20 AWG stranded silicone wire.
* **Thermistor:** Connected to `TH0` header (`PA0`).
* **Part Cooling Fan (Blower):** Connected to `FAN0` (`PC6`).
* **Hotend Heatsink Fan:** Connected to `FAN1` (`PC7`). Auto-starts at 50°C.
* *Note:* Toolhead wiring interfaces via an 8-pin GX16-8 Aviation plug at the control box.

### Motion System & Dual Z-Axis
* **X & Y Steppers:** TMC2209 UART drivers (`PC11`/`PC10`). Endstops on `PC0` (X) and `PC1` (Y).
* **Dual Z Steppers:** Driven by the single Z TMC2209 driver (`PB0`/`PC5`) via parallel headers `ZAM` and `ZBM`.
* *Hardware Phase Calibration:* Z2 motor cable modified by swapping **Pin 1 and Pin 3** (Circuit 1 invert) so both lead screws turn in 100% sync.

### Heated Bed & External MOSFET
* **Control Method:** External opto-isolated high-current MOSFET board.
* **Control Wires:** Connected to SKR **`HB+`** (control `+`) and **`HB-`** (control `-`).
* *Diagnostic Status:* Original MOSFET suffered internal transistor short (stuck ON). Replacement 30A wide-input opto-isolated MOSFET module ordered (AliExpress `1005006615585540`). Bed power cable safely disconnected pending module installation.

### Sensors & Probes
* **Filament Sensor:** BTT Smart Filament Sensor (SFS) V2.0.
  * Motion Encoder (3-wire): Plugged into `E0-STOP` (`PC15`).
  * Runout Switch (2-wire): Plugged into `PWR-DET` (`PC12`).
* **Z-Probe:** 3D Touch (BLTouch clone).
  * Header: Dedicated 5-pin `Z-PROBE` header.
  * Servo Control Pin: `PA1`.
  * Trigger Signal Pin: `^PC14`.

---

## 3. SOFTWARE & FIRMWARE ARCHITECTURE

* **Operating System:** MainsailOS (Debian Lite) running on Raspberry Pi 4B.
* **Network:** Static Wi-Fi `192.168.74.2` and mDNS (`3d-print-dorten.local`).
* **Web UI / API:** Mainsail + Moonraker (`http://192.168.74.2`).
* **MCU Firmware Target (`klipper.bin`):**
  * Micro-controller Architecture: `STMicroelectronics STM32`
  * Processor model: `STM32G0B1`
  * Bootloader offset: `8KiB bootloader`
  * Communication interface: `USB (on PA11/PA12)`

---

## 4. PROJECT STATUS & COMMISSIONING CHECKLIST

1. ✅ **Physical Wiring & Pinout Mapping:** Custom JST-XH splicing and 8-pin GX16 aviation connector completed.
2. ✅ **Host Networking:** Raspberry Pi live on Wi-Fi (`192.168.74.2`), passwordless SSH configured for `dorten`.
3. ✅ **Firmware Compilation & Flashing:** SKR Mini E3 V3.0 successfully flashed with Klipper firmware.
4. ✅ **Klipper Connection:** MCU communicating cleanly over USB (`usb-Klipper_stm32g0b1xx_4B0031001250564837383520-if00`).
5. ✅ **Mainsail Web Interface:** Online and functional.
6. ✅ **Toolhead & Motion System:** Toolhead heating verified, dual Z motors synchronized in phase.
7. ⚠️ **Heated Bed MOSFET:** Replacement 30A opto-isolated MOSFET ordered; bed power disconnected for safety until installation.

---

## 5. DIAGNOSTIC G-CODE MACROS

Execute directly from the Mainsail console:

* `STEPPER_BUZZ STEPPER=stepper_z` — Moves Z motors 1mm back/forth to verify sync.
* `STEPPER_BUZZ_ALL` — Sequential move test for X, Y, Z, and Extruder.
* `TEST_SENSORS` — Queries endstops (`QUERY_ENDSTOPS`), probe (`QUERY_PROBE`), and tests BLTouch pin deploy/retract.
* `SYSTEM_READY_TEST` — Full motion choreography and homing suite.

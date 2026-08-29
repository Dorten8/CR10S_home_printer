# SYSTEM ARCHITECTURE & PROJECT OVERVIEW: CR-10S UPGRADE

## 1. HARDWARE BASE & POWER TOPOLOGY

* **Base Frame & Kinematics:** Creality CR-10S (300x300mm build volume).
* **Motherboard:** BIGTREETECH SKR Mini E3 V3.0.
* **Host Computer:** Raspberry Pi 4B (2018 model) running MainsailOS.
* *Hardware Quirk:* Uses a standard USB-A to USB-C "dumb" charger to bypass the 2018 Pi 4 USB-C resistor flaw.

* **Power Environment (Split Voltage):**
  * **12V Rail:** Powered by the original CR-10S Power Supply Unit (PSU).
  * **24V Rail:** Powered by a 24V DC-DC converter, which feeds the SKR Mini E3 V3.0 motherboard and toolhead.

## 2. WIRING & PINOUT MAPPING (SKR Mini E3 V3.0)

The hardware has been custom-wired to isolate 12V and 24V components safely.

### Extruder / Toolhead (Creality Sprite Extruder Pro - 24V)

* **Heater Cartridge (50W/24V):** Connected to `PC8` (HE0) and `VBB` (+). Uses custom 18/20 AWG stranded silicone wire for mechanical fatigue resistance.
* **Thermistor:** Connected to `TH0` header.
* **Part Cooling Fan (Blower):** Connected to `FAN0` (Pin `PC6`).
* **Hotend Heatsink Fan:** Connected to `FAN1` (Pin `PC7`). Configured to turn on automatically at 50°C.
* *Note:* The custom toolhead wiring interfaces via an 8-pin GX16-8 Aviation plug at the control box.

### Heated Bed (300x300mm)

* **Control Method:** Driven by the original CR-10S heavy-duty external MOSFET board.
* **Trigger Signal (-):** Connected to `PC9` (HB / Bed Negative terminal on SKR board).
* **Trigger Power (+):** Spliced directly to the 12V PSU (+) rail to prevent the 24V SKR board from blowing out the 12V optocoupler on the external MOSFET.

### Chassis Cooling (12V)

* **Motherboard & Exhaust Fans:** Wired in *parallel* directly to the 12V PSU. They bypass the motherboard completely and run continuously when main power is on. (Note: Exhaust fan sleeve bearing is seized and pending replacement).

### Sensors & Probes

* **Filament Sensor:** BTT Smart Filament Sensor (SFS) V2.0.
  * Motion Encoder (3-wire): Plugged into `E0-STOP`. Data pin: `PC15`.
  * Runout Switch (2-wire): Plugged into `PWR-DET`. Data pin: `PC12`.

* **Z-Probe:** 3D Touch (BLTouch clone).
  * Location: Plugged into the dedicated 5-pin `Z-PROBE` header.
  * Servo Control Pin: `PA1`.
  * Trigger Signal Pin: `^PC14`.
  * *Note:* The physical Z-axis endstop switch on the frame has been retired.

## 3. SOFTWARE & FIRMWARE ARCHITECTURE

* **Operating System:** MainsailOS (Debian Lite) running on the Raspberry Pi 4B.
* **Network:** Connected to the Main Home Wi-Fi (not IoT) to allow mDNS resolution (`mainsail.local`) and seamless local websocket connections.
* **API Bridge:** Moonraker.
* **Microcontroller Compilation Targets (klipper.bin):**
  * Architecture: STM32G0B1RE
  * Bootloader offset: 8KiB
  * Communication interface: USB (on PA11/PA12 pins)

* **Post-Setup Goals:** Integration of an AI-based spaghetti detection plugin (Obico or OctoEverywhere) funneling through the Moonraker API via a USB webcam.

## 4. CURRENT PROJECT STATUS

1. Physical wiring and custom JST-XH splicing are completed and mapped.
2. Pre-flight multimeter continuity checks have been passed (no dead shorts between 24V and logic rails).
3. Raspberry Pi is flashed with MainsailOS.
4. **Next Immediate Action Required:** Use the CLI agent to ssh into the Pi, compile the `klipper.bin` firmware for the SKR board, extract the MCU serial ID via USB, and generate the master `printer.cfg` file based on the pinout above.

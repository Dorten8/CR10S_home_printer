# SYSTEM ARCHITECTURE & PROJECT OVERVIEW: CR-10S UPGRADE

## 1. HARDWARE BASE & POWER TOPOLOGY

* **Base Frame & Kinematics:** Creality CR-10S (300x300mm build volume).
* **Motherboard:** BIGTREETECH SKR Mini E3 V3.0 (STM32G0B1RE).
* **Host Computer:** Raspberry Pi 4B running MainsailOS.
* *Hardware Quirk:* Uses a standard USB-A to USB-C "dumb" charger to bypass the 2018 Pi 4 USB-C resistor flaw.

### Power Topology (Hybrid 12V / 24V)
This system utilizes a split-voltage topology. High-current chassis components run on the original 12V rail, while the SKR motherboard and Sprite toolhead run on an isolated 24V rail.

```text
+-------------------+
| Original 12V PSU  |
+-------------------+
  |   |   |
  |   |   +-- (12V) -----------------------------------> [ Chassis & Exhaust Fans ]
  |   |
  |   +------ (12V V+) --------------------------------> [ 300x300 Heated Bed ]
  |                                                             |
  +---------- (12V V+ / V-) ----+                               | (Ground Return)
                                v                               |
                       +-------------------+                    |
                       | EXTERNAL MOSFET   |                    |
                       | - DC IN (12V)     |                    |
                       | - HOT BED (-)     |<-------------------+
                       | - CONTROL PORT    |<--+
                       +-------------------+   | (24V PWM Signal / Polarity independent)
                                               |
+-------------------+                          |
| 24V DC-DC Step-Up |                          |
+-------------------+                          |
  |                                            |
  +---------- (24V V+ / V-) ----+              |
                                v              |
                       +-------------------+   |
                       | SKR MINI E3 V3.0  |---+ (HB Port / PC9)
                       +-------------------+
```

---

## 2. MOTHERBOARD & TOOLHEAD ROUTING

Data and power routing from the SKR Mini E3 V3.0 to the toolhead and sensors:

```text
[ SKR MINI E3 V3.0 ]
  |
  |-- Host ---------+--> [ Raspberry Pi 4B ] (MainsailOS via USB-A to USB-C)
  |
  |-- Sprite Pro ---+--> (HE0) ----------> [ Heater Cartridge (24V) ]
  |   Toolhead      |--> (TH0) ----------> [ Thermistor ]
  |                 |--> (FAN0) ---------> [ Part Cooling Blower ]
  |                 |--> (FAN1) ---------> [ Heatsink Fan (Auto @ 50°C) ]
  |                 |--> (E0 Motor) -----> [ Extruder Stepper ]
  |
  |-- Sensors ------+--> (E0-STOP) ------> [ BTT SFS V2.0 - Motion Encoder ]
  |                 |--> (PWR-DET) ------> [ BTT SFS V2.0 - Runout Switch ]
  |
  |-- Z-Probe ------+--> (Z-PROBE Port) -> [ BLTouch / 3D Touch Clone ]
  |   (Unified      |      |-- Pin 1: White  (Trigger Signal)
  |    5-Pin JST)   |      |-- Pin 2: Black  (Trigger Ground)
  |                 |      |-- Pin 3: Yellow (Servo Control)
  |                 |      |-- Pin 4: Red    (5V Power)
  |                 |      |-- Pin 5: Green  (Servo Ground)
  |
  |-- Kinematics ---+--> (X/Y/Z Motors) -> [ Frame Steppers ]
                    |--> (X/Y Stops) ----> [ Physical Endstops ]
```

### USB Serial Identifier
```ini
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_4B0031001250564837383520-if00
```

---

## 3. CRITICAL PINOUT REFERENCE TABLE (Klipper `printer.cfg`)

| Component | SKR Header | Klipper Pin | Notes / Hardware State |
| --- | --- | --- | --- |
| **Heated Bed (MOSFET)** | `HB` | `PC9` | Active HIGH control (`PC9`). Connect control `+` to `HB+`, `-` to `HB-`. |
| **Extruder Heater** | `HE0` | `PC8` | 24V / 50W Cartridge. |
| **Thermistor (Hotend)** | `TH0` | `PA0` | EPCOS 100K B57560G104F. |
| **Part Cooling Fan** | `FAN0` | `PC6` | 24V Blower. |
| **Heatsink Fan** | `FAN1` | `PC7` | 24V Fan (Auto @ 50°C). |
| **BLTouch Trigger** | `Z-PROBE` (Pin 1) | `^PC14` | Pullup `^` required. `Z-DIAG` jumper MUST BE REMOVED. |
| **BLTouch Servo** | `Z-PROBE` (Pin 3) | `PA1` | `Neo-PWR1` jumper MUST REMAIN to provide 5V power. |
| **BTT SFS (Motion)** | `E0-STOP` | `PC15` | Motion Encoder. |
| **BTT SFS (Runout)** | `PWR-DET` | `PC12` | Runout Switch. |

***Notes on Safety:** The external MOSFET maintains galvanic isolation via an internal optocoupler. 12V and 24V domains interact safely via optical signaling.*

---

## 4. HEATED BED MOSFET TROUBLESHOOTING & LOGIC RESOLUTION

### Initial Symptom & Analysis:
* **Initial Observation:** When `PC9` was configured, the bed heated past 30°C target. Changing to `!PC9` caused runaway heating even when Klipper commanded `0% PWM` (37°C → 41°C+).
* **Root Cause 1 (File Path / Permission Lock):** The first time `PC9` was set, Klipper was failing to open `/home/pi/printer_data/config/printer.cfg` due to missing file permissions on the Pi. Klipper was halted in an uninitialized state, leaving MCU pins floating.
* **Root Cause 2 (`!PC9` Inversion):** When permissions were fixed, `!PC9` (inverted) was active. Because `!PC9` is inverted, Klipper outputting `0% PWM` drove the pin HIGH, which forced the Makerbase optocoupler **100% ON**.
* **Final Resolution:** Restored **`heater_pin: PC9`** (non-inverted active HIGH) once permissions were fixed. Klipper now holds `PC9` LOW (0V) when off, and modulates PWM cleanly on demand.
* **Thermal Inertia Note:** The CR-10S 300x300mm aluminum bed has large thermal mass. When heating to a low target (e.g. 30°C), residual stored heat naturally coasts up to ~38°C before slowly radiating down.

---

## 5. SOFTWARE & FIRMWARE ARCHITECTURE

* **Operating System:** MainsailOS (Debian Lite) running on Raspberry Pi 4B.
* **Network (Dual-Profile Wi-Fi):**
  * **Primary (Home):** DHCP Reserved **`192.168.0.108`** (SSID: `WELOVEYOU`, MAC: `DC:A6:32:8D:36:98`).
  * **Fallback (School):** Static `192.168.74.2` / DHCP (SSID: `sensors`).
  * **Local Hostname / mDNS:** `3d-print-dorten.local` (resolves natively across LAN).
* **Web UI / API:**
  * **Mainsail Web UI (Home):** [http://192.168.0.108](http://192.168.0.108) or [http://3d-print-dorten.local](http://3d-print-dorten.local)
  * **Moonraker API:** `http://192.168.0.108:7125`
* **Remote Access (Planned):** NordVPN Meshnet peer-to-peer encrypted WireGuard tunnel for zero-port-forwarding remote management.
* **MCU Firmware Target (`klipper.bin`):**
  * Micro-controller Architecture: `STMicroelectronics STM32`
  * Processor model: `STM32G0B1`
  * Bootloader offset: `8KiB bootloader`
  * Communication interface: `USB (on PA11/PA12)`

---

## 6. CURRENT PROJECT STATUS

1. ✅ **Physical Wiring & Pinout Mapping:** Custom JST-XH splicing and 8-pin GX16 aviation connector completed.
2. ✅ **Host Networking:** Dual Wi-Fi active (Home `WELOVEYOU` @ `192.168.0.108`, School `sensors`), passwordless SSH operational for `dorten`.
3. ✅ **Firmware Compilation & Flashing:** SKR Mini E3 V3.0 successfully flashed with Klipper firmware.
4. ✅ **Klipper Connection:** MCU communicating cleanly over USB (`usb-Klipper_stm32g0b1xx_4B0031001250564837383520-if00`).
5. ✅ **Mainsail Web Interface:** Online and functional.
6. ✅ **Toolhead & Motion System:** Toolhead heating verified, dual Z motors synchronized in phase.
7. ✅ **Heated Bed MOSFET Control:** Hardware optocoupler control verified under active HIGH logic (`heater_pin: PC9`).
8. ✅ **BLTouch Homing & Z-Offset:** Clone-safe config implemented (`^PC14`). Hardware Z-DIAG interference ruled out. Z-Offset calibrated and saved.
9. ✅ **Thermal PID Tuning:** Completed and saved for both Extruder (200°C) and Heated Bed (60°C).
10. ✅ **Bed Mesh Generation:** Initial 5x5 topology map generated and saved to `printer.cfg`.
11. ✅ **Extruder E-Steps Calibration:** Hardware gear jam cleared. Tension set flush. `rotation_distance` tested and verified perfect (100mm requested = 100mm extruded).

---

## 7. DIAGNOSTIC G-CODE MACROS

Execute directly from the Mainsail console:

* `STEPPER_BUZZ STEPPER=stepper_z` — Moves Z motors 1mm back/forth to verify sync.
* `STEPPER_BUZZ_ALL` — Sequential move test for X, Y, Z, and Extruder.
* `TEST_SENSORS` — Queries endstops (`QUERY_ENDSTOPS`), probe (`QUERY_PROBE`), and tests BLTouch pin deploy/retract.
* `SYSTEM_READY_TEST` — Full motion choreography and homing suite.

---

## 8. REMOTE ACCESS STRATEGY: NORDVPN MESHNET

To securely access the Mainsail web UI, stream webcam feeds, and send print jobs from outside the local network without opening dangerous public ports on the router:

### A. Core Architecture
* **Protocol:** NordVPN Meshnet creates an encrypted peer-to-peer WireGuard (`nordlynx`) tunnel between trusted devices (Phone, Laptop, Raspberry Pi).
* **Zero Port-Forwarding:** Inbound router ports (`80`, `7125`, `22`) remain completely closed to the public internet.
* **Direct P2P Routing:** Traffic travels directly peer-to-peer whenever possible with minimal latency.

### B. Setup Procedure on Host (Pi 4B)
1. **Install NordVPN Linux CLI:**
   ```bash
   sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
   sudo usermod -aG nordvpn dorten
   ```
2. **Headless Login:**
   ```bash
   nordvpn login
   # Follow browser authorization link or run: nordvpn login --token <TOKEN>
   ```
3. **Enable Meshnet:**
   ```bash
   nordvpn set meshnet on
   nordvpn set technology nordlynx
   ```
4. **Identify Assigned Meshnet Host:**
   ```bash
   nordvpn meshnet peer list
   ```
   Note the assigned IP (`100.x.x.x`) and Nord private hostname (e.g. `3d-print-dorten-nord.nord`).

### C. Moonraker Whitelist Configuration (`moonraker.conf`)
Ensure Moonraker accepts WebSocket & HTTP API connections from the Meshnet subnet:
```ini
[authorization]
trusted_clients:
    192.168.0.0/16
    10.0.0.0/8
    127.0.0.0/8
    100.64.0.0/10    # NordVPN Meshnet CGNAT address range
cors_domains:
    *.lan
    *.local
    *://*.nord
```

### D. Client Connection (Everywhere)
* **Mobile / Laptop Browser:** Open `http://<meshnet-ip>` or `http://<pi-hostname>.nord` to view Mainsail and camera feeds.
* **OrcaSlicer / PrusaSlicer:** Configure the printer physical host with `http://<meshnet-ip>` for remote one-click slicing and upload.
* **Mobileraker App:** Connect via `http://<meshnet-ip>:7125` for mobile push notifications and print progress.

---

## 9. MANUFACTURER RESOURCES & SCHEMATICS

**Single Source of Truth (SSoT) Repository:**
* [BigTreeTech SKR Mini E3 GitHub Repository](https://github.com/bigtreetech/BIGTREETECH-SKR-mini-E3)

**Hardware Documentation (V3.0 / V3.0.1):**
* [SKR Mini E3 V3.0.1 Pinout PDF (Direct Link)](https://github.com/bigtreetech/BIGTREETECH-SKR-mini-E3/blob/master/hardware/BTT%20SKR%20MINI%20E3%20V3.0.1/Hardware/BTT%20E3%20SKR%20MINI%20V3.0.1_PIN.pdf)
* [SKR Mini E3 V3.0 Pinout PDF](https://github.com/bigtreetech/BIGTREETECH-SKR-mini-E3/blob/master/hardware/BTT%20SKR%20MINI%20E3%20V3.0/Hardware/BTT%20E3%20SKR%20MINI%20V3.0_PIN.pdf)
* [SKR Mini E3 V3.0 User Manual](https://github.com/bigtreetech/BIGTREETECH-SKR-mini-E3/blob/master/hardware/BTT%20SKR%20MINI%20E3%20V3.0/Hardware/BTT%20E3%20SKR%20MINI%20V3.0-manual.pdf)

*(Note: The V3.0 and V3.0.1 boards share identical firmware configuration parameters and primary IO layouts.)*

---




# PPG Method for Heart Rate and Heart Rate Variability Measurement

**Source:** Li X, Hu C, Meng A, Guo Y, Chen Y, Dang R. *Heart rate variability and heart rate monitoring of nurses using PPG and ECG signals during working condition: A pilot study.* Health Sci Rep. 2022;5:e477. doi: 10.1002/hsr2.477
**PMC:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8865060/

---

## 1. What is PPG?

**Photoplethysmography (PPG)** is an optical measurement technique that detects volumetric changes in blood flow in peripheral blood vessels. Each heartbeat causes a pressure wave that slightly expands the vessels — this is captured by shining LED light into the skin and measuring how much is absorbed or reflected by the blood. The resulting waveform encodes the heart's rhythm, from which HR and HRV can be derived.

PPG is non-invasive, lightweight, and well-suited for continuous, long-term wearable monitoring, making it an increasingly popular alternative to ECG in real-world settings.

---

## 2. How PPG Measures Heart Rate (HR)

- The PPG sensor emits light (LED) into subcutaneous tissue.
- Blood volume increases with each heartbeat (systolic pulse), absorbing more light.
- The photodetector captures the cyclical light intensity changes as a waveform.
- Each pulse peak corresponds to one heartbeat.
- **HR** is derived by counting pulse peaks per unit time (beats per minute, bpm).
- The device averages HR data at **1-minute intervals** for analysis.

---

## 3. How PPG Measures Heart Rate Variability (HRV)

HRV is the variation in time intervals between consecutive heartbeats (R-R intervals in ECG; pulse-to-pulse intervals in PPG). It reflects autonomic nervous system activity.

### Frequency Domain Analysis

The study analyzed HRV in the **frequency domain** using **Power Spectral Density (PSD)** analysis:

| Parameter | Frequency Band | Physiological Meaning |
|-----------|---------------|----------------------|
| **LF** (Low Frequency) | 0.04 – 0.15 Hz | Marker of sympathetic + vagal (parasympathetic) activity |
| **HF** (High Frequency) | 0.15 – 0.4 Hz | Marker of vagal (parasympathetic) activity |
| **LF/HF ratio** | — | Sympatho-vagal balance; stress indicator |
| **% LF** = LF/(LF+HF) × 100 | — | Proportion of sympathetic drive in total power |

- Spectral components are calculated in **absolute units (ms²)**.
- HRV parameters are averaged at **5-minute intervals**.
- Both devices applied **PSD-based motion artifact removal** to the raw signal before computing HRV parameters.

---

## 4. Device Specifications — SMARTEAP Stress Tracker WSS-2

| Specification | Detail |
|--------------|--------|
| **Device name** | SMARTEAP Stress Tracker WSS-2 |
| **Manufacturer** | YiCheng Business Management & Consulting Co. Ltd, China |
| **Sensor type** | Two LED optical sensors (PPG) |
| **Sampling rate** | 25 Hz |
| **Data recording interval** | 1-second intervals |
| **Wear positions** | Wrist, lower arm, or upper arm |
| **Study placement** | Upper left arm, proximal biceps brachii |
| **Design goal** | Low-power consumption for long-term continuous monitoring |
| **Output signals** | HR, LF (0.04–0.15 Hz), HF (0.15–0.4 Hz), LF/HF ratio, % LF |

### Key Design Choices
- **Dual LED sensors**: Two sensors improve signal reliability and enable artifact detection/cancellation.
- **25 Hz sampling rate**: Sufficient to resolve the HRV frequency bands of interest (up to 0.4 Hz), while keeping power consumption low for shift-long monitoring.
- **Upper arm placement**: Chosen over wrist to minimize motion artifacts from hand/wrist movements during nursing tasks, while maintaining user comfort.

---

## 5. Signal Processing Pipeline

```
Raw optical signal (LED reflectance @ 25 Hz)
        ↓
Motion artifact removal (Power Spectral Density method)
        ↓
Pulse peak detection → Inter-beat intervals (IBI)
        ↓
HR calculation (averaged per minute)
        ↓
Frequency domain HRV analysis (LF, HF — averaged per 5 min)
        ↓
Output: HR (bpm), LF/HF ratio, % LF
```

---

## 6. Validation Against ECG

The PPG device was validated against the **myBeat WHS-1 ECG device** (Union Tool Co. Ltd., Japan, sampled at 1000 Hz) worn simultaneously on the chest.

| Metric | HR | LF/HF | % LF |
|--------|----|-------|------|
| Correlation (r) | **0.974** (strong) | **0.577** (moderate) | **0.668** (moderate) |
| Mean bias | 0.493 ± 2.209 bpm | 0.153 ± 1.573 | 0.001 ± 0.069 |
| 95% LoA | −4.823 to 3.838 | −2.930 to 3.235 | −0.137 to 0.139 |

**Key findings:**
- **HR**: Excellent agreement with ECG — PPG is highly reliable for HR measurement in real working conditions.
- **HRV (LF/HF, % LF)**: Moderate agreement — acceptable for stress-level assessment but with wider limits of agreement.
- **Night shift** showed slightly lower agreement, likely due to higher motion artifact levels from increased physical activity.

---

## 7. Limitations & Challenges

- **Motion artifacts**: The primary challenge for PPG in active conditions. Arm movements during nursing tasks can corrupt the optical signal. The upper arm placement mitigated but did not eliminate this.
- **Sampling rate trade-off**: 25 Hz is a minimum viable rate for HRV; higher rates (e.g., ECG at 1000 Hz) yield more precise inter-beat intervals.
- **HRV precision**: PPG-derived IBI intervals are less precise than ECG R-R intervals, resulting in moderate (not strong) HRV agreement.
- **Single device model**: Results may not generalize to other PPG devices.

---

## 8. Summary

PPG is a viable wearable technology for **continuous HR monitoring** (strong agreement with ECG) and **HRV-based stress assessment** (moderate agreement) in real working environments. The SMARTEAP WSS-2, using dual LEDs at 25 Hz with PSD-based artifact removal, demonstrates that low-power upper-arm PPG devices can capture clinically meaningful autonomic nervous system data over extended monitoring periods — making them practical tools for occupational health monitoring in high-stress professions such as nursing.

---

## 9. Industry AFE Solutions for PPG-Based HRM & HRV

### 9.1 Texas Instruments — Optical Heart Rate Monitoring (OHRM) on Wearables

**Reference:** SBAA564, Application Brief, Anand Udupa, November 2022 — *Wearable Bio-Sensing Series*
**URL:** https://www.ti.com/lit/ab/sbaa564/sbaa564.pdf

#### PPG Signal Chain Architecture

TI describes a complete signal chain: LED driver → skin/tissue → photodiode (PD) → Analog Front-End (AFE) → MCU (Heart Rate Extraction).

```
LED (pulsed at PRF)
      ↓  (light into skin)
Photodiode (IPD — reflected photocurrent)
      ↓
AFE:  Switch Matrix → TIA → Offset DAC (AACM) → Noise Reduction Filter → MUX → ADC
      ↓
MCU: HR / HRV algorithm
```

Key operating principle:
- The LED is **pulsed at the Pulse Repetition Frequency (PRF)** — turned on only for a short window per cycle to save power. Each LED pulse → one ADC sample.
- **Green LEDs** are typically used for wrist-based HRM (better absorption by oxyhaemoglobin near skin surface).
- Multiple **spatially-separated photodiodes** are combined to mitigate motion artifact effects.
- **Clinical HR frequency range: 0.5–4 Hz** → PPG only needs to capture up to ~4 Hz; **25–100 Hz sampling** is sufficient for continuous HRM.

#### Featured AFE: AFE4432

| Specification | Value | Notes |
|--------------|-------|-------|
| LED drivers | 4 (TX1–TX4) | Programmable current |
| Photodiode inputs | 3 PDs (INP1–3 / INM1–3) | Differential inputs |
| Sampling rate | 1 Hz – 1 kHz | 25–100 Hz typical for HRM |
| Current consumption (RX) | 12 µA | At 25 Hz PRF |
| Peak SNR | 115 dB over 10 Hz BW | Achieves accuracy at low perfusion |
| Ambient light rejection | > 70 dB up to 160 Hz | Removes indoor lighting interference |
| FIFO depth | 160 samples | Reduces MCU wake-up frequency |
| Interface | SPI / I²C | Selectable by pin |
| Package | 1.9 mm × 1.8 mm DSBGA | Ultra-small for wearables |
| Supply (RX / TX) | 1.7–1.9 V / 3.0–5.5 V | |

#### Key Design Features
- **TIA (Transimpedance Amplifier)**: Converts photodiode current to voltage; programmable gain adapts to low-perfusion conditions.
- **Offset DAC (AACM)**: Input offset cancellation removes DC bias from both ambient light and LED background — allows high TIA gain without saturation.
- **Noise Reduction Filter**: Limits optical noise bandwidth, improves SNR at low LED currents (critical for low-power designs).
- **Ambient Light Cancellation**: >70 dB rejection prevents fluorescent/indoor light from corrupting the PPG waveform.
- **Multi-PD combining**: Signals from multiple PDs are fused in the switch matrix to cancel spatially correlated motion noise.

#### Other TI AFEs for PPG
| Device | Key Feature |
|--------|-------------|
| AFE4950 | Simultaneous PPG (24 channels) + ECG (1 lead) acquisition |
| AFE4960P | High-channel PPG for advanced motion artifact cancellation |
| AFE4500 | Combined PPG + ECG + biopotential |
| AFE4404 | Ultra-small, 3-LED + 1-PD, SpO2 + HRM |

---

### 9.2 Analog Devices (ADI / Maxim Integrated) — PPG for HRM & HRV

#### 9.2.1 MAX86141 — Optical Pulse Oximeter and Heart-Rate Sensor

**Product page:** https://www.analog.com/en/products/max86141.html
**Datasheet:** https://www.analog.com/media/en/technical-documentation/data-sheets/max86140-max86141.pdf

| Specification | Value | Notes |
|--------------|-------|-------|
| Optical readout channels | 2 (simultaneous) | Enables multi-wavelength PPG |
| LED drivers | 3 programmable high-current | Supports up to 6 LEDs via external 3×2:1 mux |
| ADC resolution | 19-bit | High dynamic range |
| Dynamic range (HRM) | > 110 dB | Multi-sample mode + on-chip averaging |
| Dynamic range (SpO2) | > 104 dB | |
| FIFO depth | 128 words | Autonomous buffering, reduces SPI traffic |
| Interface | SPI | Standard 4-wire |
| Main supply | 1.8 V | |
| LED driver supply | 3.1 – 5.5 V | |
| Package | 2.048 × 1.848 mm WLP | Wafer-level, 0.4 mm ball pitch |
| Applications | HRM, HRV, SpO2, PTT blood pressure | |

**Key capabilities:**
- **Ambient Light Cancellation (ALC)**: Industry-leading circuit removes strong ambient interference.
- **Picket Fence Detect & Replace**: Detects and corrects corrupted samples caused by motion-induced signal dropout ("picket fence" artifact).
- **Fully autonomous operation**: On-chip FIFO + averaging means the MCU can sleep between reads, saving system power.
- **Inter-beat interval (IBI) output**: Enables HRV calculation directly from the MAX-HEALTH-BAND platform (steps, activity classification, HR, IBI for HRV).

#### 9.2.2 ADPD4100/4101 — Multimodal Sensor Front End

**Product page:** https://www.analog.com/en/products/adpd4100.html
**Datasheet:** https://www.analog.com/media/en/technical-documentation/data-sheets/adpd4100-4101.pdf

| Specification | Value |
|--------------|-------|
| LED stimulators | Up to 8 |
| Current inputs (PD channels) | Up to 8 |
| Sensor modalities | PPG, ECG, BIA (body impedance), resistance, capacitance, temperature |
| Applications | HRM, HRV, stress, SpO2, blood pressure (PTT), hydration, body composition |

**Four operating modes:**
1. **Continuous Connect Mode** — constant LED illumination, for static measurements
2. **Multiple Integration Mode** — pulsed LED with multiple integration windows, improves dynamic range
3. **Float Mode** — ultra-low-power mode for always-on HR monitoring
4. **Digital Integration Mode** — digital accumulation of multiple pulses, improves SNR

#### 9.2.3 ADI Beat-to-Beat Detection Algorithm for HRV (PRV)

**Technical Article:** *Robust Beat-to-Beat Detection Algorithm for Pulse Rate Variability Analysis from Wrist PPG Signals*
**URL:** https://www.analog.com/en/resources/technical-articles/robust-beat-to-beat-detection-algorithm-for-pulse-rate-variability-analysis.html

ADI developed a combined **peak and onset (foot) detection algorithm** for extracting beat-to-beat pulse intervals (PPI) from wrist PPG signals — the basis for Pulse Rate Variability (PRV) as an HRV surrogate.

**Algorithm approach:**
- Detects both the **systolic peak** and the **pulse onset (foot)** of each PPG waveform cycle
- Beat-to-beat intervals derived from onset-to-onset timing (more robust than peak-to-peak, less sensitive to waveform shape changes)
- Validated on large dataset using ADI's **multisensory smartwatch platform**
- Performance: high coverage, high sensitivity, low RMSSD error compared to ECG-derived beat-to-beat intervals

**Why PRV from PPG ≠ HRV from ECG (but is useful):**
- PPG pulse intervals (PPI) reflect the same autonomic modulation as ECG R-R intervals
- Wrist PPG adds pulse transit time variability and motion noise vs. chest ECG
- ADI's algorithm mitigates this via robust onset detection and signal quality gating

---

### 9.3 Why Multi-LED is Necessary for Precision HRM & HRV

A single LED/single PD PPG sensor (like the SMARTEAP WSS-2's 2-LED design) is sufficient for basic HR monitoring under controlled conditions. However, **precision HRM and HRV in real-world active use requires 3–4 LEDs and multiple photodiodes**. Here's why:

#### Motion Artifact: The Core Problem
Motion moves the sensor relative to the tissue, causing large mechanical displacement artifacts in the optical signal — often 10–100× larger than the actual PPG pulse. A single photodiode cannot distinguish between motion-induced light variation and the true blood-volume pulse.

#### How Multiple LEDs & PDs Solve This

| Technique | How it works | LEDs/PDs needed |
|-----------|-------------|-----------------|
| **Multi-wavelength redundancy** | Green (530 nm) penetrates shallower than red/IR (660/940 nm). Using 2–3 wavelengths provides redundant pulse signals; the cleanest channel is selected or fused | 2–3 LEDs (green + red + IR) |
| **Spatial PD combining** | Multiple PDs at different positions around the LED pick up light scattered through different tissue paths. Motion-correlated noise is common across PDs and cancels when subtracted; true pulse signal is coherent | 2–3 PDs |
| **Differential LED subtraction** | Alternating LED pulses (LED1 on → sample, LED2 on → sample, both off → ambient sample). Subtracting ambient from each LED reading cancels ambient light interference | 3+ LEDs (including "off" ambient cycle) |
| **Accelerometer fusion** | 3-axis accelerometer provides motion reference; its signal is regressed out of the PPG (adaptive filtering). Required for HRV-grade accuracy during activity | Any PPG + accel |

#### Minimum Configuration Recommendations (Industry Standard)

| Use Case | Min LEDs | Min PDs | Sampling Rate | Notes |
|----------|----------|---------|---------------|-------|
| Basic HR (resting) | 1 green | 1 | 25 Hz | Adequate only in low-motion scenarios |
| HR during activity | 2–3 green | 2 | 50–100 Hz | Spatial PD combining needed |
| HRV (resting) | 2 green | 1–2 | 100–250 Hz | IBI accuracy requires higher rate |
| HRV (active) + SpO2 | 3 (green + red + IR) | 2 | 100–250 Hz | Multi-wavelength + spatial combining |

Both TI (AFE4432: 4 LEDs, 3 PDs) and ADI (MAX86141: 3 LEDs, 2 PDs) are designed with these minimums in mind for **production-grade wearables**. The SMARTEAP WSS-2's dual-LED design compensates with **upper-arm placement** (lower motion vs. wrist) and **PSD-based artifact removal** in firmware.

---

### 9.4 Industry Design Principles for PPG HRM/HRV

Based on TI and ADI guidance, the following practices are standard in commercial PPG wearable design:

1. **Pulsed LED operation**: Pulse at PRF (25–100 Hz) rather than continuous illumination — reduces average current by 100–1000×, enabling multi-day battery life.

2. **3+ LEDs + 2+ PDs minimum for active HRV**: Single-channel designs cannot adequately reject motion artifacts for beat-to-beat IBI accuracy during movement.

3. **Ambient light cancellation in hardware**: Fluorescent/outdoor light can completely swamp the PPG AC signal. Hardware ALC (>70 dB) is non-negotiable; software-only correction is insufficient.

4. **DC offset cancellation (offset DAC)**: The DC component (ambient + LED background) is ~100× larger than the AC PPG pulse (~1% modulation depth). An offset DAC before the TIA removes DC, allowing maximum gain on the AC pulse signal.

5. **Sampling rate 100–250 Hz for HRV**: 25 Hz is minimum for HR but gives ~40 ms IBI quantization error. HRV metrics like RMSSD require <5 ms IBI resolution → 200+ Hz is preferred.

6. **Beat onset detection over peak detection**: The pulse foot (onset) is more temporally stable than the peak for IBI calculation — peak position shifts with waveform morphology changes from vasoconstriction, posture, and blood pressure variation.

7. **FIFO buffering on-chip**: Allows MCU deep sleep between reads (128–160 sample FIFO), cutting system power 10–100× compared to polling at sample rate.

---

**References:**
- Texas Instruments SBAA564: [Optical Heart Rate Monitoring (OHRM) on Wearables](https://www.ti.com/lit/ab/sbaa564/sbaa564.pdf) (Nov 2022)
- Texas Instruments: [AFE4404 Product Page](https://www.ti.com/product/AFE4404)
- Texas Instruments: [AFE4950 Product Page](https://www.ti.com/product/AFE4950)
- Analog Devices: [MAX86141 Product Page](https://www.analog.com/en/products/max86141.html)
- Analog Devices: [ADPD4100 Product Page](https://www.analog.com/en/products/adpd4100.html)
- Analog Devices: [Robust Beat-to-Beat Detection Algorithm for PRV from Wrist PPG](https://www.analog.com/en/resources/technical-articles/robust-beat-to-beat-detection-algorithm-for-pulse-rate-variability-analysis.html)
- Analog Devices: [Guidelines to Enhancing Heart-Rate Monitoring Performance](https://www.analog.com/en/resources/technical-articles/guidelines-to-enhancing-the-heartrate-monitoring-performance-of-biosensing-wearables.html)
- Analog Devices: [Maxim Integrated PPG Algorithms Specifications](https://www.analog.com/en/resources/app-notes/maxim-integrated-ppg-algorithms-specifications.html)

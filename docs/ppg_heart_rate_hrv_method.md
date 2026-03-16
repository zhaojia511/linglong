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

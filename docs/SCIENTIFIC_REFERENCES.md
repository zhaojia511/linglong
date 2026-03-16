# Scientific References and Methodology

This document provides the scientific foundation for all calculations, metrics, and methodologies used in the Linglong Heart Rate Monitor Platform. All algorithms and concepts are based on peer-reviewed research and established sports science principles.

---

## Core Textbooks

### 1. NSCA's Essentials of Strength Training and Conditioning
**Haff, G. G., & Triplett, N. T. (Eds.). (2016).** *Essentials of strength training and conditioning* (4th ed.). Human Kinetics.

**Used for:**
- Training load principles
- Periodization concepts
- Recovery and adaptation science
- Overtraining prevention strategies

### 2. ACSM's Guidelines for Exercise Testing and Prescription
**American College of Sports Medicine. (2021).** *ACSM's guidelines for exercise testing and prescription* (11th ed.). Wolters Kluwer.

**Used for:**
- Heart rate zone calculations
- Maximum heart rate estimation (220 - age)
- Heart rate reserve (Karvonen method)
- VO2max estimation protocols
- Cardiovascular fitness classifications

### 3. Heart Rate Variability: Standards of Measurement
**Task Force of the European Society of Cardiology and the North American Society of Pacing and Electrophysiology. (1996).** Heart rate variability: Standards of measurement, physiological interpretation, and clinical use. *Circulation*, 93(5), 1043-1065.

**Used for:**
- HRV metrics definitions (SDNN, RMSSD, pNN50)
- Time-domain analysis methods
- Frequency-domain analysis (LF, HF, LF/HF ratio)
- HRV data collection standards
- Interpretation guidelines

---

## Training Load and Monitoring

### TRIMP (Training Impulse)

#### 1. Edwards TRIMP (Zone-Based Method)
**Edwards, S. (1993).** *The heart rate monitor book.* Polar Electro Oy.

**Formula:**
```
TRIMP = Σ(time_in_zone × zone_weight)
Zone weights: Zone1=1, Zone2=2, Zone3=3, Zone4=4, Zone5=5
```

**Used for:**
- Session training load quantification
- Zone-based training load calculation
- Simple, practical TRIMP method

#### 2. Banister TRIMP (Exponential Method)
**Banister, E. W. (1991).** Modeling elite athletic performance. In J. D. MacDougall, H. A. Wenger, & H. J. Green (Eds.), *Physiological testing of elite athletes* (pp. 403-424). Human Kinetics.

**Formula:**
```
TRIMP = duration × ΔHR × 0.64e^(1.92×ΔHR)
where ΔHR = (HR_exercise - HR_rest) / (HR_max - HR_rest)
```

**Used for:**
- Individual training load assessment
- Exponential weighting of intensity
- Research-grade TRIMP calculation

#### 3. Lucia TRIMP (3-Zone Method)
**Lucia, A., Hoyos, J., Santalla, A., Earnest, C., & Chicharro, J. L. (2003).** Tour de France versus Vuelta a España: Which is harder? *Medicine & Science in Sports & Exercise*, 35(5), 872-878.

**Formula:**
```
TRIMP = Σ(time_in_zone × zone_factor)
Zone1 (<VT1): factor = 1
Zone2 (VT1-VT2): factor = 2
Zone3 (>VT2): factor = 3
```

**Used for:**
- Elite athlete training load
- Simplified intensity zones
- Professional cycling methodology

---

## Acute:Chronic Workload Ratio (ACWR)

### Primary Reference
**Gabbett, T. J. (2016).** The training—injury prevention paradox: Should athletes be training smarter and harder? *British Journal of Sports Medicine*, 50(5), 273-280.

**Formula:**
```
ACWR = Acute Load (7 days) / Chronic Load (28 days)
```

**Interpretation:**
- ACWR < 0.8: Undertraining, detraining risk
- ACWR 0.8-1.3: "Sweet spot" - optimal training stimulus
- ACWR > 1.5: High injury risk zone

**Used for:**
- Injury risk assessment
- Training load management
- Workload progression monitoring

### Supporting Research
**Blanch, P., & Gabbett, T. J. (2016).** Has the athlete trained enough to return to play safely? The acute:chronic workload ratio permits clinicians to quantify a player's risk of subsequent injury. *British Journal of Sports Medicine*, 50(8), 471-475.

---

## Training Monotony and Strain

**Foster, C. (1998).** Monitoring training in athletes with reference to overtraining syndrome. *Medicine & Science in Sports & Exercise*, 30(7), 1164-1168.

**Formulas:**
```
Training Monotony = Mean daily load / SD of daily load
Training Strain = Total weekly load × Training Monotony
```

**Interpretation:**
- High monotony (>2.0) = lack of training variation
- High strain = risk of overtraining
- Optimal: varied training loads with adequate recovery

**Used for:**
- Overtraining detection
- Training variety assessment
- Long-term monitoring

---

## Heart Rate Variability (HRV)

### Time-Domain Metrics

#### SDNN (Standard Deviation of NN intervals)
**Source:** Task Force (1996)

**Formula:**
```
SDNN = √(Σ(RRᵢ - RR_mean)² / (n-1))
```

**Interpretation:**
- Higher = better autonomic function
- Reflects both sympathetic and parasympathetic activity
- Normal range: 50-100ms (varies by age)

#### RMSSD (Root Mean Square of Successive Differences)
**Source:** Task Force (1996)

**Formula:**
```
RMSSD = √(Σ(RRᵢ₊₁ - RRᵢ)² / (n-1))
```

**Interpretation:**
- Reflects parasympathetic activity
- Higher = better recovery status
- More sensitive to acute changes

#### pNN50
**Source:** Task Force (1996)

**Formula:**
```
pNN50 = (NN50 count / total NN intervals) × 100%
where NN50 = number of successive RR intervals differing by >50ms
```

**Interpretation:**
- Indicates vagal tone
- Higher = better parasympathetic activity

### Frequency-Domain Metrics

**Source:** Task Force (1996)

**Metrics:**
- **LF (Low Frequency):** 0.04-0.15 Hz - mixed sympathetic/parasympathetic
- **HF (High Frequency):** 0.15-0.40 Hz - parasympathetic (vagal)
- **LF/HF Ratio:** Sympathovagal balance indicator

**Used for:**
- Autonomic nervous system assessment
- Recovery status monitoring
- Training readiness evaluation

---

## Heart Rate Zones

### Percentage of Maximum Heart Rate Method
**Source:** ACSM (2021)

**Maximum HR Estimation:**
```
HR_max = 220 - age  (Fox equation, most common)
```

**Standard 5-Zone Model:**
- Zone 1: 50-60% HR_max (Very Light)
- Zone 2: 60-70% HR_max (Light)
- Zone 3: 70-80% HR_max (Moderate)
- Zone 4: 80-90% HR_max (Hard)
- Zone 5: 90-100% HR_max (Maximum)

### Heart Rate Reserve (Karvonen Method)
**Karvonen, J., Kentala, E., & Mustala, O. (1957).** The effects of training on heart rate: A longitudinal study. *Annales Medicinae Experimentalis et Biologiae Fenniae*, 35, 307-315.

**Formula:**
```
Target HR = ((HR_max - HR_rest) × intensity%) + HR_rest
```

**Used for:**
- Individualized zone calculation
- Accounts for resting heart rate
- More accurate than simple % max HR

---

## Cardiovascular Fitness Assessment

### VO2max Estimation from Heart Rate
**Jackson, A. S., Blair, S. N., Mahar, M. T., Wier, L. T., Ross, R. M., & Stuteville, J. E. (1990).** Prediction of functional aerobic capacity without exercise testing. *Medicine & Science in Sports & Exercise*, 22(6), 863-870.

**Non-Exercise VO2max Prediction:**
```
VO2max = 56.363 + (1.921×PA-R) - (0.381×age) - (0.754×BMI) + (10.987×gender)
where: PA-R = physical activity rating, gender: 1=male, 0=female
```

### Fitness Level Classification
**Source:** ACSM (2021)

Age and gender-specific VO2max percentile tables for fitness classification:
- Superior
- Excellent
- Good
- Fair
- Poor
- Very Poor

---

## Recovery and Training Effect

### Heart Rate Recovery
**Cole, C. R., Blackstone, E. H., Pashkow, F. J., Snader, C. E., & Lauer, M. S. (1999).** Heart-rate recovery immediately after exercise as a predictor of mortality. *New England Journal of Medicine*, 341(18), 1351-1357.

**Measurement:**
```
HR Recovery = HR_peak - HR_1min_post
```

**Interpretation:**
- Normal: >12 bpm decrease in first minute
- Abnormal: <12 bpm (associated with increased mortality risk)
- Faster recovery = better cardiovascular fitness

### Training Effect Score
**Firstbeat Technologies. (2014).** Automated fitness level (VO2max) estimation with heart rate and speed data. *White paper*.

**Based on:**
- Session duration
- HR intensity distribution
- Individual fitness level
- Recent training history

**Scale:** 0-5
- 0-0.9: No effect
- 1.0-1.9: Minor effect
- 2.0-2.9: Maintaining effect
- 3.0-3.9: Improving effect
- 4.0-4.9: Highly improving effect
- 5.0: Overreaching

---

## Overtraining and Recovery

### Overtraining Syndrome
**Meeusen, R., Duclos, M., Foster, C., et al. (2013).** Prevention, diagnosis, and treatment of the overtraining syndrome: Joint consensus statement of the European College of Sport Science and the American College of Sports Medicine. *Medicine & Science in Sports & Exercise*, 45(1), 186-205.

**Key Markers:**
- Decreased HRV
- Elevated resting HR
- Prolonged HR recovery
- Decreased performance
- Excessive fatigue

**Used for:**
- Early warning system
- Training adjustment recommendations
- Recovery prescription

### Recovery Time Estimation
**Based on:** ACSM Guidelines and TRIMP methodology

**Simple Model:**
```
Recovery Hours = TRIMP / 10
```

**Advanced Model:** Considers individual fitness, recent training load, and HRV trends

---

## Additional References

### Lactate Threshold
**Faude, O., Kindermann, W., & Meyer, T. (2009).** Lactate threshold concepts: How valid are they? *Sports Medicine*, 39(6), 469-490.

### Periodization
**Bompa, T. O., & Haff, G. G. (2009).** *Periodization: Theory and methodology of training* (5th ed.). Human Kinetics.

### Heart Rate Monitoring Best Practices
**Achten, J., & Jeukendrup, A. E. (2003).** Heart rate monitoring: Applications and limitations. *Sports Medicine*, 33(7), 517-538.

---

## Data Quality and Standards

### RR Interval Recording Standards
**Task Force (1996)** specifies:
- Minimum sampling rate: 250 Hz
- Recording duration: 5 minutes minimum for reliable HRV
- Artifact removal: <5% ectopic beats
- Stationarity: subject at rest or steady-state exercise

### Sensor Accuracy Requirements
**Polar Electro Oy. (2021).** *Precision and accuracy of Polar heart rate sensors.* Technical white paper.

**Standards:**
- HR measurement accuracy: ±1 bpm
- RR interval accuracy: ±1 ms
- Compatible with Bluetooth Heart Rate Service (0x180D)

---

## How References Are Used in Linglong

### Phase 1 (Current - v1.0.0)
- ✅ Basic HR monitoring (ACSM guidelines)
- ✅ Session recording (industry standards)
- ✅ Simple statistics (mean, max, min)

### Phase 2 (v1.1.0 - Planned)
- 🔄 TRIMP calculations (Edwards, Banister, Lucia)
- 🔄 ACWR monitoring (Gabbett)
- 🔄 HRV metrics (Task Force 1996)
- 🔄 Training zones (ACSM, Karvonen)
- 🔄 Recovery assessment (Cole et al.)

### Phase 3 (v2.0.0 - Planned)
- 🔄 Advanced HRV analysis (multiple methods)
- 🔄 Overtraining detection (Meeusen et al.)
- 🔄 VO2max estimation (Jackson et al.)
- 🔄 Training effect (Firstbeat methodology)

---

## Citation Format

For user manual and documentation, use APA 7th edition format as shown above.

For in-app references, use simplified format:
```
"Based on Gabbett (2016) ACWR methodology"
"Calculated using Edwards TRIMP (1993)"
"HRV metrics per Task Force standards (1996)"
```

---

## Updates and Revisions

This reference document will be updated as:
- New features are implemented
- New research becomes available
- Methodologies are refined
- User feedback indicates need for clarification

**Document Version:** 1.0  
**Last Updated:** 2026-01-02  
**Next Review:** Q2 2026

---

## Contact for Academic Collaboration

For researchers interested in using Linglong for studies or contributing to methodology:
- GitHub: [repository_url]
- Email: [research@linglong.project]
- Documentation: support.linglong.project/research

---

## License Note

While the Linglong software is open-source (MIT License), the scientific methodologies and formulas are intellectual property of their respective authors and subject to their original licenses and citations. Users of this software should cite both:
1. The Linglong platform (for implementation)
2. The original research papers (for methodology)

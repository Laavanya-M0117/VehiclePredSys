# KSCST 50th SERIES STUDENT PROJECT PROGRAMME (SPP: 2026–2027)
## PROPOSAL FOR STUDENT PROJECT - FULLY FILLED TEMPLATE
*(Updated with Official KSCST 50th Series Broad Themes & Sub-Themes)*

---

### INSTRUCTIONS FOR MS WORD CLEANUP BEFORE PDF SUBMISSION
*(Follow these exact rules to make your Word document compliant with Rule 8)*

1. **Delete Pages 1 & 2** (The title cover and the 15 bullet instructions). Official submission begins directly with **PART-A: GENERAL INFORMATION**.
2. **Delete Pages 17 & 18** (Bank Account details and QR Code). Page 17 explicitly notes: *(“not to include this page in the project proposal softcopy”)*.
3. **Remove All Prompts, Instructions & Examples in Brackets**:
   - Remove `(Please fill in all details in UPPERCASE LETTERS, except for the Email ID.)`
   - Remove `(Maximum 300 words)`, `(Clearly define the problem...)`, `Example: • To design...`, `Examples: • Hardware... • Software...`
   - Remove `Important Note: KSCST provides only a modest financial grant...`
   - Remove instructional text under Processing Fee Payment.
4. **Font & Formatting Standards**:
   - Heading 1 / Section Titles: **Times New Roman, 12 pt, Bold, UPPERCASE**
   - Body Text: **Times New Roman, 11 pt or 12 pt, Regular, Line Spacing 1.15, Justified**
   - Tables: **Times New Roman, 10 pt or 11 pt**, clean borders.
5. **Mandatory Signatures & Seals**:
   - Student Team Members (Page 11 & 13)
   - Project Guide (Pages 11, 13, 15, 16)
   - Institutional SPP Coordinator (Pages 11, 13, 15, 16)
   - Head of Department (HOD) (Pages 15, 16)
   - Principal / Head of Institution with Official Seal (Page 15)

---

# PART-A: GENERAL INFORMATION

### 1. Project Title:
**VEHICARE: AN AI-BASED VEHICLE PREDICTIVE TRIAGE AND HEALTH INTELLIGENCE SYSTEM USING REAL-TIME DATA FROM OBD-II**

### 2. Keywords (5–8):
`Predictive Maintenance`, `Vehicle Health Monitoring`, `OBD-II Diagnostics`, `Intelligent Triage`, `Long Short-Term Memory (LSTM)`, `Remaining Useful Life (RUL)`, `Internet of Things (IoT)`

### 3. Broad Theme:
*(Chosen from KSCST Official 50th Series Broad Themes List)*

- **1. Theme No.:** 8
- **2. Theme Name:** Sustainable Infrastructure, Smart Cities and Smart Mobility
- **3. Sub-theme / Focus Area:** Smart Mobility, Intelligent Transport Systems (ITS) and Connected Mobility
  *(Note: You can also choose Theme No. 4: Artificial Intelligence, Data Science and Digital Technologies, with Sub-theme: Artificial Intelligence (AI) and Machine Learning (ML))*

### 4. Institution Details:
- **Name of Institution:** ATRIA INSTITUTE OF TECHNOLOGY
- **Course Name:** B.E. (BACHELOR OF ENGINEERING)
- **Department Name:** DEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING
- **Affiliated University:** VISVESVARAYA TECHNOLOGICAL UNIVERSITY (VTU), BELAGAVI
- **District of Your Institution:** BENGALURU URBAN
- **Complete Postal Address with Pin Code:** ASKB CAMPUS, 1ST MAIN ROAD, AGS COLONY, ANANDNAGAR, HEBBAL, BENGALURU, KARNATAKA – 560024

### 5. Project Guide Details:
- **Project Guide Name:** PROF. HARI KISHAN K R
- **Project Guide Designation:** ASSISTANT PROFESSOR
- **Project Guide Department:** DEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING
- **Project Guide Email ID:** hkkr.hari@gmail.com
- **Project Guide Mobile Number:** [Insert Guide Mobile Number]
- **Project Co-Guide (if applicable):** NOT APPLICABLE

---

### 6. Student Team Details:

| Sl. No. | Insert Passport-size Photograph | Name of the Student (BLOCK LETTERS) | USN / Registration No. | Degree & Branch & Semester | Category (SC/ST/OBC/GEN) | Mobile No. | Email Id |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1.** | *(Paste Photo)* | **MS. LAAVANYA M (TEAM LEADER)** | [Insert USN] | Degree: B.E.<br>Branch: CSE<br>Semester: 7th / 8th | [Your Cat.] | [Your Mobile] | laavanyam1701@gmail.com |
| **2.** | *(Paste Photo)* | **MS. JOHANNA PRIYANKA** | [Insert USN] | Degree: B.E.<br>Branch: CSE<br>Semester: 7th / 8th | [Your Cat.] | [Mobile] | johannapriyanka12@gmail.com |
| **3.** | *(Paste Photo)* | **MS. HARSHITHA S** | [Insert USN] | Degree: B.E.<br>Branch: CSE<br>Semester: 7th / 8th | [Your Cat.] | [Mobile] | harshitha_cse@atria.edu.in |
| **4.** | *(Paste Photo)* | **MS. AIZA ZUHA** | [Insert USN] | Degree: B.E.<br>Branch: CSE<br>Semester: 7th / 8th | [Your Cat.] | [Mobile] | aizazuha0613@gmail.com |

---

### 7. SPP Coordinator Details:
- **SPP Coordinator Name:** [Insert College SPP Coordinator Name, e.g., Dr. / Prof. ...]
- **SPP Coordinator Designation:** [Designation, e.g., Associate Professor / SPP Institutional Coordinator]
- **SPP Coordinator Email ID:** [Coordinator Official Email ID]
- **SPP Coordinator Mobile Number:** [Coordinator Mobile Number]

---

# PART - B: PROJECT DESCRIPTION

### 8. Background and Need of the Project:

**1. Background:**  
Modern connected automobiles and motorcycles generate extensive operational telemetry via Electronic Control Units (ECUs) and standard On-Board Diagnostics (OBD-II) protocols. However, conventional vehicular maintenance paradigms remain predominantly reactive (servicing after catastrophic failure) or rigidly periodic (time-based inspections). These approaches fail to capture dynamic component degradation influenced by ambient conditions, driving habits, and fluctuating mechanical stress.

**2. Existing Scenario:**  
In two-wheeler markets like India (predominated by BS6 emission-compliant vehicles), riders possess negligible visibility into real-time subsystem health. Standard dashboard Malfunction Indicator Lamps (MIL) illuminate only after an emissions or powertrain threshold is fatally breached, incurring exorbitant roadside repairs, safety risks, and heightened emissions.

**3. Problem Statement:**  
Existing commercial diagnostic systems are expensive, proprietary, tailored for passenger four-wheelers, and offer binary fault codes (DTCs) without remaining lifespan estimations or severity ranking.

**4. Need for the Project:**  
There is an urgent requirement for a low-cost, continuous, IoT-and-AI-driven predictive health intelligence system specifically engineered for commuter motorcycles. By acquiring high-frequency OBD-II parameter sequences (Engine RPM, Speed, Engine Load, Coolant Temperature, Throttle Position, Battery Voltage, Fuel Trim, and O2 Voltage) via low-power hardware, early wear can be detected prior to catastrophic failure.

**5. Beneficiaries:**  
- **Individual Motorcyclists & Commuters:** Elimination of unforeseen highway breakdowns and up to 30% reduction in lifetime maintenance expenditure.
- **Fleet & Last-Mile Delivery Operators (e.g., Swiggy, Zomato, Rapido):** Optimized maintenance turnaround, maximized vehicle uptime, and extended battery/engine longevity.
- **Urban Environment:** Controlled emissions through timely detection of rich/lean fuel mismatches and thermal distress.

---

### 9. Review of Existing Work:

**1. Existing Technologies:**  
Current onboard telemetry systems rely on static OBD-II scan tools (e.g., ELM327 handheld readers) that read freeze-frame Diagnostic Trouble Codes (DTCs) upon manual plugin. 

**2. Commercial Products:**  
Consumer dongles (such as Automatic, CarLock, and Vgate) provide basic trip logging, GPS tracking, and clear generic trouble codes, but lack machine learning intelligence, Remaining Useful Life (RUL) estimation, and diagnostic triage algorithms.

**3. Research Papers:**  
- *Mahale et al. (Discover Applied Sciences, 2025)* reviewed AI-driven predictive maintenance in vehicles but noted the absence of lightweight edge deployment architectures.
- *Khan et al. (IEEE Internet of Things Journal, 2026)* examined Industrial IoT predictive maintenance, focusing on stationary industrial machines rather than dynamic two-wheelers.
- *Devi & Giri (IEEE ICACRS, 2025)* and *Wang et al. (IEEE APPEEC, 2024)* investigated UDS protocols and EV battery state-of-health estimation using ensemble methods, yet restricted their focus to isolated battery components rather than comprehensive vehicle powertrain triage.

**4. Patents & Existing Solutions:**  
Automotive OEM telematics patents (Bosch, Continental) focus on high-bandwidth 4G/5G telematics control units (TCUs) coupled to proprietary cloud servers, rendering them cost-prohibitive for mass-market two-wheelers.

**5. Shortcomings and Research Gaps:**  
- Lack of multi-sensor temporal degradation modeling for two-wheelers.
- Absence of medical-style triage frameworks that translate complex probability metrics into straightforward, non-technical rider action levels (Stable, Medium, High, Critical).
- Reliance on isolated snapshot values instead of sliding-window time series dependencies.

---

### 10. Problem Statement:

Motorcycles lack intelligent, low-cost diagnostic mechanisms to detect sub-surface mechanical and electrical degradation before physical breakdown. Traditional diagnostics only alert the rider once irreversible damage has occurred. 

This project aims to bridge this critical gap by designing **VehiCare (VETRI)**: an end-to-end IoT and Deep Learning architecture that continuously acquires 8 OBD-II sensor streams via low-power Bluetooth Low Energy (BLE) / CAN bus hardware, extracts temporal degradation dynamics across a 60-step sliding window, predicts both the Failure Probability and Remaining Useful Life (RUL in hours/days) using an optimized Long Short-Term Memory (LSTM) neural network, and translates predictions into a 4-tier actionable medical-style triage protocol visualized through a responsive Flutter mobile dashboard.

---

### 11. Objectives:

- **To design** a low-power, lightweight IoT data acquisition hardware interface utilizing Arduino Nano / ESP32 and MCP2515 CAN / ELM327 BLE to stream real-time standard OBD-II PIDs (Engine RPM, Speed, Load, Coolant Temperature, Throttle Position, Battery Voltage, Fuel Trim, O2 Sensor Voltage) from BS6 compliant motorcycles.
- **To develop** a high-throughput, edge-processing mobile application using Google Flutter featuring local SQLite buffering, sensor normalization, outlier filtering, and encrypted HTTPS transmission.
- **To fabricate / engineer** a multi-feature temporal dataset incorporating rolling means, standard deviations, temperature gradients, voltage drop rates, and vacuum ratios across sliding temporal windows ($60 \times 40$ matrix).
- **To evaluate and train** an optimized dual-head Long Short-Term Memory (LSTM) recurrent neural network in PyTorch capable of concurrently predicting Remaining Useful Life (RUL regression) and Failure Probability (binary classification) with high accuracy ($>94\%$) and low inference latency ($<120\text{ ms}$).
- **To validate** an automated 4-tier deterministic Predictive Triage Engine (Stable, Medium, High, Critical) and benchmark the performance against baseline machine learning models (Decision Trees, Random Forests, HistGradientBoosting).

---

### 12. Innovation / Novelty:

**1. What is New?**  
VehiCare introduces a **dual-head temporal deep learning architecture** combined with a **medical-style triage decision algorithm** specifically optimized for two-wheeler operational dynamics. Unlike generic scanners that display cryptic alpha-numeric fault codes (e.g., P0171, P0217), VehiCare delivers intuitive Health Scores ($0–100$) and tangible action timelines (e.g., *"RUL: 21 Days — Routine inspection recommended"*).

**2. How is it Different from Existing Work?**  
- **Sequential Trend Learning vs. Snapshot Rules:** Conventional systems evaluate single sensor thresholds (e.g., Temp $> 105^\circ\text{C}$). VehiCare's LSTM captures gradual rates of degradation ($\Delta T / \Delta t$, rolling fuel trim drifts) over a 60-sample temporal window, identifying micro-anomalies up to weeks before component failure.
- **Physics-Informed Hybrid Loss:** Models are trained using a unified multi-task loss function:
  $$L = 0.6 \cdot L_{\text{MSE}} (\text{RUL}) + 0.4 \cdot L_{\text{BCE}} (\text{Failure Probability})$$
  ensuring simultaneous precision in failure likelihood and countdown estimation.

**3. Why is it Innovative?**  
- Extreme cost efficiency ($<\text{₹}2,000$ hardware interface) compared to commercial OEM systems ($\text{₹}15,000+$).
- Ultra-lightweight footprint ($4.1\text{ MB}$ model size, $118\text{ ms}$ inference time) deployable on low-cost cloud microservices (FastAPI / Render) and edge mobile devices.

---

### 13. Proposed Methodology:

**1. Overall Methodology:**  
The VehiCare pipeline operates across five coordinated layers:
$$\text{Vehicle OBD-II Port} \longrightarrow \text{BLE / CAN Edge} \longrightarrow \text{Mobile Preprocessing} \longrightarrow \text{Cloud ML Inference} \longrightarrow \text{Triage Dashboard}$$

```
┌────────────────────────────────────────────────────────┐
│               VEHICLE SENSORS & OBD-II ECU             │
│ (RPM, Speed, Load, Coolant Temp, Throttle, Volt, Trim) │
└───────────────────────────┬────────────────────────────┘
                            │ Standard ISO 15765-4 / CAN (500 kbps)
                            ▼
┌────────────────────────────────────────────────────────┐
│            DATA ACQUISITION (BLE / MCP2515)            │
│       ELM327 BLE Adapter / Arduino Nano + MCP2515      │
└───────────────────────────┬────────────────────────────┘
                            │ Bluetooth Low Energy (NUS Protocol)
                            ▼
┌────────────────────────────────────────────────────────┐
│           EDGE LAYER (FLUTTER MOBILE APP)              │
│  • Range Validation  • SQLite Cache  • Normalization   │
└───────────────────────────┬────────────────────────────┘
                            │ Encrypted HTTPS REST API (FastAPI)
                            ▼
┌────────────────────────────────────────────────────────┐
│            FEATURE ENGINEERING & LSTM MODEL            │
│  • 60-Step Sliding Window • Rolling Mean & Variance    │
│  • Multi-Task LSTM (64 Units, Dropout 0.3, Dense 32)   │
└─────────────┬────────────────────────────┬─────────────┘
              │ RUL Output                 │ Failure Prob
              ▼                            ▼
┌────────────────────────────────────────────────────────┐
│             PREDICTIVE TRIAGE DECISION ENGINE          │
│ HealthScore = 0.7*(RUL/RULmax)*100 + 0.3*(1-Pfail)*100 │
│   [ STABLE (80-100) | MEDIUM (60-79) | HIGH | CRIT ]   │
└───────────────────────────┬────────────────────────────┘
                            │ Push Notifications & Visual Telemetry
                            ▼
┌────────────────────────────────────────────────────────┐
│           RIDER DASHBOARD & ALERT INTERFACE            │
│       Real-Time Gauges, Alerts & Diagnostic Insights   │
└────────────────────────────────────────────────────────┘
```

**2. Design Approach & Mathematical Formulation:**  
- **Data Normalization:** Raw parameters are scaled using Min-Max feature scaling:
  $$X_{\text{norm}} = \frac{X - X_{\text{min}}}{X_{\text{max}} - X_{\text{min}}}$$
- **LSTM Recurrent Cell:** Temporal transitions are governed by:
  $$h_t = \tanh(W_h h_{t-1} + W_x x_t + b)$$
- **Health Score Formulation:**
  $$\text{Health Score} = 0.7 \cdot \left(\frac{\widehat{RUL}}{RUL_{\text{max}}} \times 100\right) + 0.3 \cdot \left( (1 - P_{\text{failure}}) \times 100 \right)$$

**3. Experimental Plan:**  
- Generate physics-informed degradation cycles simulating battery discharge, coolant leakage, and oxygen sensor fouling across 40 virtual vehicles over 60 operating days (691,200 records, 68,880 sliding windows).
- Partition datasets via `GroupShuffleSplit` (75:25 train-test split) preventing inter-vehicle data leakage.
- Validate real-world hardware data capture using a Royal Enfield Classic 350 J-Series motorcycle testbed.

**4. Software & Hardware Stack:**  
- **Hardware:** Arduino Nano (ATmega328P), MCP2515 CAN Bus module (8 MHz SPI), ELM327 BLE v1.5 OBD-II adapter, OBD-II to 6-pin Euro5 diagnostic harness.
- **Software:** Python 3.12, PyTorch 2.4, Google Flutter 3.x (Dart), FastAPI, PostgreSQL, SharedPreferences & SQLite.

---

### 14. Expected Deliverables:

- **Functional Hardware Diagnostic Dongle:** Compact, plug-and-play OBD-II to BLE/CAN hardware interface compatible with BS6 commuter motorcycles.
- **Trained Deep Learning Model Weights:** Exported PyTorch / ONNX model files ($4.1\text{ MB}$) for RUL regression and component failure probability estimation.
- **Production-Grade FastAPI Backend:** Scalable microservice repository implementing automated inference pipelines, JWT token authentication, and telemetry ingestion.
- **Cross-Platform Mobile Application:** Fully compiled Android APK and web dashboard featuring live digital gauges, real-time health scorecards, predictive triage badges, and maintenance advisory logs.
- **Comprehensive Project Report & IEEE Research Publication:** Complete technical documentation, benchmarking reports, and experimental validation paper.

---

### 15. Expected Outcomes and Impact:

- **Technical Impact:** Proves the feasibility of running real-time recurrent neural network inference ($118\text{ ms}$) on low-power vehicle telemetry streams, establishing benchmark accuracy ($94.82\%$, AUC $0.963$).
- **Social Impact:** Enhances two-wheeler commuter road safety by eliminating sudden engine seizures and electrical blackouts on highways.
- **Environmental Impact:** Prevents excessive vehicle emissions caused by unmonitored oxygen sensor fouling, rich air-fuel mixtures, and thermal overheating.
- **Economic Impact:** Saves vehicle owners substantial repair costs through timely preventive interventions (e.g., replacing a ₹300 coolant gasket prevents a ₹15,000 engine overhaul).
- **Industrial & Academic Impact:** Provides a replicable blueprint for EV and ICE fleet operators to integrate predictive telematics without expensive proprietary infrastructure.
- **Potential Users:** Two-wheeler commuters, fleet logistics companies, EV battery management researchers, and automotive service networks across Karnataka.

---

### 16. Relevance:

- [x] **SDGs (Sustainable Development Goals):** Goal 9 (Industry, Innovation & Infrastructure), Goal 11 (Sustainable Cities & Communities), Goal 12 (Responsible Consumption & Production)
- [x] **Karnataka Priority Sector:** Electric & Connected Mobility, Information Technology & Electronics
- [x] **Smart Cities**
- [x] **Digital India**
- [x] **Startup & Innovation**
- [x] **Manufacturing & Automobile Engineering**

---

### 17. Work Plan:

| Activity | Month 1 | Month 2 | Month 3 | Month 4 | Month 5 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Literature Survey & Architecture Design** | **✓** | | | | |
| **Hardware Interfacing (OBD-II / CAN / BLE Setup)** | **✓** | **✓** | | | |
| **Data Collection, Preprocessing & Feature Engineering** | | **✓** | **✓** | | |
| **LSTM Model Training, Optimization & Benchmarking** | | | **✓** | **✓** | |
| **Flutter App & FastAPI Integration** | | | | **✓** | **✓** |
| **Real Vehicle Testing, Validation & Final Report** | | | | | **✓** |

---

### 18. Facilities Available in the Institution:

| Facility Type | Details |
| :--- | :--- |
| **1. Laboratory** | Advanced Computing Laboratory / IoT & Embedded Systems Lab, Dept. of CSE |
| **2. Equipment** | High-performance computing workstations (AMD Ryzen 7, 16GB RAM, NVIDIA GPU), Digital Storage Oscilloscopes (DSO), Multimeters |
| **3. Software** | Python 3.12, PyTorch, Flutter SDK, Android Studio, VS Code, PostgreSQL, Git |
| **4. Instruments** | ELM327 OBD-II BLE scanners, MCP2515 CAN Bus modules, Logic Analyzers, OBD-II Breakout boards |
| **5. Workshop** | Mechanical & Electrical Engineering Fabrication Workshop |
| **6. Institutional Facilities** | High-speed 1 Gbps Campus Wi-Fi, IEEE Digital Library Access, Seminar Presentation Halls |

---

### 19. Major Requirements for the Project:

- **Hardware:**
  - ELM327 Bluetooth Low Energy OBD-II Diagnostic Transceiver
  - Arduino Nano (ATmega328P) & ESP32 Microcontroller Dev Boards
  - MCP2515 CAN Bus SPI Controller + TJA1050 Transceiver Modules
  - Euro-5 / BS6 6-Pin OBD-II Motorcycle Diagnostic Adapter Cable
  - 12V / 5V DC Step-Down Buck Converter Module
- **Software:**
  - Python 3.12 Environment with PyTorch, Scikit-Learn, Pandas, NumPy
  - Google Flutter 3.x Framework & Dart SDK
  - FastAPI High-Performance Asynchronous Python Microframework
  - PostgreSQL Database Management System
  - Git & GitHub Version Control System
- **Consumables:**
  - Prototyping Breadboards, Jumper Wires, 120-Ohm Resistors, Enclosure Casing, Soldering Accessories
- **Field Studies:**
  - Live motorcycle testbed telemetry trials (Royal Enfield Classic 350 J-Series, BS6 commuter two-wheelers)

---

### 20. Budget Estimate:

| Item | Description | Estimated Cost (₹) |
| :--- | :--- | :---: |
| **Equipment / Components** | ELM327 BLE Adapter, MCP2515 CAN Modules, Arduino Nano, Euro-5 OBD-II Diagnostic Harness | 3,400.00 |
| **Consumables** | Electronic wiring, 12V buck converters, breadboards, enclosure casing | 1,200.00 |
| **Fabrication** | Custom PCB prototype & 3D printed protective enclosure | 1,500.00 |
| **Software / Cloud Services**| Cloud Database & API hosting credits (Render / PostgreSQL), Domain & SSL | 1,800.00 |
| **Testing / Analysis** | Fuel & operational expenses for live motorcycle road tests | 1,000.00 |
| **Miscellaneous** | Printing, report binding, documentation, poster presentation materials | 900.00 |
| **TOTAL** | *(Well within the KSCST financial grant ceiling of ₹10,000)* | **₹ 9,800.00** |

---

### 21. References:

1. Y. Mahale, S. Kolhar, and A. S. More, “A comprehensive review on artificial intelligence driven predictive maintenance in vehicles: Technologies, challenges and future research directions,” *Discover Applied Sciences*, vol. 7, no. 4, Art. no. 243, Mar. 2025.
2. M. Khan, M. A. Khan, B. Moser, W. Rafique, X. Xu, and D. Wangchun, “AI-Driven Predictive Maintenance in Industrial IoTs: A Comprehensive Survey,” *IEEE Internet of Things Journal*, early access, Jan. 2026.
3. Y. Mahale, S. Kolhar, and A. S. More, “Automated vehicle fault diagnosis and report generation using hybrid machine learning with multi-step RAG approach,” *Discover Computing*, vol. 28, Art. no. 283, Nov. 2025.
4. M. P. Kumar, S. Velpula, C. Saiprakash, and B. Sahoo, “Advancements in fault detection and diagnosis methods for electric vehicles: A review,” *Discover Applied Sciences*, vol. 7, no. 11, Art. no. 1235, Oct. 2025.
5. S. Devi R. S. and S. R. K. Shira Giri, “A survey on OBD and UDS-based diagnostic system for ECU-VCU communication in electric two-wheelers using UDS,” in *Proc. 2025 4th Int. Conf. on Automation, Computing and Renewable Systems (ICACRS)*, 2025.
6. H. Wang, H. He, P. Wang, Y. Geng, and X. Guo, “Battery State of Health Estimation for Real-World Vehicles Based on Ensemble Learning,” in *Proc. 2024 IEEE PES 16th Asia-Pacific Power and Energy Engineering Conf. (APPEEC)*, Chengdu, China, 2024.
7. S. Zhang, J. Li, L. Shi, M. Ding, D. C. Nguyen, W. Tan, J. Weng, and Z. Han, “Federated Learning in Intelligent Transportation Systems: Recent Applications and Open Problems,” *IEEE Transactions on Intelligent Transportation Systems*, vol. 25, no. 5, pp. 3259–3285, May 2024.
8. A. Tahernejad, A. Sahebi, A. S. S. Abadi, and M. Safari, “Application of Artificial Intelligence in Triage in Emergencies and Disasters: A Systematic Review,” *BMC Public Health*, vol. 24, no. 1, Art. no. 3203, Nov. 2024.

---

### 22. Processing Fee Payment Details:

- **Mode of Payment:** [x] UPI &nbsp;&nbsp;&nbsp; [ ] NEFT
- **Transaction / UTR / Reference Number:** [Insert 12-digit UTR No. from Google Pay / PhonePe / Bank]
- **Date of Payment:** [DD/MM/2026]
- **Amount Paid:** ₹1,180/- (₹1,000/- + 18% GST)
- **Name of Account Holder:** [Sender Account Name]
- **UPI ID Used:** [Your UPI ID, e.g. yourname@okaxis / okicici]
- **Attachment:** [x] Copy of UPI Payment Receipt / NEFT Transaction Receipt enclosed.

---

### 23. Student Details with Signature:

| Sl. No. | Name of Student (Block Letters) | USN / Registration No. | Signature | Date |
| :---: | :--- | :--- | :---: | :---: |
| **1.** | **MS. LAAVANYA M (TEAM LEADER)** | [Insert USN] | *(Sign here)* | [Date] |
| **2.** | **MS. JOHANNA PRIYANKA** | [Insert USN] | *(Sign here)* | [Date] |
| **3.** | **MS. HARSHITHA S** | [Insert USN] | *(Sign here)* | [Date] |
| **4.** | **MS. AIZA ZUHA** | [Insert USN] | *(Sign here)* | [Date] |

**SPP Coordinator Signature:** _______________________ (with Seal)  
**Project Guide Signature:** _______________________ (with Seal)  
**Project Guide Email ID:** hkkr.hari@gmail.com  
**Project Guide Contact No.:** [Insert Guide Mobile Number]

# Vehicle Predictive Triage System (v3)

A full-stack, production-grade **Vehicle Predictive Triage System** designed for two-wheelers (motorcycles) and automotive applications. Streams real-time OBD-II PID sensor data via cross-platform Bluetooth Low Energy (BLE), executes ML component failure risk & DTC triage via a Python FastAPI microservice, and displays real-time health metrics on a cross-platform Flutter app (iOS + Android).

---

## 🛠️ System Architecture

```
┌─────────────────────────────────┐     BLE PIDs     ┌─────────────────────────────────┐
│     Vehicle OBD-II Adapter      │ ────────────────► │       Flutter Mobile App        │
│   (Vgate iCar BLE / ELM327)     │                  │  (Android & iOS Cross-Platform) │
└─────────────────────────────────┘                  └─────────────────────────────────┘
                                                                    │
                                                           HTTPS + JWT Auth Gate
                                                                    ▼
┌─────────────────────────────────┐   Postgres RLS   ┌─────────────────────────────────┐
│    Supabase Postgres Database   │ ◄─────────────── │      FastAPI Backend API        │
│ (Users, Readings, Alerts, RLS)  │                  │  (Scikit-Learn ML Inference)    │
└─────────────────────────────────┘                  └─────────────────────────────────┘
```

---

## 🚀 Quick Start & VS Code Setup

### 1. Backend Setup & Model Training (Python 3.10+)

```bash
# Navigate to project root directory
cd C:\Users\Laavanya Manjunathan\.gemini\antigravity\scratch\vehicle_predictive_triage

# Create virtual environment (optional)
python -m venv env
# Activate on Windows:
.\env\Scripts\activate

# Install dependencies
pip install -r backend/requirements.txt

# 1. Train the ML Baseline Models (HistGradientBoosting, ROC-AUC > 0.85)
python backend/train_baseline_model.py

# 2. Run Automated Unit Tests
pytest tests/

# 3. Start FastAPI Service
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

FastAPI Interactive Docs will be accessible at: `http://localhost:8000/docs`

---

### 2. Mobile App Setup (Flutter)

```bash
# Navigate to mobile app directory
cd mobile_app

# Fetch dependencies
flutter pub get

# Launch on Android Emulator, iOS Simulator, or connected Physical Phone:
flutter run
```

> **Note on Simulator Mode**: The mobile app includes a built-in OBD-II simulator so you can test all 9 screens, DTC fault scenarios (Overheating, Fuel Lean, Low Battery), and predictions inside VS Code without needing physical hardware attached!

---

### 3. Connect to Git & GitHub Repository

To push this codebase to your personal Git / GitHub:

```bash
# Initialize Git in project root
cd C:\Users\Laavanya Manjunathan\.gemini\antigravity\scratch\vehicle_predictive_triage
git init

# Add all files and make initial commit
git add .
git commit -m "feat: initial release of Vehicle Predictive Triage end-to-end software suite"

# Link to your remote GitHub repository
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/vehicle-predictive-triage.git
git push -u origin main
```

---

### 4. Database Setup (Supabase / Postgres)

1. Open your **Supabase Console** or local PostgreSQL instance.
2. Execute `database/schema.sql` to create all tables (`users`, `vehicles`, `readings`, `predictions`, `dtc_lookup`, `alerts`, `trips`, `training_runs`).
3. Execute `database/rls_policies.sql` to activate **Row-Level Security (RLS)**.
4. Execute `database/seed_dtc.sql` to populate SAE Diagnostic Trouble Codes.

---

### 5. Datasets & Hugging Face / Kaggle Integration

- Synthetic sensor generator: `backend/dataset_generator.py`
- Hugging Face Hub dataset pipeline: `backend/hf_kaggle_loader.py`
- You can pull custom telemetry datasets or export model binaries directly to `backend/models/`.

---

## 📱 Mobile App Screens Overview

1. **Sign In / Sign Up**: Supabase JWT authentication gate.
2. **Pair OBD-II Device**: Native cross-platform BLE scanner.
3. **Adapter Found**: Connection handshake & vehicle VIN binding.
4. **Home Dashboard**: Health score gauge (0-100), live metrics grid, active fault cards.
5. **Diagnostics**: Real-time sensor parameter bars & live RPM history line charts (`fl_chart`).
6. **Alerts**: Filterable DTC list with triage severity badges (Critical, Warning, Info).
7. **History**: Trip logs, per-ride score trends, and distance tracking.
8. **Profile**: User info, registered vehicle specs, BLE binding, Pro Plan badge.
9. **Emergency SOS**: Hold 2-sec SOS button, GPS coordinate broadcast (`geolocator`), roadside assistance & Google Maps dialer deep-links.

---

## 🔒 Security Specifications

- **Auth Gate**: Every backend API endpoint requires a valid JWT Bearer token.
- **Database RLS**: Postgres policies (`user_id = auth.uid()`) ensure users can never query other vehicles' data.
- **On-Device Storage**: JWT tokens stored securely via `flutter_secure_storage`.

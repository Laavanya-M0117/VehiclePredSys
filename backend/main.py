import os
import time
import json
import base64
import hmac
import hashlib
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Depends, HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

try:
    from backend.inference import get_inference_engine
    from backend.train_baseline_model import train_and_save_models
    from backend.triage import DTC_RULES
except ImportError:
    from inference import get_inference_engine
    from train_baseline_model import train_and_save_models
    from triage import DTC_RULES

try:
    import jwt as pyjwt
    HAS_PYJWT = True
except ImportError:
    HAS_PYJWT = False

JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-demo-key-for-vehicle-predictive-triage-2026")

REGISTERED_USERS = {
    "alex.martinez@vehicle-triage.io": {
        "user_id": "usr-alex-001",
        "email": "alex.martinez@vehicle-triage.io",
        "password": "Password123!",
        "display_name": "Alex Martinez",
    },
    "rider@vehicle-triage.com": {
        "user_id": "usr-rider-002",
        "email": "rider@vehicle-triage.com",
        "password": "Password123!",
        "display_name": "Demo Rider",
    }
}

def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

def b64url_decode(data_str: str) -> bytes:
    padding = 4 - (len(data_str) % 4)
    if padding != 4:
        data_str += '=' * padding
    return base64.urlsafe_b64decode(data_str)

def encode_jwt_token(payload: dict, secret: str = JWT_SECRET) -> str:
    if HAS_PYJWT:
        return pyjwt.encode(payload, secret, algorithm="HS256")
    else:
        header = {"alg": "HS256", "typ": "JWT"}
        header_b64 = b64url_encode(json.dumps(header).encode('utf-8'))
        payload_b64 = b64url_encode(json.dumps(payload).encode('utf-8'))
        signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')
        signature = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
        sig_b64 = b64url_encode(signature)
        return f"{header_b64}.{payload_b64}.{sig_b64}"

def decode_jwt_token(token: str, secret: str = JWT_SECRET) -> dict:
    if HAS_PYJWT:
        return pyjwt.decode(token, secret, algorithms=["HS256"], options={"verify_aud": False})
    else:
        parts = token.split('.')
        if len(parts) != 3:
            raise ValueError("Invalid token format")
        header_b64, payload_b64, sig_b64 = parts
        signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')
        expected_sig = b64url_encode(hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest())
        if not hmac.compare_digest(sig_b64, expected_sig):
            raise ValueError("Invalid signature")
        payload_bytes = b64url_decode(payload_b64)
        return json.loads(payload_bytes.decode('utf-8'))

app = FastAPI(
    title="Vehicle Predictive Triage API",
    description="Production ML Backend microservice streaming OBD-II telemetry, evaluating DTC triage, and predicting motorcycle component failure.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

in_memory_readings: Dict[int, List[Dict[str, Any]]] = {}
in_memory_predictions: Dict[int, List[Dict[str, Any]]] = {}
in_memory_alerts: Dict[int, List[Dict[str, Any]]] = {}

class SensorReading(BaseModel):
    rpm: Optional[float] = Field(3200.0, description="Engine Speed (RPM)")
    coolant_temp: Optional[float] = Field(88.0, description="Coolant Temperature (°C)")
    engine_load: Optional[float] = Field(40.0, description="Calculated Engine Load (%)")
    throttle_pos: Optional[float] = Field(25.0, description="Throttle Position (%)")
    fuel_trim: Optional[float] = Field(0.5, description="Short-Term Fuel Trim (%)")
    o2_voltage: Optional[float] = Field(0.45, description="O2 Sensor Voltage (V)")
    speed: Optional[float] = Field(55.0, description="Vehicle Speed (km/h)")
    voltage: Optional[float] = Field(13.8, description="Control Module Voltage (V)")
    # Extended 15-parameter aliases from Royal Enfield protocol:
    tps: Optional[float] = None
    eot: Optional[float] = None
    stft: Optional[float] = None
    ltft: Optional[float] = None
    map: Optional[float] = None
    battery_voltage: Optional[float] = None
    dtc_count: Optional[int] = 0

    class Config:
        extra = "allow"

class PredictRequest(BaseModel):
    vehicle_id: int = Field(1, description="Registered Vehicle ID")
    readings: List[SensorReading]

class LogReadingRequest(BaseModel):
    vehicle_id: int
    reading: SensorReading

class LoginRequest(BaseModel):
    email: str
    password: str

class SignUpRequest(BaseModel):
    email: str
    password: str
    display_name: Optional[str] = "New Rider"

class DemoAuthRequest(BaseModel):
    user_id: str = "demo-user-123"
    email: str = "rider@vehicle-triage.com"

def verify_jwt_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> Dict[str, Any]:
    token = credentials.credentials
    try:
        payload = decode_jwt_token(token, JWT_SECRET)
        return payload
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token. Mandatory auth gate enforced."
        )

@app.get("/health", tags=["System"])
def health_check():
    return {
        "status": "healthy",
        "service": "Vehicle Predictive Triage Backend",
        "timestamp": time.time()
    }

@app.post("/auth/login", tags=["Auth"])
def login_user(req: LoginRequest):
    email_clean = req.email.strip().lower()
    user_record = REGISTERED_USERS.get(email_clean)
    
    if not user_record or user_record["password"] != req.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password. Authentication rejected."
        )
        
    payload = {
        "sub": user_record["user_id"],
        "email": user_record["email"],
        "display_name": user_record["display_name"],
        "role": "authenticated",
        "iat": int(time.time()),
        "exp": int(time.time()) + (86400 * 7)
    }
    token = encode_jwt_token(payload, JWT_SECRET)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 604800,
        "user": {
            "user_id": user_record["user_id"],
            "email": user_record["email"],
            "display_name": user_record["display_name"]
        }
    }

@app.post("/auth/signup", tags=["Auth"])
def signup_user(req: SignUpRequest):
    email_clean = req.email.strip().lower()
    if email_clean in REGISTERED_USERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists."
        )
        
    user_id = f"usr-new-{int(time.time())}"
    user_record = {
        "user_id": user_id,
        "email": email_clean,
        "password": req.password,
        "display_name": req.display_name or email_clean.split('@')[0],
    }
    REGISTERED_USERS[email_clean] = user_record
    
    payload = {
        "sub": user_id,
        "email": email_clean,
        "display_name": user_record["display_name"],
        "role": "authenticated",
        "iat": int(time.time()),
        "exp": int(time.time()) + (86400 * 7)
    }
    token = encode_jwt_token(payload, JWT_SECRET)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 604800,
        "user": {
            "user_id": user_id,
            "email": email_clean,
            "display_name": user_record["display_name"]
        }
    }

@app.post("/auth/demo-token", tags=["Auth"])
def generate_demo_token(req: DemoAuthRequest):
    payload = {
        "sub": req.user_id,
        "email": req.email,
        "role": "authenticated",
        "iat": int(time.time()),
        "exp": int(time.time()) + (86400 * 7)
    }
    token = encode_jwt_token(payload, JWT_SECRET)
    return {"access_token": token, "token_type": "bearer", "expires_in": 604800}

@app.post("/predict", tags=["Prediction"])
def predict_health(payload: Dict[str, Any], user: Dict[str, Any] = Depends(verify_jwt_token)):
    engine = get_inference_engine()
    vehicle_id = payload.get("vehicle_id", 1)
    
    if "readings" in payload and isinstance(payload["readings"], list):
        readings_dict = payload["readings"]
    else:
        readings_dict = payload

    result = engine.predict(readings_dict)
    
    prediction_entry = {
        "vehicle_id": vehicle_id,
        "timestamp": time.time(),
        **result
    }
    if vehicle_id not in in_memory_predictions:
        in_memory_predictions[vehicle_id] = []
    in_memory_predictions[vehicle_id].append(prediction_entry)
    
    if result["active_dtcs"]:
        if vehicle_id not in in_memory_alerts:
            in_memory_alerts[vehicle_id] = []
        for dtc in result["active_dtcs"]:
            in_memory_alerts[vehicle_id].append({
                "alert_id": len(in_memory_alerts[vehicle_id]) + 1,
                "vehicle_id": vehicle_id,
                "dtc_code": dtc["code"],
                "title": dtc["title"],
                "severity": dtc["severity"],
                "action": dtc["action"],
                "triggered_at": time.time(),
                "resolved": False
            })
            
    return prediction_entry

@app.post("/log-reading", tags=["Telemetry"])
def log_sensor_reading(req: LogReadingRequest, user: Dict[str, Any] = Depends(verify_jwt_token)):
    vehicle_id = req.vehicle_id
    if vehicle_id not in in_memory_readings:
        in_memory_readings[vehicle_id] = []
        
    entry = {"timestamp": time.time(), **req.reading.dict()}
    in_memory_readings[vehicle_id].append(entry)
    
    if len(in_memory_readings[vehicle_id]) > 500:
        in_memory_readings[vehicle_id] = in_memory_readings[vehicle_id][-500:]
        
    return {"status": "logged", "total_readings": len(in_memory_readings[vehicle_id])}

RIDE_LOGS_DIR = os.path.join(os.path.dirname(__file__), '..', 'data', 'recorded_rides')
os.makedirs(RIDE_LOGS_DIR, exist_ok=True)

class RecordRideRequest(BaseModel):
    session_id: Optional[str] = None
    vehicle_vin: Optional[str] = "ME3J350CAN2026VIN"
    readings: List[Dict[str, Any]]

@app.post("/telemetry/record-ride", tags=["Telemetry Logging"])
def record_ride_telemetry(req: RecordRideRequest, user: Dict[str, Any] = Depends(verify_jwt_token)):
    """
    Appends live incoming BLE telemetry packets from a ride session into a CSV file.
    Creates a new session file if none specified.
    """
    session_id = req.session_id or f"ride_{int(time.time())}"
    csv_file = os.path.join(RIDE_LOGS_DIR, f"{session_id}.csv")
    
    if not req.readings:
        return {"status": "empty", "message": "No readings in payload"}
        
    df = pd.DataFrame(req.readings)
    df['recorded_at'] = time.time()
    
    file_exists = os.path.exists(csv_file)
    df.to_csv(csv_file, mode='a', header=not file_exists, index=False)
    
    return {
        "status": "success",
        "session_id": session_id,
        "recorded_packets": len(df),
        "file_path": csv_file
    }

@app.get("/telemetry/recorded-rides", tags=["Telemetry Logging"])
def list_recorded_rides(user: Dict[str, Any] = Depends(verify_jwt_token)):
    """Lists all captured ride log CSV files available for model training."""
    files = []
    if os.path.exists(RIDE_LOGS_DIR):
        for f in os.listdir(RIDE_LOGS_DIR):
            if f.endswith('.csv'):
                p = os.path.join(RIDE_LOGS_DIR, f)
                files.append({
                    "filename": f,
                    "size_kb": round(os.path.getsize(p) / 1024, 2),
                    "created_at": time.ctime(os.path.getctime(p))
                })
    return {"total_rides": len(files), "rides": files}

@app.post("/retrain", tags=["Model Training"])
def retrain_model(user: Dict[str, Any] = Depends(verify_jwt_token)):
    metadata = train_and_save_models()
    engine = get_inference_engine()
    engine.load_models()
    return {"status": "success", "message": "Model retrained and reloaded successfully", "metadata": metadata}

@app.get("/vehicle/{vehicle_id}/history", tags=["Telemetry"])
def get_vehicle_history(vehicle_id: int, user: Dict[str, Any] = Depends(verify_jwt_token)):
    readings = in_memory_readings.get(vehicle_id, [])
    predictions = in_memory_predictions.get(vehicle_id, [])
    return {
        "vehicle_id": vehicle_id,
        "readings_count": len(readings),
        "recent_readings": readings[-20:],
        "predictions_count": len(predictions),
        "recent_predictions": predictions[-10:]
    }

@app.get("/vehicle/{vehicle_id}/alerts", tags=["Telemetry"])
def get_vehicle_alerts(vehicle_id: int, user: Dict[str, Any] = Depends(verify_jwt_token)):
    alerts = in_memory_alerts.get(vehicle_id, [])
    return {
        "vehicle_id": vehicle_id,
        "total_alerts": len(alerts),
        "alerts": alerts
    }

@app.get("/dtc/{code}", tags=["Diagnostics"])
def lookup_dtc_code(code: str, user: Dict[str, Any] = Depends(verify_jwt_token)):
    upper_code = code.upper()
    if upper_code in DTC_RULES:
        return DTC_RULES[upper_code]
    raise HTTPException(status_code=404, detail=f"DTC code {upper_code} not found in database.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

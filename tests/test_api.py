import os
import sys
from fastapi.testclient import TestClient

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

from backend.main import app

def run_all_api_tests():
    print("[Test API] Initializing TestClient...")
    client = TestClient(app)

    print("[Test API] Testing unauthenticated rejection (401/403)...")
    response = client.post("/predict", json={"vehicle_id": 1, "readings": []})
    assert response.status_code in [401, 403]

    print("[Test API] Testing /auth/demo-token endpoint...")
    auth_resp = client.post("/auth/demo-token", json={"user_id": "rider-1", "email": "test@rider.com"})
    assert auth_resp.status_code == 200
    token = auth_resp.json()["access_token"]
    assert len(token) > 20

    headers = {"Authorization": f"Bearer {token}"}

    print("[Test API] Testing authenticated /predict endpoint...")
    payload = {
        "vehicle_id": 1,
        "readings": [
            {"rpm": 3200, "coolant_temp": 88, "voltage": 13.8, "speed": 60},
            {"rpm": 3300, "coolant_temp": 89, "voltage": 13.7, "speed": 62}
        ]
    }
    pred_resp = client.post("/predict", json=payload, headers=headers)
    assert pred_resp.status_code == 200
    data = pred_resp.json()
    assert "health_score" in data
    assert "triage_label" in data
    assert "failure_probability" in data

    print("[Test API] Testing /dtc/{code} lookup endpoint...")
    dtc_resp = client.get("/dtc/P0300", headers=headers)
    assert dtc_resp.status_code == 200
    assert dtc_resp.json()["code"] == "P0300"
    assert dtc_resp.json()["severity"] == "CRITICAL"

    print("\n[SUCCESS] ALL API ENDPOINT TESTS PASSED CLEANLY!")

if __name__ == '__main__':
    run_all_api_tests()

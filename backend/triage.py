"""
DTC (Diagnostic Trouble Code) Rules & Health Score Triage Engine
Evaluates SAE J1979 OBD-II standard fault codes and calculates vehicle health score.
Integrates ambient weather temperature baseline correlation and 4-tier triage (HIGH / MEDIUM / LOW / INFO).
"""

DTC_RULES = {
    "P0300": {
        "code": "P0300",
        "title": "Engine Misfire Detected (Multiple Cylinders)",
        "severity": "CRITICAL",
        "triage_tier": "HIGH",
        "description": "Random/multiple cylinder misfire detected via crankshaft position fluctuations.",
        "action": "Immediate service required. Stop riding if Check Engine light flashes.",
        "impact_score": 35
    },
    "P0171": {
        "code": "P0171",
        "title": "System Too Lean (Bank 1)",
        "severity": "MEDIUM",
        "triage_tier": "MEDIUM",
        "description": "Air/Fuel ratio excessively lean. Short-term fuel trim > +15%.",
        "action": "Inspect intake manifold gaskets, MAF sensor, and vacuum lines.",
        "impact_score": 20
    },
    "P0217": {
        "code": "P0217",
        "title": "Engine Coolant Over Temperature Condition",
        "severity": "CRITICAL",
        "triage_tier": "HIGH",
        "description": "Coolant temperature exceeded ambient-adjusted threshold (> 110°C).",
        "action": "Pull over safely and stop engine. Inspect radiator fan and coolant level.",
        "impact_score": 45
    },
    "P0562": {
        "code": "P0562",
        "title": "System Voltage Low",
        "severity": "MEDIUM",
        "triage_tier": "MEDIUM",
        "description": "Control module voltage dropped below 11.5V.",
        "action": "Check stator/alternator output, charging relay, and battery terminals.",
        "impact_score": 25
    },
    "P0420": {
        "code": "P0420",
        "title": "Catalyst System Efficiency Below Threshold",
        "severity": "LOW",
        "triage_tier": "LOW",
        "description": "Downstream O2 sensor indicates reduced catalytic conversion efficiency.",
        "action": "Schedule emissions inspection. Non-critical for immediate operation.",
        "impact_score": 10
    },
    "P0105": {
        "code": "P0105",
        "title": "MAP Circuit Malfunction",
        "severity": "MEDIUM",
        "triage_tier": "MEDIUM",
        "description": "Manifold Absolute Pressure sensor signal out of range.",
        "action": "Inspect MAP sensor wiring connector and vacuum hose.",
        "impact_score": 15
    },
    "P0117": {
        "code": "P0117",
        "title": "Engine Coolant Temp Sensor Low Input",
        "severity": "MEDIUM",
        "triage_tier": "MEDIUM",
        "description": "ECT sensor circuit shorted to ground.",
        "action": "Check ECT sensor wiring harness for short circuit.",
        "impact_score": 15
    },
    "P0122": {
        "code": "P0122",
        "title": "Throttle Position Sensor Low Input",
        "severity": "CRITICAL",
        "triage_tier": "HIGH",
        "description": "TPS voltage below 0.2V indicating open circuit.",
        "action": "Check throttle body position sensor wiring and alignment.",
        "impact_score": 30
    },
    "INFO-BLE": {
        "code": "INFO-BLE",
        "title": "OBD-II Bluetooth Telemetry Active",
        "severity": "INFO",
        "triage_tier": "INFO",
        "description": "Real-time streaming active over BLE protocol.",
        "action": "All systems nominal.",
        "impact_score": 0
    }
}

def evaluate_dtc_rules(readings_aggregated: dict, ambient_temp: float = 28.0) -> list:
    active_dtcs = []
    
    expected_coolant = ambient_temp + 60.0
    coolant = readings_aggregated.get('coolant_temp', 88.0)
    
    if coolant > max(110.0, expected_coolant + 22.0):
        active_dtcs.append(DTC_RULES["P0217"])
        
    fuel_trim = readings_aggregated.get('fuel_trim', 0.0)
    if fuel_trim > 18.0:
        active_dtcs.append(DTC_RULES["P0171"])
        
    rpm_std = readings_aggregated.get('rpm_std', 0.0)
    if rpm_std > 450.0 and fuel_trim > 12.0:
        active_dtcs.append(DTC_RULES["P0300"])
        
    voltage = readings_aggregated.get('voltage', 13.8)
    if voltage < 11.5:
        active_dtcs.append(DTC_RULES["P0562"])
        
    o2_voltage = readings_aggregated.get('o2_voltage', 0.45)
    if o2_voltage < 0.15 and fuel_trim > 10.0:
        active_dtcs.append(DTC_RULES["P0420"])
        
    return active_dtcs

def evaluate_sensor_triage(readings_aggregated: dict, ambient_temp: float = 28.0):
    active_dtcs = evaluate_dtc_rules(readings_aggregated, ambient_temp)
    if any(d.get('severity') in ('CRITICAL', 'HIGH') for d in active_dtcs):
        label = 'HIGH'
    elif any(d.get('severity') == 'MEDIUM' for d in active_dtcs):
        label = 'MEDIUM'
    elif any(d.get('severity') == 'LOW' for d in active_dtcs):
        label = 'LOW'
    else:
        label = 'NORMAL'
    return label, active_dtcs

def compute_health_score(active_dtcs=None, failure_prob: float = 0.0, coolant_temp: float = 88.0, voltage: float = 13.8) -> int:
    base_score = 100
    if active_dtcs:
        for dtc in active_dtcs:
            impact = dtc.get('impact_score', 15)
            base_score -= impact
    if failure_prob > 0.5:
        base_score -= int((failure_prob - 0.5) * 40)
    return max(0, min(100, base_score))

calculate_health_score = compute_health_score

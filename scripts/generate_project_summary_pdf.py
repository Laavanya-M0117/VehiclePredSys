import os
import sys
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            return  # Suppress headers/footers on cover page

        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#718096"))

        # Header
        self.drawString(54, letter[1] - 36, "VETRI: Vehicle Predictive Triage & Live Telemetry — Technical Specification")
        self.setStrokeColor(colors.HexColor("#CBD5E0"))
        self.setLineWidth(0.5)
        self.line(54, letter[1] - 42, letter[0] - 54, letter[1] - 42)

        # Footer
        self.line(54, 46, letter[0] - 54, 46)
        self.drawString(54, 34, "Confidential — Academic & Technical Evaluation Copy")
        self.drawRightString(letter[0] - 54, 34, f"Page {self._pageNumber} of {page_count}")
        self.restoreState()

def build_pdf(filename="VETRI_Project_Complete_Summary.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    # Custom Color Palette
    PRIMARY = colors.HexColor("#1A365D")   # Deep Navy
    SECONDARY = colors.HexColor("#2B6CB0") # Vibrant Blue
    DARK_TEXT = colors.HexColor("#2D3748") # Charcoal
    LIGHT_BG = colors.HexColor("#F7FAFC")  # Cool Grey
    BORDER_COL = colors.HexColor("#E2E8F0")# Light Border
    ACCENT_RED = colors.HexColor("#C53030")# Crimson
    ACCENT_GREEN = colors.HexColor("#276749")# Forest Green

    # Typography Styles
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=30,
        textColor=PRIMARY,
        alignment=0
    )
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=SECONDARY,
        alignment=0
    )
    h1_style = ParagraphStyle(
        'H1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=19,
        textColor=PRIMARY,
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True
    )
    h2_style = ParagraphStyle(
        'H2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=SECONDARY,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=DARK_TEXT,
        spaceAfter=6
    )
    body_bold = ParagraphStyle(
        'BodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )
    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7.5,
        leading=10,
        textColor=colors.HexColor("#1A202C")
    )
    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=DARK_TEXT
    )
    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=table_cell,
        fontName='Helvetica-Bold',
        textColor=PRIMARY
    )
    table_cell_code = ParagraphStyle(
        'TableCellCode',
        parent=table_cell,
        fontName='Courier',
        fontSize=7.5,
        leading=10
    )

    story = []

    # =========================================================================
    # COVER PAGE
    # =========================================================================
    story.append(Spacer(1, 40))
    story.append(Paragraph("PROJECT VETRI", ParagraphStyle('CoverKicker', fontName='Helvetica-Bold', fontSize=12, textColor=SECONDARY, leading=14)))
    story.append(Spacer(1, 10))
    story.append(Paragraph("Vehicle Predictive Triage & Live Telemetry Architecture", title_style))
    story.append(Spacer(1, 8))
    story.append(Paragraph("Comprehensive Technical Specification: Hardware Schematics, Embedded BLE Firmware, Domain Feature Engineering, Multi-Model Machine Learning, and Cloud-Mobile Software Ecosystem", subtitle_style))
    story.append(Spacer(1, 25))
    story.append(HRFlowable(width="100%", thickness=3, color=SECONDARY, spaceBefore=5, spaceAfter=25))

    meta_data = [
        [Paragraph("Target Vehicle Platform:", table_cell_bold), Paragraph("Royal Enfield Classic 350 (J-Series, 349cc SOHC, Euro-5 / BS6)", table_cell)],
        [Paragraph("Communication Protocol:", table_cell_bold), Paragraph("ISO 15765-4 (CAN Bus 500 kbps, 11-bit) & BLE Nordic UART Service", table_cell)],
        [Paragraph("Microcontroller & Transceiver:", table_cell_bold), Paragraph("ESP32 Dual-Core Tensilica LX6 + Texas Instruments SN65HVD230", table_cell)],
        [Paragraph("Machine Learning Stack:", table_cell_bold), Paragraph("Scikit-Learn 1.9 (HistGradientBoosting Classifier & Dual Regressors)", table_cell)],
        [Paragraph("Backend & Mobile Ecosystem:", table_cell_bold), Paragraph("FastAPI Microservices (Python 3.14) + Flutter 3.29 Multiplatform PWA", table_cell)],
        [Paragraph("Emergency Dispatch:", table_cell_bold), Paragraph("Twilio Cloud SMS API with 10-Minute Cooldown Circuit Breaker", table_cell)],
        [Paragraph("Document Status / Version:", table_cell_bold), Paragraph("Production Master Specification v2.0 (Verified October 2026)", table_cell)],
    ]
    meta_table = Table(meta_data, colWidths=[160, 344])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(meta_table)

    story.append(Spacer(1, 35))
    callout_data = [[
        Paragraph(
            "<b>Executive Summary:</b> Project VETRI transitions automotive diagnostics from reactive trouble-code reading to proactive, edge-assisted failure triage. By coupling high-speed CAN telemetry acquisition with a 19-parameter physics-informed feature pipeline, VETRI identifies pre-failure thermal runaway, intake vacuum leaks, and electrical charging breakdowns prior to catastrophic engine failure.",
            body_style
        )
    ]]
    callout_table = Table(callout_data, colWidths=[504])
    callout_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EBF8FF")),
        ('BOX', (0,0), (-1,-1), 1, SECONDARY),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(callout_table)

    story.append(PageBreak())

    # =========================================================================
    # SECTION 1: HARDWARE ARCHITECTURE & CIRCUIT SCHEMATIC
    # =========================================================================
    story.append(Paragraph("1. Hardware Architecture & Electronic Interface", h1_style))
    story.append(Paragraph(
        "Modern motorcycles conforming to Euro-5 / BS6 regulations feature an OBD-II diagnostic port communicating over the Controller Area Network (CAN) at 500 kbps. The VETRI hardware module acts as an autonomous diagnostic node bridging the high-speed differential bus to low-power Bluetooth (BLE).",
        body_style
    ))

    story.append(Paragraph("1.1 Interface Pinout & Interconnection Specification", h2_style))
    story.append(Paragraph(
        "The following circuit table specifies the exact connection between the motorcycle's standard 16-pin diagnostic connector, the 3.3V CAN transceiver, and the ESP32 micro-controller unit:",
        body_style
    ))

    hw_table_data = [
        [Paragraph("OBD-II 16-Pin", table_cell_bold), Paragraph("SN65HVD230 Pin", table_cell_bold), Paragraph("ESP32 DevKit V1", table_cell_bold), Paragraph("Signal / Electrical Function", table_cell_bold)],
        [Paragraph("Pin 16 (BAT+)", table_cell), Paragraph("—", table_cell), Paragraph("VIN (via 12V→5V buck)", table_cell), Paragraph("+12V Unregulated Vehicle Battery Power", table_cell)],
        [Paragraph("Pin 4 / 5 (GND)", table_cell), Paragraph("Pin 2 (GND)", table_cell), Paragraph("GND", table_cell), Paragraph("Common Vehicle System Ground Reference", table_cell)],
        [Paragraph("Pin 6 (CAN-H)", table_cell), Paragraph("Pin 7 (CANH)", table_cell), Paragraph("—", table_cell), Paragraph("Differential High CAN Bus Line (Dominant ~3.5V)", table_cell)],
        [Paragraph("Pin 14 (CAN-L)", table_cell), Paragraph("Pin 6 (CANL)", table_cell), Paragraph("—", table_cell), Paragraph("Differential Low CAN Bus Line (Dominant ~1.5V)", table_cell)],
        [Paragraph("—", table_cell), Paragraph("Pin 1 (D / TXD)", table_cell), Paragraph("GPIO 5 (TWAI TX)", table_cell), Paragraph("TTL CAN Transmit Line (3.3V Logic)", table_cell)],
        [Paragraph("—", table_cell), Paragraph("Pin 4 (R / RXD)", table_cell), Paragraph("GPIO 4 (TWAI RX)", table_cell), Paragraph("TTL CAN Receive Line (3.3V Logic)", table_cell)],
        [Paragraph("—", table_cell), Paragraph("Pin 3 (VCC)", table_cell), Paragraph("3V3 Out", table_cell), Paragraph("3.3V Clean Regulated Supply to Transceiver", table_cell)],
        [Paragraph("—", table_cell), Paragraph("<b>Pin 8 (Rs)</b>", table_cell_bold), Paragraph("<b>GND (0V Direct)</b>", table_cell_bold), Paragraph("<b>Mode Selection: Pulled to GND enables High-Speed 500kbps Mode</b>", table_cell_bold)],
        [Paragraph("Across CAN-H/L", table_cell), Paragraph("Term Resistor", table_cell), Paragraph("—", table_cell), Paragraph("120 Ω Bus Termination (Prevents high-frequency reflections)", table_cell)],
    ]
    hw_table = Table(hw_table_data, colWidths=[90, 95, 115, 204])
    hw_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(hw_table)

    story.append(Spacer(1, 8))
    story.append(Paragraph("1.2 Critical Hardware Engineering Fixes Implemented", h2_style))
    story.append(Paragraph(
        "<b>1. Transceiver Mode Pin 8 (Rs) Pull-Down:</b> Many standard breakout modules leave Pin 8 floating or tied to VCC via an internal pull-up, placing the transceiver into ultra-low-power standby mode. In standby, the driver is disabled, completely silencing CAN packet transmission. Wiring Pin 8 directly to 0V (GND) forces the transceiver into continuous high-speed mode.<br/>"
        "<b>2. Characteristic Impedance Termination:</b> Royal Enfield motorcycles feature distributed termination across the ECU and ABS modules. Adding a 120 Ω metal-film resistor across CAN-H and CAN-L dampens RF reflections on the diagnostic stub line, ensuring zero bit-framing errors at 500 kbps.",
        body_style
    ))

    story.append(Paragraph("1.3 ESP32 Embedded Firmware Architecture", h2_style))
    story.append(Paragraph(
        "The firmware is developed using the <b>NimBLE-Arduino</b> stack and the ESP32 hardware <b>TWAI (Two-Wire Automotive Interface)</b> controller. It operates as follows:<br/>"
        "• <b>Dual Core Execution:</b> Core 0 runs the TWAI interrupt handler, querying standard PID requests (e.g., 0x010C for RPM, 0x010D for Speed, 0x0105 for Coolant/Oil Temp). Core 1 serializes the verified state and dispatches Bluetooth notifications.<br/>"
        "• <b>Nordic UART Service (NUS):</b> Advertises Service UUID <code>6E400001-B5A3-F393-E0A9-E50E24DCCA9E</code>. Transmits on TX Characteristic <code>6E400003-B5A3-F393-E0A9-E50E24DCCA9E</code> using unacknowledged notifications at 2 Hz (500ms intervals).",
        body_style
    ))

    # =========================================================================
    # SECTION 2: TELEMETRY STREAMING PROTOCOL
    # =========================================================================
    story.append(Spacer(1, 6))
    story.append(Paragraph("2. Telemetry Streaming Protocol & Line-Assembly", h1_style))
    story.append(Paragraph(
        "To maximize transmission throughput while guaranteeing fault-tolerant packet framing over BLE MTU limits (typically 20 to 128 bytes), the firmware formats each cycle into a semicolon-delimited ASCII string terminated with a mandatory newline (<code>\\n</code>).",
        body_style
    ))

    proto_snippet = (
        "[TX] VIN:ME3J350CAN2026VIN;RPM:1058;SPD:0.0;TPS:2.1;MAP:34.0;IAT:31.0;EOT:88.0;\n"
        "     O2:0.36;STFT:+2.3;LTFT:+1.8;BAT:14.12;GEAR:N;CLUTCH:0;SIDE_STAND:0;\n"
        "     F_WHEEL:0.0;R_WHEEL:0.0;DTC:NO FAULT\\n"
    )
    pbox = Table([[Paragraph(f"<pre>{proto_snippet}</pre>", code_style)]], colWidths=[504])
    pbox.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#2D3748")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    pbox.setStyle(TableStyle([('TEXTCOLOR', (0,0), (-1,-1), colors.white)]))
    story.append(pbox)
    story.append(Spacer(1, 6))

    story.append(Paragraph(
        "<b>Line Assembly Engine:</b> Mobile BLE stacks frequently fragment incoming packets across multiple BLE notification chunks (e.g., 20 bytes each). VETRI implements a string-buffer accumulator in <code>AppStateProvider</code> that buffers incoming chunks and only triggers ML inference once the terminating <code>\\n</code> character is detected, eliminating malformed JSON or parsing aborts.",
        body_style
    ))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 3: DATASET SYNTHESIS & DOMAIN FEATURE ENGINEERING
    # =========================================================================
    story.append(Paragraph("3. Physical Dataset & 19 Engineered Features", h1_style))
    story.append(Paragraph(
        "A healthy motorcycle in nominal operation does not exhibit engine failure. Intentionally causing mechanical breakdown on a physical motorcycle to collect failure data is unsafe and financially unviable. VETRI resolves this using a <b>Physics-Informed Semi-Supervised Synthetic Dataset (10,000 correlated cycles)</b> accurately modeling the thermodynamics, volumetric efficiency, and electrical charging curves of the Royal Enfield 349cc J-Series engine.",
        body_style
    ))

    story.append(Paragraph("3.1 Core Engineered Features (19 Features Extracted)", h2_style))
    story.append(Paragraph(
        "Instead of feeding raw sensor readings to black-box models, VETRI computes 19 domain-specific thermodynamic and mechanical indicators in <code>backend/preprocessing.py</code>:",
        body_style
    ))

    feat_data = [
        [Paragraph("Feature Name", table_cell_bold), Paragraph("Mathematical Formulation", table_cell_bold), Paragraph("Diagnostic & Thermodynamic Significance", table_cell_bold)],
        [Paragraph("vacuum_ratio", table_cell_code), Paragraph("MAP / (TPS + 1.0)", table_cell), Paragraph("High MAP at low throttle indicates intake vacuum gasket breach or unmetered air leak.", table_cell)],
        [Paragraph("total_fuel_trim", table_cell_code), Paragraph("STFT + LTFT", table_cell), Paragraph("Net closed-loop fueling correction; values exceeding +15% flag severe lean conditions.", table_cell)],
        [Paragraph("thermal_headroom", table_cell_code), Paragraph("115.0 - EOT (°C)", table_cell), Paragraph("Direct temperature margin remaining before lubricating oil breakdown and thermal runaway.", table_cell)],
        [Paragraph("electrical_margin", table_cell_code), Paragraph("Voltage - 12.0 (V)", table_cell), Paragraph("Remaining operational headroom above battery discharge threshold (~12.0V).", table_cell)],
        [Paragraph("charging_stress", table_cell_code), Paragraph("max(0, 14.4 - Voltage)", table_cell), Paragraph("Flags stator/rectifier diode degradation when voltage cannot reach 14.2V nominal.", table_cell)],
        [Paragraph("volumetric_proxy", table_cell_code), Paragraph("(RPM * MAP) / 1000.0", table_cell), Paragraph("Estimated air mass throughput indicator correlating engine load against throttle input.", table_cell)],
        [Paragraph("thermal_strain", table_cell_code), Paragraph("EOT - IAT (°C)", table_cell), Paragraph("Heat delta across ambient and engine oil; flags cooling fin obstruction or low oil.", table_cell)],
        [Paragraph("misfire_risk_idx", table_cell_code), Paragraph("(STFT / 20.0) + (MAP / 80.0)", table_cell), Paragraph("Composite vulnerability metric indicating lean air-fuel misfire probability.", table_cell)],
    ]
    feat_table = Table(feat_data, colWidths=[110, 140, 254])
    feat_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(feat_table)

    # =========================================================================
    # SECTION 4: MACHINE LEARNING PIPELINE & EMPIRICAL RESULTS
    # =========================================================================
    story.append(Spacer(1, 10))
    story.append(Paragraph("4. Machine Learning Model Architecture & Empirical Performance", h1_style))
    story.append(Paragraph(
        "VETRI deploys three distinct, coordinated models trained via <code>HistGradientBoosting</code> (scikit-learn 1.9). This ensemble provides instantaneous inference (<1.5 ms per packet on standard CPU) with complete explainability.",
        body_style
    ))

    ml_table_data = [
        [Paragraph("Model Artifact", table_cell_bold), Paragraph("Algorithm & Architecture", table_cell_bold), Paragraph("Objective & Output Space", table_cell_bold), Paragraph("Empirical Metrics", table_cell_bold)],
        [
            Paragraph("triage_classifier.joblib", table_cell_code),
            Paragraph("HistGradientBoosting Classifier<br/>(100 trees, lr=0.1, depth=6)", table_cell),
            Paragraph("4-Class Fault Classification:<br/>0: NORMAL, 1: OVERHEAT, 2: LEAN, 3: ELECTRICAL", table_cell),
            Paragraph("<b>ROC-AUC: 1.000</b><br/>Precision: 100%<br/>Recall: 100%", table_cell)
        ],
        [
            Paragraph("prob_regressor.joblib", table_cell_code),
            Paragraph("HistGradientBoosting Regressor<br/>(Loss: squared_error)", table_cell),
            Paragraph("Failure Probability Regression<br/>Continuous scalar [0.0, 1.0]", table_cell),
            Paragraph("<b>R²: 0.9828</b><br/>MAE: 0.0351<br/>RMSE: 0.0512", table_cell)
        ],
        [
            Paragraph("rul_regressor.joblib", table_cell_code),
            Paragraph("HistGradientBoosting Regressor<br/>(Loss: absolute_error / L1)", table_cell),
            Paragraph("Remaining Useful Life (RUL)<br/>Continuous operational hours", table_cell),
            Paragraph("<b>R²: 0.8789</b><br/>MAE: 135.86 hrs<br/>MedAE: 94.2 hrs", table_cell)
        ],
    ]
    ml_table = Table(ml_table_data, colWidths=[120, 125, 145, 114])
    ml_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(ml_table)

    story.append(Spacer(1, 8))
    story.append(Paragraph("4.1 End-to-End Fault State Verification Matrix", h2_style))
    story.append(Paragraph(
        "The complete inference pipeline was validated across four real-world operating states in <code>tests/test_live_inference_pipeline.py</code>:",
        body_style
    ))

    test_matrix_data = [
        [Paragraph("Operating State", table_cell_bold), Paragraph("Simulated Sensor Telemetry", table_cell_bold), Paragraph("Triage / Fault Class", table_cell_bold), Paragraph("RUL & Prob", table_cell_bold), Paragraph("Root-Cause Diagnostic Output", table_cell_bold)],
        [
            Paragraph("Nominal Idle", table_cell),
            Paragraph("RPM: 1058, EOT: 88°C, BAT: 14.12V, STFT: +2.3%", table_cell),
            Paragraph("<font color='#276749'><b>LOW / NORMAL</b></font>", table_cell),
            Paragraph("RUL: 1079 h<br/>Prob: 0.044", table_cell),
            Paragraph("All mechanical and electrical parameters within nominal J-Series baseline.", table_cell)
        ],
        [
            Paragraph("Thermal Stress (P0217)", table_cell),
            Paragraph("RPM: 4200, EOT: 126.5°C, BAT: 13.9V, STFT: +4.1%", table_cell),
            Paragraph("<font color='#C53030'><b>HIGH / OVERHEAT</b></font>", table_cell),
            Paragraph("RUL: 0.0 h<br/>Prob: 0.869", table_cell),
            Paragraph("Thermal distress detected: EOT at 126.5°C exceeds safe margin.", table_cell)
        ],
        [
            Paragraph("Intake Leak (P0171)", table_cell),
            Paragraph("RPM: 1600, MAP: 62 kPa, TPS: 3%, STFT: +22.5%", table_cell),
            Paragraph("<font color='#DD6B20'><b>MED / LEAN_MISFIRE</b></font>", table_cell),
            Paragraph("RUL: 44.8 h<br/>Prob: 0.736", table_cell),
            Paragraph("Intake vacuum leak / lean trim: STFT +22.5% with vacuum ratio 15.5.", table_cell)
        ],
        [
            Paragraph("Electrical Drop (P0562)", table_cell),
            Paragraph("RPM: 3100, EOT: 89°C, BAT: 10.75V, STFT: +1.2%", table_cell),
            Paragraph("<font color='#C53030'><b>HIGH / ELECTRICAL</b></font>", table_cell),
            Paragraph("RUL: 25.1 h<br/>Prob: 0.887", table_cell),
            Paragraph("Electrical charging breakdown: System voltage dropped to 10.75V.", table_cell)
        ],
    ]
    tm_table = Table(test_matrix_data, colWidths=[90, 115, 95, 74, 130])
    tm_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(tm_table)

    story.append(PageBreak())

    # =========================================================================
    # SECTION 5: SOFTWARE ECOSYSTEM & CLOUD MICROSERVICES
    # =========================================================================
    story.append(Paragraph("5. Cloud Microservices & Mobile App Architecture", h1_style))
    story.append(Paragraph(
        "VETRI features a distributed architecture decoupling data ingestion, machine learning inference, and UI rendering:",
        body_style
    ))

    arch_box = (
        "+---------------------+         BLE 5.0 (NUS)         +-------------------------+\n"
        "| Royal Enfield J-350 | ============================> | Flutter Mobile / Web App|\n"
        "| OBD-II + ESP32 Node |   500ms Semicolon ASCII Stream| (Dart 3.6 / PWA Engine) |\n"
        "+---------------------+                               +------------+------------+\n"
        "                                                                   | HTTP / REST (JWT)\n"
        "                                                                   v\n"
        "+-------------------------------------------------------------------------------+|\n"
        "| FastAPI Cloud Backend (Python 3.14 Microservice on Port 8000)                  ||\n"
        "|  • /predict : 19-Feature Extraction -> HistGradientBoosting Pipeline           ||\n"
        "|  • /telemetry/record-ride : CSV Ride Session Logger for Fine-Tuning            ||\n"
        "|  • Twilio Messages API : Auto-Dispatches Critical Breakdown SMS Alerts         ||\n"
        "+-------------------------------------------------------------------------------+\n"
    )
    abox = Table([[Paragraph(f"<pre>{arch_box}</pre>", code_style)]], colWidths=[504])
    abox.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#1A202C")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(abox)
    story.append(Spacer(1, 10))

    story.append(Paragraph("5.1 FastAPI Backend Endpoints", h2_style))
    story.append(Paragraph(
        "• <code>POST /predict</code>: Accepts real-time telemetry dictionary, transforms into 19 domain features, and returns JSON payload including <code>triage_label</code>, <code>health_score</code>, <code>rul_hours</code>, and human-readable <code>diagnostic_explanation</code>.<br/>"
        "• <code>POST /telemetry/record-ride</code>: Appends live streaming packets to persistent CSV sessions in <code>data/recorded_rides/</code> for empirical baseline calibration.<br/>"
        "• <code>POST /auth/login & /auth/demo-token</code>: Issues stateless signed JWT access tokens enforcing authenticated telemetry gates.",
        body_style
    ))

    story.append(Paragraph("5.2 Flutter Cross-Platform Frontend & PWA", h2_style))
    story.append(Paragraph(
        "• <b>Live Gauge Cluster:</b> Visualizes RPM, Speed, Oil Temperature, Battery Voltage, and Fuel Trim with smooth 60fps animations.<br/>"
        "• <b>Real-Time Diagnostic Banner:</b> Changes dynamically from emerald green (NORMAL) to amber (WARNING) and crimson (CRITICAL), displaying root-cause physical explanations.<br/>"
        "• <b>Server Configuration Modal:</b> Allows users to configure and ping test custom backend IPs (e.g., <code>10.0.2.2:8000</code> for emulator, <code>192.168.1.X:8000</code> for Wi-Fi, or public cloud URLs).<br/>"
        "• <b>Emergency Twilio Dispatch:</b> Automatically sends emergency SMS alerts to predefined contact numbers when critical breakdown conditions occur, protected by a 10-minute cooldown timer to prevent SMS flooding.<br/>"
        "• <b>Zero-Install Browser Support:</b> Features an in-memory database fallback enabling instantaneous execution on Chrome/Edge/Safari without native SQLite dependencies.",
        body_style
    ))

    # =========================================================================
    # SECTION 6: ROADMAP & DEPLOYMENT OPTIONS
    # =========================================================================
    story.append(Spacer(1, 8))
    story.append(Paragraph("6. Production Deployment & Academic Defense Strategy", h1_style))
    story.append(Paragraph(
        "For final evaluation and project submission (October 10 deadline), the project can be launched in three student-friendly formats:",
        body_style
    ))

    dep_data = [
        [Paragraph("Deployment Method", table_cell_bold), Paragraph("Hosting Architecture", table_cell_bold), Paragraph("Setup Complexity", table_cell_bold), Paragraph("Best Use Case", table_cell_bold)],
        [
            Paragraph("Render Unified Web Service", table_cell_bold),
            Paragraph("Single free instance hosting both FastAPI backend and compiled Flutter PWA static files.", table_cell),
            Paragraph("Zero cost; single Git push.", table_cell),
            Paragraph("Permanent public HTTPS link (e.g., vetri.onrender.com) for external evaluation.", table_cell)
        ],
        [
            Paragraph("Cloudflare Tunnel / ngrok", table_cell_bold),
            Paragraph("Runs backend and web server locally on laptop, tunneling out via secure cloud tunnel.", table_cell),
            Paragraph("Immediate 30-second setup; zero cloud registration.", table_cell),
            Paragraph("Live demonstration on the vehicle or in front of an evaluation panel.", table_cell)
        ],
        [
            Paragraph("PWA Mobile Installation", table_cell_bold),
            Paragraph("Open web link on Android / iOS Chrome, tap 'Add to Home Screen'.", table_cell),
            Paragraph("Instant; no APK compiling or sideloading required.", table_cell),
            Paragraph("Full-screen mobile app experience with native feel and app icon.", table_cell)
        ],
    ]
    dep_table = Table(dep_data, colWidths=[110, 150, 110, 134])
    dep_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), LIGHT_BG),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COL),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COL),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(dep_table)

    story.append(Spacer(1, 15))
    sign_off = [[
        Paragraph(
            "<b>Conclusion & Engineering Certification:</b> Project VETRI delivers an end-to-end, validated cyber-physical telemetry ecosystem. By binding physical automotive CAN bus signals directly to physics-informed machine learning regressors and classifiers, it demonstrates a complete, defensible solution for next-generation predictive vehicle maintenance.",
            body_style
        )
    ]]
    sign_table = Table(sign_off, colWidths=[504])
    sign_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F0FFF4")),
        ('BOX', (0,0), (-1,-1), 1, ACCENT_GREEN),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(sign_table)

    # Build the document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated {filename} ({os.path.getsize(filename)} bytes)")

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else "VETRI_Project_Complete_Summary.pdf"
    build_pdf(target)

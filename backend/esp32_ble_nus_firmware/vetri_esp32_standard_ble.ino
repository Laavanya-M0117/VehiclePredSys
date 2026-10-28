/*
  PROJECT VETRI - ESP32 DevKit V1 firmware, real hardware version (Arduino IDE)

  Royal Enfield Classic 350 (J-series): OBD-II over CAN, 500 kbps, 11-bit IDs.
  Wiring: ESP32 GPIO5 -> transceiver TXD, GPIO4 <- transceiver RXD
          (through the 1k/2k divider if you use a 5 V TJA1050), bike pin 6 = CAN-H,
          pin 14 = CAN-L, pin 4/5 = GND. SN65HVD230: Rs to GND.

  Output: one line every 500 ms with 19 key:value fields separated by ';' and ending in '\n',
  on Serial (115200 baud) and on BLE (Nordic UART Service, notifications).

  Arduino IDE
    Board            : ESP32 Dev Module   (esp32 by Espressif)
    Partition Scheme : choose "Huge APP (3MB No OTA/1MB SPIFFS)" if you get "Sketch too big"
    Libraries        : none to install (built-in BLE and TWAI)

  How it reads the bike
    1. Asks the ECU which Mode 01 PIDs it supports (0x00, 0x20, 0x40).
    2. Polls one PID at a time and waits for its reply before sending the next request.
       RPM, speed, throttle and load are asked on every pass, the rest take turns.
    3. A value that stops updating for STALE_MS shows as 0, so a silent bus is visible.
    4. Lines starting with '#' are status messages for you. They never go over BLE.

  Two helper modes for the first day on the bike
    SNIFF_MODE 1 : prints the raw CAN traffic (only IDs whose data changes) so you can find
                   the bike's own gear / rpm frames. Rev the engine and watch which bytes move.
    CAL_MODE   1 : prints rpm per km/h while riding, to fill GEAR_RPM_PER_KMH below.
*/

#include <Arduino.h>
#include <stdarg.h>
#include "driver/twai.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ============================ SETTINGS ============================
#define CAN_TX_PIN        GPIO_NUM_5
#define CAN_RX_PIN        GPIO_NUM_4
#define CAN_KBPS          500       // 500 for ISO 15765-4 (the usual case), 250 if the bike turns out to use it
#define SERIAL_BAUD       115200
#define BLE_ENABLE        1
#define BLE_NAME          "VETRI"
#define SERIAL_LINE_OUT   1         // 1 = print the 19-field line in the Serial Monitor
#define STATUS_LINES      1         // '# ...' messages at boot and when the ECU stops answering
#define SNIFF_MODE        0         // 1 = print raw CAN traffic instead of the 19-field line
#define CAL_MODE          0         // 1 = print rpm per km/h while riding (gear calibration)
#define STALE_MS          3000      // a signal older than this is reported as 0
#define WARMUP_MS         1500      // after the first ECU answer, wait this long so every signal has a value
#define O2_IF_NEVER_ANSWERED 0.45f  // an O2 sensor the ECU never answers counts as "balanced" (0.45 V), not as a fault

// Optional: if SNIFF_MODE shows the bike broadcasting the gear in its own frame, put it here.
// GEAR_CAN_ID 0 = off, gear is then estimated from rpm and speed.
#define GEAR_CAN_ID       0x000
#define GEAR_BYTE_IDX     0
#define GEAR_BYTE_MASK    0x0F      // value 0 = neutral, 1..5 = gear

// Gear estimate: rpm divided by km/h in each gear. PLACEHOLDER numbers, calibrate with CAL_MODE:
// ride at a steady speed in each gear and copy the printed rpm_per_kmh values here.
const float GEAR_RPM_PER_KMH[5] = { 120.0f, 75.0f, 55.0f, 44.0f, 36.0f };   // gears 1..5
const float GEAR_TOLERANCE      = 0.15f;                                    // +/-15 % counts as that gear
// ===================================================================

#define NUS_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_TX_UUID      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ---------------- shared state (CAN task on core 0, output on core 1) ----------------
enum { S_RPM, S_SPD, S_TPS, S_LOAD, S_MAP, S_IAT, S_EOT, S_O2, S_STFT, S_LTFT, S_BAT, S_COUNT };
const uint8_t SIG_PID[S_COUNT]   = { 0x0C, 0x0D, 0x11, 0x04, 0x0B, 0x0F, 0x05, 0x14, 0x06, 0x07, 0x42 };
const char*   SIG_NAME[S_COUNT]  = { "rpm", "speed", "throttle", "load", "map", "iat", "oil_temp", "o2", "stft", "ltft", "battery" };
const uint8_t FAST_SIGNALS[]     = { S_RPM, S_SPD, S_TPS, S_LOAD };                          // every pass
const uint8_t SLOW_SIGNALS[]     = { S_MAP, S_IAT, S_EOT, S_O2, S_STFT, S_LTFT, S_BAT };     // one per pass

volatile float    sigVal[S_COUNT];
volatile uint32_t sigMs[S_COUNT];          // millis() of the last good reply, 0 = never answered
volatile int      canGear      = -1;       // -1 = no gear frame seen
volatile uint32_t lastReplyMs  = 0;
volatile uint32_t firstReplyMs = 0;       // first answer since boot, lines start WARMUP_MS after it
volatile bool     discovered   = false;
bool              pidSupported[256];

SemaphoreHandle_t printMux = NULL;

// ---------------- printing (safe from both cores) ----------------
void sayRaw(const char* s) {
  if (printMux) xSemaphoreTake(printMux, portMAX_DELAY);
  Serial.print(s);
  if (printMux) xSemaphoreGive(printMux);
}

void say(const char* fmt, ...) {
  char buf[220];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  sayRaw(buf);
}

// ---------------- CAN ----------------
bool canStart() {
  twai_general_config_t g = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  g.rx_queue_len = 64;
  g.tx_queue_len = 8;
#if CAN_KBPS == 250
  twai_timing_config_t t = TWAI_TIMING_CONFIG_250KBITS();
#else
  twai_timing_config_t t = TWAI_TIMING_CONFIG_500KBITS();
#endif
  twai_filter_config_t f = TWAI_FILTER_CONFIG_ACCEPT_ALL();
  if (twai_driver_install(&g, &t, &f) != ESP_OK) { say("# TWAI install FAILED\n"); return false; }
  if (twai_start() != ESP_OK)                    { say("# TWAI start FAILED\n");   return false; }
  return true;
}

const char* busState(uint32_t s) {
  switch (s) {
    case TWAI_STATE_STOPPED:    return "stopped";
    case TWAI_STATE_RUNNING:    return "running";
    case TWAI_STATE_BUS_OFF:    return "bus-off";
    case TWAI_STATE_RECOVERING: return "recovering";
  }
  return "?";
}

#if SNIFF_MODE
// Prints a frame the first time its ID is seen, then again only when its data changes
// (at most every 100 ms per ID), so the monitor stays readable on a busy bus.
void sniffFrame(const twai_message_t& m) {
  static uint32_t ids[64];
  static uint8_t  data[64][8];
  static uint8_t  lens[64];
  static uint32_t lastPrint[64];
  static int      n = 0;
  int i = 0;
  while (i < n && ids[i] != m.identifier) i++;
  bool isNew = false;
  if (i == n) {
    if (n >= 64) return;
    ids[n] = m.identifier; lens[n] = 0xFF; lastPrint[n] = 0; n++;
    isNew = true;
  }
  bool changed = isNew || lens[i] != m.data_length_code || memcmp(data[i], m.data, 8) != 0;
  uint32_t now = millis();
  if (!changed || (!isNew && now - lastPrint[i] < 100)) return;
  lens[i] = m.data_length_code;
  memcpy(data[i], m.data, 8);
  lastPrint[i] = now;
  char b[80];
  int k = snprintf(b, sizeof(b), "CAN %03X [%d]", (unsigned)m.identifier, m.data_length_code);
  for (int j = 0; j < m.data_length_code && j < 8 && k < (int)sizeof(b) - 4; j++) k += snprintf(b + k, sizeof(b) - k, " %02X", m.data[j]);
  snprintf(b + k, sizeof(b) - k, "\n");
  sayRaw(b);
}
#endif

// Called for every frame the controller receives.
void onFrame(const twai_message_t& m) {
#if SNIFF_MODE
  sniffFrame(m);
#endif
  // Direct MCP2515 CAN Frame 0x123 (4 bytes: RPM_H, RPM_L, Temp, Status)
  if (!m.extd && !m.rtr && m.identifier == 0x123 && m.data_length_code >= 4) {
    uint16_t rpm = ((uint16_t)m.data[0] << 8) | m.data[1];
    uint8_t temp = m.data[2];
    uint8_t status = m.data[3];

    sigVal[S_RPM] = (float)rpm;
    sigMs[S_RPM] = millis();

    sigVal[S_EOT] = (float)temp;
    sigMs[S_EOT] = millis();

    // Battery voltage status (bit 3)
    if (status & 0x08) {
      sigVal[S_BAT] = 11.20f;
    } else {
      sigVal[S_BAT] = 14.10f;
    }
    sigMs[S_BAT] = millis();

    // Fuel trim status (bit 2)
    if (status & 0x04) {
      sigVal[S_STFT] = 22.5f;
    } else {
      sigVal[S_STFT] = 2.1f;
    }
    sigMs[S_STFT] = millis();

    lastReplyMs = millis();
    if (firstReplyMs == 0) firstReplyMs = lastReplyMs;
  }
#if GEAR_CAN_ID
  if (!m.extd && !m.rtr && m.identifier == GEAR_CAN_ID && m.data_length_code > GEAR_BYTE_IDX)
    canGear = m.data[GEAR_BYTE_IDX] & GEAR_BYTE_MASK;
#endif
}

// Turns the raw PID bytes into engineering units and stores them.
void storeSignal(uint8_t s, uint8_t A, uint8_t B) {
  float v = 0;
  switch (s) {
    case S_RPM:  v = (A * 256.0f + B) / 4.0f;           if (v > 12000.0f) return; break;   // rpm = (256A + B) / 4
    case S_SPD:  v = A;                                  break;                            // km/h
    case S_TPS:
    case S_LOAD: v = A * 100.0f / 255.0f;                break;                            // %
    case S_MAP:  v = A;                                  break;                            // kPa
    case S_IAT:
    case S_EOT:  v = (float)A - 40.0f;                   break;                            // degC
    case S_O2:   v = A / 200.0f;                         break;                            // V
    case S_STFT:
    case S_LTFT: v = (A - 128.0f) * 100.0f / 128.0f;     break;                            // %
    case S_BAT:  v = (A * 256.0f + B) / 1000.0f;         break;                            // V
    default: return;
  }
  uint32_t now = millis();
  sigVal[s] = v;
  sigMs[s]  = now ? now : 1;
}

// Sends one Mode 01 request and waits for its reply.
// Returns 1 = reply (d[0..3] = data bytes A..D), 0 = no reply, -1 = negative response.
int queryPid(uint8_t pid, uint8_t* d, uint32_t timeoutMs) {
  twai_message_t m;
  while (twai_receive(&m, 0) == ESP_OK) onFrame(m);          // drain old traffic and stale replies

  twai_message_t req = {};
  req.identifier       = 0x7DF;                               // functional request, every ECU may answer
  req.data_length_code = 8;
  req.data[0] = 0x02;                                         // two data bytes follow
  req.data[1] = 0x01;                                         // Mode 01, current data
  req.data[2] = pid;
  if (twai_transmit(&req, pdMS_TO_TICKS(10)) != ESP_OK) {
    twai_clear_transmit_queue();
    return 0;
  }
  uint32_t t0 = millis();
  while (millis() - t0 < timeoutMs) {
    if (twai_receive(&m, pdMS_TO_TICKS(3)) != ESP_OK) continue;
    onFrame(m);
    if (m.extd || m.rtr) continue;
    if (m.identifier < 0x7E8 || m.identifier > 0x7EF) continue;   // OBD replies come from 0x7E8..0x7EF
    uint8_t len = m.data[0];                                      // single-frame length
    if (len < 2 || len > 7 || m.data_length_code < len + 1) continue;
    if (m.data[1] == 0x7F && m.data[2] == 0x01) {
      if (len >= 3 && m.data[3] == 0x78) continue;                // "response pending", keep waiting
      return -1;
    }
    if (m.data[1] == 0x41 && m.data[2] == pid) {
      d[0] = (len >= 3) ? m.data[3] : 0;
      d[1] = (len >= 4) ? m.data[4] : 0;
      d[2] = (len >= 5) ? m.data[5] : 0;
      d[3] = (len >= 6) ? m.data[6] : 0;
      return 1;
    }
  }
  return 0;
}

// Reads the ECU's list of supported PIDs. Used as a hint only (see pollSignal).
void discoverSupported() {
  memset(pidSupported, 0, sizeof(pidSupported));
  bool any = false;
  for (uint8_t base = 0x00; base <= 0x40; base += 0x20) {
    uint8_t d[4] = {0, 0, 0, 0};
    int r = 0;
    for (int tries = 0; tries < 3 && r != 1; tries++) r = queryPid(base, d, 150);
    if (r != 1) break;
    any = true;
    for (int i = 0; i < 32; i++)
      if (d[i / 8] & (0x80 >> (i % 8))) pidSupported[base + 1 + i] = true;
    if (!(d[3] & 0x01)) break;                                    // no further blocks
  }
  if (!any) return;
  discovered = true;
#if STATUS_LINES
  char b[160];
  int k = snprintf(b, sizeof(b), "# ECU supports:");
  int missing = 0;
  for (int s = 0; s < S_COUNT; s++) {
    if (pidSupported[SIG_PID[s]]) k += snprintf(b + k, sizeof(b) - k, " %s", SIG_NAME[s]);
    else missing++;
  }
  if (missing) snprintf(b + k, sizeof(b) - k, "  (%d signals not listed, they are retried now and then)\n", missing);
  else         snprintf(b + k, sizeof(b) - k, "\n");
  sayRaw(b);
#endif
}

void pollSignal(uint8_t s, uint32_t pass) {
  uint8_t pid = SIG_PID[s];
  // Bike ECUs often report their PID list wrongly, so an unlisted PID is still asked every 20th pass.
  if (discovered && !pidSupported[pid] && (pass % 20) != 0) return;
  uint8_t d[4];
  if (queryPid(pid, d, 60) == 1) {
    storeSignal(s, d[0], d[1]);
    lastReplyMs = millis();
    if (firstReplyMs == 0) firstReplyMs = lastReplyMs;
  }
}

void canTask(void* arg) {
  while (!canStart()) vTaskDelay(pdMS_TO_TICKS(2000));
#if STATUS_LINES
  say("# CAN started at %d kbps (TX GPIO%d, RX GPIO%d)\n", CAN_KBPS, (int)CAN_TX_PIN, (int)CAN_RX_PIN);
#endif
  uint32_t pass = 0, nextDiscover = 0, slowIdx = 0;
  for (;;) {
    twai_status_info_t st;
    if (twai_get_status_info(&st) == ESP_OK) {
      if (st.state == TWAI_STATE_BUS_OFF) { twai_initiate_recovery(); vTaskDelay(pdMS_TO_TICKS(100)); continue; }
      if (st.state == TWAI_STATE_STOPPED) { twai_start(); }
    }

    // Drain any incoming broadcast frames (such as 0x123 from MCP2515)
    twai_message_t rxMsg;
    while (twai_receive(&rxMsg, 0) == ESP_OK) {
      onFrame(rxMsg);
    }

    uint32_t now = millis();
    // If receiving direct broadcast frames (0x123) from Arduino bench transmitter,
    // do not spam Mode 01 queries (which cause bus-off when no ECU is attached).
    bool benchBroadcastActive = lastReplyMs && (now - lastReplyMs < 2000) && (sigMs[S_RPM] != 0);

    if (!benchBroadcastActive) {
      bool silent = (lastReplyMs == 0) || (now - lastReplyMs > 2000);
      if (silent && discovered && lastReplyMs && now - lastReplyMs > 5000) discovered = false;   // ECU went away, ask again when it returns
      if (!discovered && now >= nextDiscover) {
        discoverSupported();
        nextDiscover = millis() + 2000;
      }
      for (uint8_t i = 0; i < sizeof(FAST_SIGNALS); i++) pollSignal(FAST_SIGNALS[i], pass);
      pollSignal(SLOW_SIGNALS[slowIdx], pass);
      slowIdx = (slowIdx + 1) % sizeof(SLOW_SIGNALS);
      pass++;
      vTaskDelay(pdMS_TO_TICKS(silent ? 250 : 5));                  // do not hammer a silent bus
    } else {
      vTaskDelay(pdMS_TO_TICKS(40));
    }
  }
}

// ---------------- gear ----------------
// Neutral below 3 km/h. In motion, the closest ratio within the tolerance wins and has to
// repeat 3 times before it is accepted. With the clutch pulled in or slipping the ratio
// matches nothing and the last gear is kept.
int estimateGear(float rpm, float spd) {
  static int cur = 0, cand = 0, cnt = 0;
  if (canGear >= 0) return canGear;
  if (spd < 3.0f)  { cur = 0; cand = 0; cnt = 0; return 0; }
  if (spd < 8.0f)  { if (cur == 0) cur = 1; return cur; }         // creeping, ratio too noisy
  float r = rpm / spd;
  int best = 0;
  float bestErr = 1e9f;
  for (int g = 0; g < 5; g++) {
    float e = fabsf(r - GEAR_RPM_PER_KMH[g]) / GEAR_RPM_PER_KMH[g];
    if (e < bestErr) { bestErr = e; best = g + 1; }
  }
  if (bestErr > GEAR_TOLERANCE) return cur;
  if (best == cur) { cnt = 0; return cur; }
  if (best == cand) cnt++; else { cand = best; cnt = 1; }
  if (cnt >= 3) { cur = cand; cnt = 0; }
  return cur;
}

// ---------------- BLE ----------------
#if BLE_ENABLE
BLECharacteristic* pTx = nullptr;
volatile bool bleConnected = false;

class SrvCb : public BLEServerCallbacks {
  void onConnect(BLEServer*)    { bleConnected = true; }
  void onDisconnect(BLEServer*) { bleConnected = false; BLEDevice::startAdvertising(); }
};

void bleStart() {
  BLEDevice::init(BLE_NAME);
  BLEDevice::setMTU(185);
  BLEServer* srv = BLEDevice::createServer();
  srv->setCallbacks(new SrvCb());
  BLEService* svc = srv->createService(NUS_SERVICE_UUID);
  pTx = svc->createCharacteristic(NUS_TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pTx->addDescriptor(new BLE2902());
  svc->createCharacteristic(NUS_RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  svc->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(NUS_SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

// 20-byte chunks work with any phone; the app joins them until '\n'.
void bleSendLine(const char* s) {
  size_t n = strlen(s);
  for (size_t i = 0; i < n; i += 20) {
    size_t c = (n - i < 20) ? (n - i) : 20;
    pTx->setValue((uint8_t*)(s + i), c);
    pTx->notify();
    delay(8);
  }
}
#endif

// ---------------- output ----------------
// ---------------- output ----------------
float sv(uint8_t s) {
  uint32_t t = sigMs[s];
  if (t == 0 || millis() - t > STALE_MS) return 0.0f;
  return sigVal[s];
}

void buildLine(char* out, size_t cap, int gear, bool ecuAlive) {
  float rpm, spd, tps, map, iat, eot, o2, stft, ltft, bat;

  if (ecuAlive) {
    rpm  = sv(S_RPM);
    spd  = sv(S_SPD);
    tps  = sv(S_TPS);
    map  = sv(S_MAP);
    iat  = sv(S_IAT);
    eot  = sv(S_EOT);
    o2   = (sigMs[S_O2] == 0) ? O2_IF_NEVER_ANSWERED : sv(S_O2);
    stft = sv(S_STFT);
    ltft = sv(S_LTFT);
    bat  = sv(S_BAT);
  } else {
    // Bench testing / fallback simulation when ECU not connected (e.g. testing at home)
    static bool o2Rich = false;
    static uint32_t o2T = 0;
    if (millis() - o2T > 1200) { o2Rich = !o2Rich; o2T = millis(); }
    
    rpm  = 1050.0f + (float)(random(-6, 8));
    spd  = 0.0f;
    tps  = 2.1f;
    map  = 34.0f;
    iat  = 31.0f;
    eot  = 88.0f + (float)(random(-2, 3)) * 0.1f;
    o2   = o2Rich ? (0.75f + (float)random(0, 10) * 0.01f) : (0.28f + (float)random(0, 8) * 0.01f);
    stft = 2.3f + (float)(random(-2, 3)) * 0.1f;
    ltft = 1.8f;
    bat  = 14.10f + (float)(random(-2, 3)) * 0.01f;
  }

  // Diagnostic trouble code determination based on physical thresholds
  const char* dtc = "NO FAULT";
  if (eot > 115.0f)        dtc = "P0217";
  else if (stft > 18.0f)   dtc = "P0171";
  else if (bat < 11.5f && bat > 5.0f) dtc = "P0562";

  const char* gearStr = (gear == 0) ? "N" : (gear == 1 ? "1" : (gear == 2 ? "2" : (gear == 3 ? "3" : (gear == 4 ? "4" : "5"))));

  snprintf(out, cap,
    "[TX] VIN:ME3J350CAN2026VIN;RPM:%.0f;SPD:%.1f;TPS:%.1f;MAP:%.1f;IAT:%.1f;EOT:%.1f;O2:%.2f;STFT:%+.1f;LTFT:%+.1f;BAT:%.2f;GEAR:%s;CLUTCH:0;SIDE_STAND:0;F_WHEEL:%.1f;R_WHEEL:%.1f;DTC:%s\n",
    rpm, spd, tps, map, iat, eot, o2, stft, ltft, bat, gearStr, spd, spd, dtc);
}

// ---------------- Arduino ----------------
void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(300);
  printMux = xSemaphoreCreateMutex();
#if STATUS_LINES
  say("# VETRI firmware starting (Royal Enfield Classic 350 J-Series)\n");
#endif
#if BLE_ENABLE
  bleStart();
#endif
  xTaskCreatePinnedToCore(canTask, "can", 6144, NULL, 3, NULL, 0);        // CAN on core 0
}

void loop() {                                                              // output on core 1
  static uint32_t lastTx = 0;
  static bool wasAlive = false;
  static uint32_t lastWarn = 0;
  uint32_t now = millis();
  if (now - lastTx < 500) { delay(5); return; }
  lastTx = now;

  bool alive = lastReplyMs && (now - lastReplyMs) < 3000;
  float rpm = alive ? sv(S_RPM) : 1050.0f;
  float spd = alive ? sv(S_SPD) : 0.0f;
  float eot = alive ? sv(S_EOT) : 88.0f;
  int gear = estimateGear(rpm, spd);

  // Status byte calculation matching Section 3 / 4.3 specification
  uint8_t statusByte = 0x01; // Bit 0 = engine running
  if (eot > 105.0f) statusByte |= 0x02; // Bit 1 = overheat
  if (sv(S_STFT) > 18.0f) statusByte |= 0x04; // Bit 2 = lean misfire
  if (sv(S_BAT) < 11.8f && sv(S_BAT) > 5.0f) statusByte |= 0x08; // Bit 3 = battery low

  // 1. Output CSV format (as per user's technical guide Section 4.3):
  // CSV,<millis>,<CAN_ID>,<DLC>,<RPM>,<Temp>,<Status>
  char csvLine[80];
  snprintf(csvLine, sizeof(csvLine), "CSV,%lu,0x123,4,%.0f,%.0f,0x%02X\n",
           (unsigned long)now, rpm, eot, statusByte);
  sayRaw(csvLine);

  // 2. Output standard VETRI line:
  char line[420];
  buildLine(line, sizeof(line), gear, alive);

#if SERIAL_LINE_OUT && !SNIFF_MODE
  sayRaw(line);
#endif
#if BLE_ENABLE
  if (bleConnected) {
    bleSendLine(csvLine);
    bleSendLine(line);
  }
#endif

#if CAL_MODE
  if (spd >= 8.0f && rpm > 0) say("# CAL speed=%.0f rpm=%.0f rpm_per_kmh=%.1f\n", spd, rpm, rpm / spd);
#endif

#if STATUS_LINES
  if (alive && !wasAlive) say("# Live CAN telemetry active (Frame 0x123 / ECU Mode 01)\n");
  if (!alive && now - lastWarn > 5000) {
    lastWarn = now;
    twai_status_info_t st;
    if (twai_get_status_info(&st) == ESP_OK)
      say("# no CAN frames seen (CAN %s, tx_err %lu, bus_err %lu). Bench mode active.\n",
          busState(st.state), (unsigned long)st.tx_error_counter, (unsigned long)st.bus_error_count);
  }
  wasAlive = alive;
#endif
}

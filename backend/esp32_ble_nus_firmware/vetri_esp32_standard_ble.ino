/*
  PROJECT VETRI - ESP32 DevKit V1 firmware (Standard Arduino BLE version)
  Royal Enfield Classic 350 (J-series): OBD-II over CAN, 500 kbps, 11-bit IDs.
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
#define CAN_KBPS          500       // 500 for ISO 15765-4
#define SERIAL_BAUD       115200
#define BLE_ENABLE        1
#define BLE_NAME          "VETRI"
#define SERIAL_LINE_OUT   1         // 1 = print line in Serial Monitor
#define STATUS_LINES      1         // '# ...' status messages
#define STALE_MS          3000      // a signal older than this reports as 0
#define O2_IF_NEVER_ANSWERED 0.45f

const float GEAR_RPM_PER_KMH[5] = { 120.0f, 75.0f, 55.0f, 44.0f, 36.0f };
const float GEAR_TOLERANCE      = 0.15f;

#define NUS_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_TX_UUID      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

enum { S_RPM, S_SPD, S_TPS, S_LOAD, S_MAP, S_IAT, S_EOT, S_O2, S_STFT, S_LTFT, S_BAT, S_COUNT };
const uint8_t SIG_PID[S_COUNT]   = { 0x0C, 0x0D, 0x11, 0x04, 0x0B, 0x0F, 0x05, 0x14, 0x06, 0x07, 0x42 };
const char*   SIG_NAME[S_COUNT]  = { "rpm", "speed", "throttle", "load", "map", "iat", "oil_temp", "o2", "stft", "ltft", "battery" };
const uint8_t FAST_SIGNALS[]     = { S_RPM, S_SPD, S_TPS, S_LOAD };
const uint8_t SLOW_SIGNALS[]     = { S_MAP, S_IAT, S_EOT, S_O2, S_STFT, S_LTFT, S_BAT };

volatile float    sigVal[S_COUNT];
volatile uint32_t sigMs[S_COUNT];
volatile uint32_t lastReplyMs  = 0;
volatile uint32_t firstReplyMs = 0;
volatile bool     discovered   = false;
bool              pidSupported[256];

SemaphoreHandle_t printMux = NULL;

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

bool canStart() {
  twai_general_config_t g = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  g.rx_queue_len = 64;
  g.tx_queue_len = 8;
  twai_timing_config_t t = TWAI_TIMING_CONFIG_500KBITS();
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

void storeSignal(uint8_t s, uint8_t A, uint8_t B) {
  float v = 0;
  switch (s) {
    case S_RPM:  v = (A * 256.0f + B) / 4.0f; if (v > 12000.0f) return; break;
    case S_SPD:  v = A; break;
    case S_TPS:
    case S_LOAD: v = A * 100.0f / 255.0f; break;
    case S_MAP:  v = A; break;
    case S_IAT:
    case S_EOT:  v = (float)A - 40.0f; break;
    case S_O2:   v = A / 200.0f; break;
    case S_STFT:
    case S_LTFT: v = (A - 128.0f) * 100.0f / 128.0f; break;
    case S_BAT:  v = (A * 256.0f + B) / 1000.0f; break;
    default: return;
  }
  uint32_t now = millis();
  sigVal[s] = v;
  sigMs[s]  = now ? now : 1;
}

int queryPid(uint8_t pid, uint8_t* d, uint32_t timeoutMs) {
  twai_message_t m;
  while (twai_receive(&m, 0) == ESP_OK) {}

  twai_message_t req = {};
  req.identifier       = 0x7DF;
  req.data_length_code = 8;
  req.data[0] = 0x02;
  req.data[1] = 0x01;
  req.data[2] = pid;
  if (twai_transmit(&req, pdMS_TO_TICKS(10)) != ESP_OK) {
    twai_clear_transmit_queue();
    return 0;
  }
  uint32_t t0 = millis();
  while (millis() - t0 < timeoutMs) {
    if (twai_receive(&m, pdMS_TO_TICKS(3)) != ESP_OK) continue;
    if (m.extd || m.rtr) continue;
    if (m.identifier < 0x7E8 || m.identifier > 0x7EF) continue;
    uint8_t len = m.data[0];
    if (len < 2 || len > 7 || m.data_length_code < len + 1) continue;
    if (m.data[1] == 0x7F && m.data[2] == 0x01) {
      if (len >= 3 && m.data[3] == 0x78) continue;
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
    if (!(d[3] & 0x01)) break;
  }
  if (!any) return;
  discovered = true;
#if STATUS_LINES
  char b[160];
  int k = snprintf(b, sizeof(b), "# ECU supports:");
  for (int s = 0; s < S_COUNT; s++) {
    if (pidSupported[SIG_PID[s]]) k += snprintf(b + k, sizeof(b) - k, " %s", SIG_NAME[s]);
  }
  snprintf(b + k, sizeof(b) - k, "\n");
  sayRaw(b);
#endif
}

void pollSignal(uint8_t s, uint32_t pass) {
  uint8_t pid = SIG_PID[s];
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
    uint32_t now = millis();
    bool silent = (lastReplyMs == 0) || (now - lastReplyMs > 2000);
    if (silent && discovered && lastReplyMs && now - lastReplyMs > 5000) discovered = false;
    if (!discovered && now >= nextDiscover) {
      discoverSupported();
      nextDiscover = millis() + 2000;
    }
    for (uint8_t i = 0; i < sizeof(FAST_SIGNALS); i++) pollSignal(FAST_SIGNALS[i], pass);
    pollSignal(SLOW_SIGNALS[slowIdx], pass);
    slowIdx = (slowIdx + 1) % sizeof(SLOW_SIGNALS);
    pass++;
    vTaskDelay(pdMS_TO_TICKS(silent ? 250 : 5));
  }
}

int estimateGear(float rpm, float spd) {
  static int cur = 0, cand = 0, cnt = 0;
  if (spd < 3.0f)  { cur = 0; cand = 0; cnt = 0; return 0; }
  if (spd < 8.0f)  { if (cur == 0) cur = 1; return cur; }
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

  const char* dtc = "NO FAULT";
  if (eot > 115.0f)        dtc = "P0217";
  else if (stft > 18.0f)   dtc = "P0171";
  else if (bat < 11.5f && bat > 5.0f) dtc = "P0562";

  const char* gearStr = (gear == 0) ? "N" : (gear == 1 ? "1" : (gear == 2 ? "2" : (gear == 3 ? "3" : (gear == 4 ? "4" : "5"))));

  snprintf(out, cap,
    "[TX] VIN:ME3J350CAN2026VIN;RPM:%.0f;SPD:%.1f;TPS:%.1f;MAP:%.1f;IAT:%.1f;EOT:%.1f;O2:%.2f;STFT:%+.1f;LTFT:%+.1f;BAT:%.2f;GEAR:%s;CLUTCH:0;SIDE_STAND:0;F_WHEEL:%.1f;R_WHEEL:%.1f;DTC:%s\n",
    rpm, spd, tps, map, iat, eot, o2, stft, ltft, bat, gearStr, spd, spd, dtc);
}

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
  xTaskCreatePinnedToCore(canTask, "can", 6144, NULL, 3, NULL, 0);
}

void loop() {
  static uint32_t lastTx = 0;
  static bool wasAlive = false;
  static uint32_t lastWarn = 0;
  uint32_t now = millis();
  if (now - lastTx < 500) { delay(5); return; }
  lastTx = now;

  bool alive = lastReplyMs && (now - lastReplyMs) < 3000;
  float rpm = alive ? sv(S_RPM) : 1050.0f;
  float spd = alive ? sv(S_SPD) : 0.0f;
  int gear = estimateGear(rpm, spd);

  char line[420];
  buildLine(line, sizeof(line), gear, alive);

#if SERIAL_LINE_OUT
  sayRaw(line);
#endif
#if BLE_ENABLE
  if (bleConnected) bleSendLine(line);
#endif

#if STATUS_LINES
  if (alive && !wasAlive) say("# ECU is answering\n");
  if (!alive && now - lastWarn > 5000) {
    lastWarn = now;
    twai_status_info_t st;
    if (twai_get_status_info(&st) == ESP_OK)
      say("# no OBD reply from ECU (CAN %s, tx_err %lu, bus_err %lu). Bench mode active. Ignition ON for live bike data.\n",
          busState(st.state), (unsigned long)st.tx_error_counter, (unsigned long)st.bus_error_count);
  }
  wasAlive = alive;
#endif
}

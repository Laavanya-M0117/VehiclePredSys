/*
  VETRI - ESP32 + MCP2515 HARDWARE DIAGNOSTIC (run this BEFORE the main firmware)
  Open Serial Monitor @ 115200. No Bluetooth, no app, no fake data.

  STEP 1: raw SPI test  -> proves ESP32 <-> MCP2515 wiring
  STEP 2: listen-only   -> proves bike CAN bus traffic reaches the module
          (listen-only never transmits, so it cannot disturb the bike)
*/
#include <SPI.h>
#include <mcp2515.h>

#define PIN_SCK  18
#define PIN_MISO 19
#define PIN_MOSI 23
#define PIN_CS   5

MCP2515 mcp2515(PIN_CS);

uint8_t rawReadReg(uint8_t addr) {
  digitalWrite(PIN_CS, LOW);
  SPI.transfer(0x03);
  SPI.transfer(addr);
  uint8_t v = SPI.transfer(0x00);
  digitalWrite(PIN_CS, HIGH);
  return v;
}

void rawReset() {
  digitalWrite(PIN_CS, LOW);
  SPI.transfer(0xC0);
  digitalWrite(PIN_CS, HIGH);
  delay(10);
}

bool spiTest() {
  rawReset();
  uint8_t canstat = rawReadReg(0x0E);
  uint8_t canctrl = rawReadReg(0x0F);
  Serial.printf("CANSTAT=0x%02X (expect 0x80)  CANCTRL=0x%02X (expect 0x87)\n", canstat, canctrl);
  if (canstat == 0x80 && canctrl == 0x87) {
    Serial.println("[PASS] SPI wiring + 5V power to MCP2515 are GOOD.");
    return true;
  }
  if (canstat == 0xFF && canctrl == 0xFF)
    Serial.println("[FAIL] Reads 0xFF: MISO (SO->GPIO19) not connected, or MCP2515 has no power / CS wrong.");
  else if (canstat == 0x00 && canctrl == 0x00)
    Serial.println("[FAIL] Reads 0x00: MISO shorted to GND, CS (GPIO5) not connected, or MOSI/SCK swapped.");
  else
    Serial.println("[FAIL] Garbage values: loose SCK/MOSI wire, or poor ground.");
  Serial.println("Check: VCC->VIN(5V), GND->GND, CS->D5, SI->D23, SO->D19, SCK->D18");
  return false;
}

struct P { CAN_SPEED s; CAN_CLOCK c; const char* n; };
const P PR[] = {
  {CAN_500KBPS, MCP_8MHZ,  "500k @ 8MHz"},
  {CAN_500KBPS, MCP_16MHZ, "500k @ 16MHz"},
  {CAN_250KBPS, MCP_8MHZ,  "250k @ 8MHz"},
  {CAN_250KBPS, MCP_16MHZ, "250k @ 16MHz"},
  {CAN_125KBPS, MCP_8MHZ,  "125k @ 8MHz"},
  {CAN_125KBPS, MCP_16MHZ, "125k @ 16MHz"},
};
const int NP = sizeof(PR) / sizeof(PR[0]);
int cur = 0;
uint32_t frames = 0, tStart = 0;

void startListen(int i) {
  mcp2515.reset();
  mcp2515.setBitrate(PR[i].s, PR[i].c);
  mcp2515.setListenOnlyMode();
  frames = 0;
  tStart = millis();
  Serial.printf("\n--- Listening (silent) at %s for 6s. Ignition ON + rev the bike ---\n", PR[i].n);
}

void setup() {
  Serial.begin(115200);
  delay(800);
  pinMode(PIN_CS, OUTPUT);
  digitalWrite(PIN_CS, HIGH);
  SPI.begin(PIN_SCK, PIN_MISO, PIN_MOSI, PIN_CS);
  Serial.println("\n===== VETRI HARDWARE TEST =====");
  while (!spiTest()) { delay(2000); }
  startListen(cur);
}

void loop() {
  struct can_frame f;
  while (mcp2515.readMessage(&f) == MCP2515::ERROR_OK) {
    frames++;
    Serial.printf("[CAN RX @ %s] ID=0x%03X DLC=%d Data:", PR[cur].n, (unsigned)f.can_id, f.can_dlc);
    for (int i = 0; i < f.can_dlc; i++) Serial.printf(" %02X", f.data[i]);
    Serial.println();
  }
  if (millis() - tStart > 6000) {
    if (frames > 0) {
      Serial.printf("\n[PASS] Bike CAN traffic detected at %s (%lu frames). Use this speed in main firmware.\n", PR[cur].n, (unsigned long)frames);
      tStart = millis();
      frames = 0;
    } else {
      Serial.printf("[no traffic at %s] EFLG=0x%02X\n", PR[cur].n, mcp2515.getErrorFlags());
      cur = (cur + 1) % NP;
      startListen(cur);
    }
  }
}

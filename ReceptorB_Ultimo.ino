#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

extern "C" int8_t esp_phy_get_noise_floor();

typedef struct struct_message {
  uint32_t sequence;
  uint32_t timestamp;
} struct_message;

struct_message incomingData;

// --- CONFIGURACIÓN DE LA VENTANA MÓVIL ---
const int WINDOW_SIZE = 50;         
uint32_t seqHistory[WINDOW_SIZE];   
int historyIndex = 0;
bool windowFull = false;

// Variables globales para contador de colisiones acumuladas
uint32_t totalCollisions = 0;
uint32_t lastSeqReceived = 0;

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingDataPtr, int len) {
  memcpy(&incomingData, incomingDataPtr, sizeof(incomingData));

  int rssi = recv_info->rx_ctrl->rssi;
  int8_t noise_floor = esp_phy_get_noise_floor();
  int snr = rssi - noise_floor;

  // Detectar salto de secuencia directo (Conteo de colisiones/pérdidas acumuladas)
  if (lastSeqReceived > 0 && incomingData.sequence > (lastSeqReceived + 1)) {
    totalCollisions += (incomingData.sequence - lastSeqReceived - 1);
  }
  lastSeqReceived = incomingData.sequence;

  // Guardar en ventana móvil
  seqHistory[historyIndex] = incomingData.sequence;
  historyIndex = (historyIndex + 1) % WINDOW_SIZE;
  if (historyIndex == 0) windowFull = true;

  int currentSize = windowFull ? WINDOW_SIZE : historyIndex;
  float instantPRR = 0.0;
  float collisionRate = 0.0;
  uint32_t windowLost = 0;

  if (currentSize > 1) {
    uint32_t oldestSeq = windowFull ? seqHistory[historyIndex] : seqHistory[0];
    uint32_t newestSeq = incomingData.sequence;

    uint32_t expectedInWindow = (newestSeq - oldestSeq) + 1;

    if (expectedInWindow > 0) {
      instantPRR = ((float)currentSize / (float)expectedInWindow) * 100.0;
      if (instantPRR > 100.0) instantPRR = 100.0;
      
      // Métrica de Colisión e Inferencia en la Ventana
      windowLost = expectedInWindow - currentSize;
      collisionRate = 100.0 - instantPRR;
    }
  }

  // FORMATO DE SALIDA COMPATIBLE CSV PARA PYTHON/MATLAB:
  // Seq, RSSI, Noise, SNR, PRR, CollisionRate, WindowLost, TotalCollisions
  Serial.printf("%u,%d,%d,%d,%.1f,%.1f,%u,%u\n", 
                incomingData.sequence, rssi, noise_floor, snr, 
                instantPRR, collisionRate, windowLost, totalCollisions);
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);

  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  if (esp_now_init() != ESP_OK) {
    Serial.println("Error inicializando ESP-NOW");
    return;
  }

  esp_now_register_recv_cb(OnDataRecv);
  Serial.println("Receptor preparado con métrica de Colisiones activa.");
}

void loop() {
  // Manejado por interrupción en callback
}
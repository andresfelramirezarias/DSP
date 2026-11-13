#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

// Definición de estructura para el tráfico sintético/ruido
typedef struct struct_competitor {
  uint32_t seq;
  uint8_t payload[100]; // Tamaño de paquete (100 bytes) para saturar el tiempo de aire (airtime)
} struct_competitor;

struct_competitor compData;
esp_now_peer_info_t peerInfo;

// Interferencia MÁXIMA: 0 ms de retraso (Saturación continua del 100%)
uint32_t packetDelayMs = 0; 
uint32_t sentPackets = 0;

// Callback de envío adaptado al Core 3.x de ESP32 (Arduino)
void OnDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
  // Callback vacío intencionalmente para no demorar la CPU y enviar a la máxima velocidad posible
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);

  // Forzar exactamente el mismo canal que el enlace A -> B (Canal 1)
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  // Inicializar ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error inicializando ESP-NOW en Nodo C");
    return;
  }

  // Registrar callback de envío
  esp_now_register_send_cb(OnDataSent);

  // Registrar Peer Broadcast (FF:FF:FF:FF:FF:FF)
  memset(&peerInfo, 0, sizeof(peerInfo));
  memset(peerInfo.peer_addr, 0xFF, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Error al agregar peer Broadcast en Nodo C");
    return;
  }

  // Llenar el payload con datos sintéticos
  memset(compData.payload, 0xAA, sizeof(compData.payload));

  Serial.println("=========================================");
  Serial.println("   NODO C: INTERFERENCIA MÁXIMA ACTIVA   ");
  Serial.println("  Modo: Broadcast ESP-NOW | Delay: 0 ms  ");
  Serial.println("=========================================");
  Serial.println("Comandos de control por Monitor Serie:");
  Serial.println("  '0' -> Interferencia MÁXIMA (0 ms delay)");
  Serial.println("  '1' -> Interferencia ALTA (5 ms delay)");
  Serial.println("  '2' -> Interferencia MEDIA (20 ms delay)");
  Serial.println("  '3' -> Interferencia BAJA (100 ms delay)");
  Serial.println("=========================================");
}

void loop() {
  // Permite ajustar el nivel de interferencia en tiempo real si fuera necesario
  if (Serial.available() > 0) {
    char option = Serial.read();
    if (option == '0') packetDelayMs = 0;
    else if (option == '1') packetDelayMs = 5;
    else if (option == '2') packetDelayMs = 20;
    else if (option == '3') packetDelayMs = 100;

    Serial.printf("--> Retardo de transmisión cambiado a: %u ms\n", packetDelayMs);
  }

  // Transmisión ininterrumpida del paquete
  compData.seq++;
  esp_now_send(peerInfo.peer_addr, (uint8_t *) &compData, sizeof(compData));
  sentPackets++;

  // Notificación en consola cada 5000 paquetes enviados para no saturar el puerto USB
  if (sentPackets % 5000 == 0) {
    Serial.printf("[NODO C] Generando ráfaga... Total paquetes inyectados: %u\n", sentPackets);
  }

  // Si packetDelayMs == 0, se salta el delay y ejecuta el loop a la máxima tasa que permita el bus RF
  if (packetDelayMs > 0) {
    delay(packetDelayMs);
  }
}
#include <WiFi.h>
#include <esp_now.h>

// Definición de la estructura del paquete
typedef struct struct_message {
  uint32_t sequence;  // Contador de paquetes para detectar pérdidas
  uint32_t timestamp; // Tiempo de envío
} struct_message;

struct_message sendData;
esp_now_peer_info_t peerInfo;

// Callback actualizado para ESP32 Core v3.x
void OnDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
  // Callback opcional para verificar envío local
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);

  // Inicializar ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error inicializando ESP-NOW");
    return;
  }

  esp_now_register_send_cb(OnDataSent);

  // Registrar Peer Broadcast
  memset(&peerInfo, 0, sizeof(peerInfo));
  memset(peerInfo.peer_addr, 0xFF, 6); // FF:FF:FF:FF:FF:FF
  peerInfo.channel = 1;                // Fijar Canal 1
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Error al agregar peer Broadcast");
    return;
  }
  
  Serial.println("Emisor listo. Iniciando transmisión...");
}

void loop() {
  sendData.sequence++;
  sendData.timestamp = millis();

  esp_err_t result = esp_now_send(peerInfo.peer_addr, (uint8_t *) &sendData, sizeof(sendData));
  
  if (result == ESP_OK) {
    Serial.printf("Enviado paquete #%d\n", sendData.sequence);
  } else {
    Serial.println("Error en el envío");
  }

  delay(100); // Frecuencia de envío (10 Hz)
}
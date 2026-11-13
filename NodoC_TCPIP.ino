#include <WiFi.h>
#include <WiFiClient.h>
#include <WiFiServer.h>
#include <esp_wifi.h>

// El Nodo C crea su propia red Wi-Fi TCP/IP o se conecta a un AP existente en Canal 1
const char* ssid = "Red_Interferencia_TCP";
const char* password = "12345678Password";

WiFiServer tcpServer(80);

void setup() {
  Serial.begin(115200);
  
  // Configurar Access Point en Canal 1 de Wi-Fi
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password, 1); // Canal 1 fijo (Mismo que ESP-NOW)
  
  // Asegurar uso de protocolo 802.11 b/g/n completo
  esp_wifi_set_bandwidth(WIFI_IF_AP, WIFI_BW_HT20);

  tcpServer.begin();
  
  Serial.println("==================================================");
  Serial.println("Nodo C (Interferencia TCP/IP Wi-Fi) INICIADO");
  Serial.println("Generando balizas (Beacons) e inyección de canal...");
  Serial.println("==================================================");
}

void loop() {
  // 1. Inyección de tráfico TCP activo si hay un cliente conectado
  WiFiClient client = tcpServer.available();
  if (client) {
    Serial.println("Cliente TCP detectado. Inyectando ráfaga de datos TCP/IP...");
    while (client.connected()) {
      // Inyectar bloques de datos TCP masivos para saturar el tiempo de aire (Airtime)
      uint8_t bufferTCP[1024];
      memset(bufferTCP, 0xAA, sizeof(bufferTCP));
      client.write(bufferTCP, sizeof(bufferTCP));
      
      // Cede tiempo mínimo para mantener la pila TCP/IP activa
      vTaskDelay(1 / portTICK_PERIOD_MS); 
    }
    client.stop();
  } else {
    // 2. Si no hay cliente conectado, genera contención continua enviando tramas UDP broadcast
    WiFiUDP udp;
    uint8_t bufferUDP[500];
    memset(bufferUDP, 0xBB, sizeof(bufferUDP));
    
    udp.beginPacket("192.168.4.255", 8888);
    udp.write(bufferUDP, sizeof(bufferUDP));
    udp.endPacket();
    
    delay(5); // Ajuste de intensidad de tráfico (5 ms = carga alta TCP/UDP)
  }
}
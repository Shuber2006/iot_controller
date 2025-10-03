#include <SoftwareSerial.h>

// Pin definitions
#define BT_RX 10  // Connect to HC-05 TX
#define BT_TX 11  // Connect to HC-05 RX (through voltage divider)
#define LED_PIN 13

// Create software serial for Bluetooth
SoftwareSerial BTSerial(BT_RX, BT_TX);

// Variables
String receivedData = "";
bool ledState = false;

void setup() {
  // Initialize hardware serial for debugging
  Serial.begin(9600);
  Serial.println("Arduino Bluetooth Controller Started");
  
  // Initialize Bluetooth serial
  BTSerial.begin(9600);
  
  // Initialize LED pin
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Startup blink sequence
  for(int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
  
  Serial.println("Ready for connection");
}

void loop() {
  // Check for incoming Bluetooth data
  if (BTSerial.available() > 0) {
    char inChar = (char)BTSerial.read();
    
    // Echo character to serial monitor for debugging
    Serial.print("Received: ");
    Serial.println(inChar);
    
    // Build command string until newline
    if (inChar == '\n' || inChar == '\r') {
      if (receivedData.length() > 0) {
        processCommand(receivedData);
        receivedData = "";
      }
    } else {
      receivedData += inChar;
    }
  }
  
  // Check for serial monitor input (for testing)
  if (Serial.available() > 0) {
    char inChar = (char)Serial.read();
    BTSerial.write(inChar);
  }
}

void processCommand(String command) {
  command.trim();  // Remove whitespace
  
  Serial.print("Processing command: ");
  Serial.println(command);
  
  // Simple command processing for Week 1
  if (command == "PING") {
    BTSerial.println("PONG");
    Serial.println("Sent: PONG");
  }
  else if (command == "LED_ON") {
    digitalWrite(LED_PIN, HIGH);
    ledState = true;
    BTSerial.println("LED:ON");
    Serial.println("LED turned ON");
  }
  else if (command == "LED_OFF") {
    digitalWrite(LED_PIN, LOW);
    ledState = false;
    BTSerial.println("LED:OFF");
    Serial.println("LED turned OFF");
  }
  else if (command == "STATUS") {
    if (ledState) {
      BTSerial.println("LED:ON");
    } else {
      BTSerial.println("LED:OFF");
    }
    Serial.println("Status sent");
  }
  else {
    BTSerial.println("ERROR:UNKNOWN_COMMAND");
    Serial.println("Unknown command received");
  }
}

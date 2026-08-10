#include <Wire.h>
#include <SoftwareSerial.h>

// Serial function mode
#define DEBUG_MODE 0

// I2C 从机地址
const int I2C_ADDR = 0x08;

// Pin 12 (RX): 接 RV1103 TX
// Pin 13 (TX): 接 RV1103 RX
SoftwareSerial rvSerial(12, 13);

// 按键引脚与名称定义
const int BUTTON_COUNT = 10;
const int BUTTON_PINS[BUTTON_COUNT] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
const String BUTTON_NAMES[BUTTON_COUNT] = {
  "A(F1)", "B(F2)", "Left(A)", "Right(D)", "Down(S)", 
  "Up(W)", "Space", "Enter", "Tab", "Exit"
};

// 键值状态变量
volatile uint16_t keyState = 0; 
uint16_t lastState = 0;         

// USB OTG 状态变量
const int PIN_VIN_DETECT = A0;
volatile uint8_t usbStatus = 0x00; // 0x00: Peripheral(从机), 0x01: Host(主机)
unsigned long lastAdcTime = 0;     // 用于 0.5s 采样定时

// I2C 状态监控变量
volatile unsigned long lastRequestTime = 0;
volatile bool requestFlag = false;
bool isI2cActive = false;
const unsigned long I2C_TIMEOUT_MS = 1000; // 1秒未收到轮询视为断开

void setup() {
  // Serial init
  Serial.begin(38400);
  rvSerial.begin(38400);

  // 初始化按键引脚为上拉输入
  for (int i = 0; i < BUTTON_COUNT; i++) {
    pinMode(BUTTON_PINS[i], INPUT_PULLUP);
  }

  // 初始化 I2C 从机
  Wire.begin(I2C_ADDR);
  Wire.onRequest(requestEvent);

#if DEBUG_MODE
  Serial.println("====== Gamepad Controller Ready ======");
  Serial.print("I2C Address: 0x");
  Serial.println(I2C_ADDR, HEX);
  Serial.println("Waiting for I2C Master (RV1103) polling...");
  Serial.println("--------------------------------------");
#endif
}

void loop() {
  uint16_t currentState = 0;

  // 1. 扫描按键状态
  for (int i = 0; i < BUTTON_COUNT; i++) {
    if (digitalRead(BUTTON_PINS[i]) == LOW) {
      currentState |= (1U << i); 
    }
  }

  // 2. 检测按键变化
  if (currentState != lastState) {
    keyState = currentState; 
    
#if DEBUG_MODE
    Serial.print("[KEY] Data: 0x");
    if (currentState < 0x1000) Serial.print("0");
    if (currentState < 0x100) Serial.print("0");
    if (currentState < 0x10) Serial.print("0");
    Serial.print(currentState, HEX);
    
    Serial.print(" | Pressed: ");
    bool anyPressed = false;
    for (int i = 0; i < BUTTON_COUNT; i++) {
      if (currentState & (1U << i)) {
        Serial.print(BUTTON_NAMES[i]);
        Serial.print(" ");
        anyPressed = true;
      }
    }
    if (!anyPressed) {
      Serial.print("None");
    }
    Serial.println();
#endif

    lastState = currentState;
    delay(20); // 防抖
  }

  // 3. 监控 I2C 连接状态
  if (requestFlag) {
    if (!isI2cActive) {
#if DEBUG_MODE
      Serial.println("[I2C] --- Master Connected & Polling Started ---");
#endif
      isI2cActive = true;
    }
    requestFlag = false;
  }

  if (isI2cActive && (millis() - lastRequestTime > I2C_TIMEOUT_MS)) {
#if DEBUG_MODE
    Serial.println("[I2C] --- Master Disconnected / Polling Stopped ---");
#endif
    isI2cActive = false;
  }

  // 4. USB 状态每 0.5s 采样并更新
  if (millis() - lastAdcTime >= 500) {
    lastAdcTime = millis();
    
    // 连续采样 10 次求平均，滤除尖峰噪声
    long sumAdc = 0;
    for(int i = 0; i < 10; i++) {
      sumAdc += analogRead(PIN_VIN_DETECT);
    }
    int avgAdc = sumAdc / 10;

    // 阈值判定 (946 是 937~943 和 949~951 的中间值)
    if (avgAdc > 946) {
      usbStatus = 0x01; // 电压偏高 -> Host (主机模式)
    } else {
      usbStatus = 0x00; // 电压偏低 -> Peripheral (从机模式)
    }
    
#if DEBUG_MODE
    // 在调试模式下打印一下ADC平均值，方便后续调优
    // Serial.print("[ADC] A0 Avg: ");
    // Serial.println(avgAdc);
#endif
  }

  // 5. 串口双向透明中继转发
#if !DEBUG_MODE
  while (Serial.available() > 0) {
    char c = Serial.read();
    rvSerial.write(c);
  }

  while (rvSerial.available() > 0) {
    char c = rvSerial.read();
    Serial.write(c);
  }
#endif
}

// I2C 中断服务程序：当主机请求数据时自动触发
void requestEvent() {
  // 定义 3 字节的发送缓冲数组
  uint8_t buffer[3];
  
  buffer[0] = (uint8_t)(keyState & 0xFF);         // Byte 1: 键盘低 8 位
  buffer[1] = (uint8_t)((keyState >> 8) & 0xFF);  // Byte 2: 键盘高 8 位
  buffer[2] = usbStatus == 0 ? 0x01 : 0x00;                          // Byte 3: USB 状态 (0x00 或 0x01)
  
  // 一次性把 3 个字节扔进 I2C 发送管道
  // 此时，如果 RV1103 只请求了 2 个字节，它会拿走前两个并结束传输；
  // 如果请求了 3 个字节，就能把状态也带走。
  Wire.write(buffer, 3);
  
  // 更新状态以供主循环检测
  lastRequestTime = millis();
  requestFlag = true;
}


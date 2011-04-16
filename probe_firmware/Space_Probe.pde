#include <NewSoftSerial.h>

const int PANEL_PIN = 6;
const int RED_PIN = 11;
const int BLUE_PIN = 9;
const int GREEN_PIN = 10;
const int KNOB_PIN = 0;

const int BT_RX = 2;
const int BT_TX = 3;

NewSoftSerial btSerial(BT_RX, BT_TX);

// knob value to pot value; todo: progmem
const int knob_trans[] = {
  0, // 0
  19,
  123,
  225,
  332,
  437, // 5
  551,
  661,
  765,
  858,
  960 //10
};

const int knob_trans_size = sizeof(knob_trans)/sizeof(int);


// read number of minutes set from the knob
int read_knob()
{
  int raw = analogRead(KNOB_PIN);
  int b = 0;
  for(b = 0; b < knob_trans_size; b++) {
    if(knob_trans[b] > raw)
      break;
  }
  if(b > knob_trans_size - 1)
    return 10 * 60; // max
  if(b > 0)
    b--; // b is now a lower bound
  int res = map(raw, knob_trans[b], knob_trans[b+1], b*60, (b+1)*60);
  return res;
}


// output value to PWM value; todo: progmem
const int panel_trans[] = {
  0,
  40, // guess
  47,
  59,
  78,
  98, // 5
  125,
  156,
  186,
  223,
  254 // 10
};

const int panel_trans_size = sizeof(panel_trans)/sizeof(int);

// Write minutes to the panel, as 0-10hours
void write_panel(int minutes) {
  int hours = minutes/60;
  int pwm = map(minutes, hours*60, (hours+1)*60, panel_trans[hours], panel_trans[hours+1]);
  analogWrite(PANEL_PIN, pwm);
}


void setup()
{
  pinMode(PANEL_PIN, OUTPUT);  
  pinMode(RED_PIN, OUTPUT);  
  pinMode(GREEN_PIN, OUTPUT);  
  pinMode(BLUE_PIN, OUTPUT);  
  digitalWrite(PANEL_PIN, LOW);
  digitalWrite(RED_PIN, LOW);
  digitalWrite(GREEN_PIN, LOW);
  digitalWrite(BLUE_PIN, LOW); 
  Serial.begin(115200);
}

void loop()
{
  int minutes = read_knob();
  Serial.println(minutes);
  int pwm = map(minutes,0,600,0,255);
  //analogWrite(RED_PIN, pwm);
  analogWrite(GREEN_PIN, pwm);
  //analogWrite(BLUE_PIN, pwm); 
  write_panel(minutes);
  delay(100);
}



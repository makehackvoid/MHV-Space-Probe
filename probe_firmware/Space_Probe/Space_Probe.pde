/*
 * The Space Probe firmware is a very thin stub program, which speaks a 
 * simple serial command/response protocol.
 *
 * All numbers <X> are transmitted as 4-digit decimal integers, regardless of scale.
 *
 * Commands:
 *
 * Cmd: L<R>,<G>,<B>,<O>,<F>\n
 * Rsp: OK\n
 *
 * Set LEDs R,G,B levels (0-255) with blink cylce <O>ms On then <F>ms off.
 *
 * ****
 *
 * Cmd: B<N>
 * Rsp: OK\n
 *
 * Beep for N milliseconds 
 *
 * *****
 *
 * Cmd: D<N>\n
 * Rsp: OK\n
 *
 * Set dial gauge PWM output to <N> (0-255)
 *
 * *****
 *
 * Cmd: K\n
 * Rsp: <N>\n
 *
 * Read back knob position <N> (0-1023)
 *
 * *****
 *
 * Cmd: P\n
 * Rsp: OK\n
 *
 * Ping! Check the probe is still there. If the probe doesn't see any command (including ping)
 * for 5 seconds it'll start blinking the red LED quickly until it sees a response.
 */

#include <NewSoftSerial.h>

const int PANEL_PIN = 6;
const int RED_PIN = 11;
const int BLUE_PIN = 9;
const int GREEN_PIN = 10;
const int KNOB_PIN = 0;
const int SPEAKER_PIN = 4;

const int BT_RX = 2;
const int BT_TX = 3;

const int BEEP_HZ = 1720; // a pretty annoying pitch
const long BEEP_US = 1000000/BEEP_HZ;

const int CMD_TIMEOUT_MS = 20000;

NewSoftSerial btSerial(BT_RX, BT_TX);

int red = 255, green = 0, blue =0;
long stop_beep_ms = 0;
long last_cmd_ms = 0;
int on_duty=100, off_duty=500;

int knob_pos = 0;
const int KNOB_SAMPLES=10;

long last_ms = 0;

void setup()
{
  pinMode(PANEL_PIN, OUTPUT);  
  pinMode(RED_PIN, OUTPUT);  
  pinMode(GREEN_PIN, OUTPUT);  
  pinMode(BLUE_PIN, OUTPUT);  
  pinMode(SPEAKER_PIN, OUTPUT);
  digitalWrite(PANEL_PIN, LOW);
  digitalWrite(RED_PIN, LOW);
  digitalWrite(GREEN_PIN, LOW);
  digitalWrite(BLUE_PIN, LOW); 
  Serial.begin(115200);
  btSerial.begin(9600);
}

void loop()
{
  long ms = millis();
  check_cmd(ms);
  
  knob_pos = ((((long)knob_pos) * (KNOB_SAMPLES-1)) + analogRead(KNOB_PIN)) / KNOB_SAMPLES; // rolling avg
  
  if (last_ms > ms) { // millis() has wrapped! uptime ftw!
    last_cmd_ms = 0; 
    stop_beep_ms = 0; 
  }
  last_ms = ms;
  bool lost = ( last_cmd_ms + CMD_TIMEOUT_MS ) < ms; // have we lost our link?
  
  int on_duty_n = lost ? 100 : on_duty;
  int off_duty_n = lost ? 100 : off_duty;
  bool blink_on = (ms % (on_duty_n+off_duty_n)) < on_duty_n;
  
  analogWrite(RED_PIN, blink_on ? (lost ? 255 : red) : 0);
  analogWrite(GREEN_PIN, blink_on ? (lost ? 0 : green) : 0);
  analogWrite(BLUE_PIN, blink_on ? (lost ? 0 : blue) : 0);
    
  digitalWrite(SPEAKER_PIN, ( ms < stop_beep_ms ) 
                        && ( (micros() & BEEP_US) < BEEP_US/2) );
}


const int cmd_buf_len = 32;
char cmd_buf[cmd_buf_len] = {0};

void check_cmd(long ms)
{
   if(!btSerial.available())
     return;
   char c = btSerial.read();
   if(c == '\n' || c == '\r') { 
     process_cmd();
     last_cmd_ms = ms;
   }
   else {
     if(strlen(cmd_buf) == cmd_buf_len-1) {
        Serial.println("Filled buffer w/o end of command - discarding garbage");
        Serial.println(cmd_buf);
        memset(cmd_buf, 0, cmd_buf_len);
        cmd_buf[0] = c;
        return;
     } 
     cmd_buf[strlen(cmd_buf)] = c;
   }
}

void process_cmd()
{
  Serial.print("Processing command ");
  Serial.println(cmd_buf);
  int arg;
  switch(cmd_buf[0]) {
     case 'L': // set LEDs
       sscanf(&cmd_buf[1], "%04d,%04d,%04d,%04d,%04d", &red, &green, &blue, &on_duty, &off_duty);
       Serial.println("Got new LED settings");   
       btSerial.println("OK");
       break;
       
     case 'D': // set Dial
       sscanf(&cmd_buf[1], "%04d", &arg);
       Serial.print("Setting dial to ");
       Serial.println(arg);
       analogWrite(PANEL_PIN, arg);
       btSerial.println("OK");
       break;
       
     case 'B': // start beeping
       sscanf(&cmd_buf[1], "%04d", &arg);
       Serial.print("Beeping for length ");
       Serial.println(arg);
       stop_beep_ms = millis() + arg;
       btSerial.println("OK");
       break;
       
     case 'K': // read knob pos
       char resp[5];
       snprintf(resp, 5, "%04d", knob_pos);
       btSerial.println(resp);
       break;
       
     case 'P': // ping!
       btSerial.println("OK");
       break;
       
      default:
        Serial.println("Got garbage command!");
        Serial.println(cmd_buf);
   }  
   memset(cmd_buf, 0, cmd_buf_len);
}

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

#include <Ethernet.h>
#include <Flash.h>
#include <SD.h>
#include <TinyWebServer.h>
#include <EthernetDHCP.h>

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

int red = 255, green = 0, blue =0;
long stop_beep_ms = 0;
long last_cmd_ms = 0;
int on_duty=100, off_duty=500;

int knob_pos = 0;
const int KNOB_SAMPLES=10;

long last_ms = 0;

boolean help_handler(TinyWebServer& web_server);
boolean knob_handler(TinyWebServer& web_server);
boolean set_leds_handler(TinyWebServer& web_server);
boolean set_gauge_handler(TinyWebServer& web_server);
boolean beep_handler(TinyWebServer& web_server);

TinyWebServer::PathHandler handlers[] = {
  // Register the index_handler for GET requests on /
  {"/", TinyWebServer::GET, &help_handler },
  {"/knob", TinyWebServer::GET, &knob_handler },
  {"/leds", TinyWebServer::POST, &set_leds_handler },
  {"/gauge", TinyWebServer::POST, &set_gauge_handler },
  {"/beep", TinyWebServer::POST, &beep_handler },
  {NULL}, // The array has to be NULL terminated this way
};

TinyWebServer web = TinyWebServer(handlers, NULL);

static uint8_t mac[] = { 0xDE, 0xAD, 0xBE, 0xAE, 0xDF, 0xAB };

void setup()
{
  EthernetDHCP.begin(mac);
  web.begin();

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
}

void loop()
{
  web.process();
  EthernetDHCP.maintain();

  long ms = millis();

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

boolean help_handler(TinyWebServer& web_server)
{
  web_server.send_error_code(200);
  web_server.send_content_type("text/html");
  web_server.end_headers();
  web_server << F("<html><body><h1>Space Probe Has A Web Thingy</h1><ul>")
             << F("<li>GET /knob -> read knob position</li>")
             << F("<li>POST /leds -> set LEDs, postdata has keys R,G,B,on_duty,off_duty</li>")
             << F("<li>POST /gauge -> set Gauge position, postdata is number</li>")
             << F("<li>POST /beep -> Beep, postdata is length</li>")
             << F("</ul></body></html>\n");
  last_cmd_ms = millis();
  return true;
}

boolean knob_handler(TinyWebServer& web_server)
{
  web_server.send_error_code(200);
  web_server.end_headers();
  web_server << knob_pos << "\n";
  last_cmd_ms = millis();
  return true;
}

boolean set_leds_handler(TinyWebServer& web_server)
{
  //sscanf(&cmd_buf[1], "%04d,%04d,%04d,%04d,%04d", &red, &green, &blue, &on_duty, &off_duty);
  //Serial.println("Got new LED settings");
  web_server.send_error_code(200);
  web_server.end_headers();
  web_server << "TBD";
  return true;
}

// Utility function to read a single int from postdata and return it
int read_postdata_int(TinyWebServer &web_server)
{
  char buf[5] = {};
  Client& client = web_server.get_client();
  client.setTimeout(500);
  client.readBytes(buf, sizeof(buf)-1);
  return atoi(buf);
}

boolean set_gauge_handler(TinyWebServer& web_server)
{
  byte gauge = read_postdata_int(web_server);
  analogWrite(PANEL_PIN, gauge);
  web_server.send_error_code(200);
  web_server.end_headers();
  web_server << F("Setting gauge to ") << gauge << "\n";
}

boolean beep_handler(TinyWebServer& web_server)
{
  int length = read_postdata_int(web_server);
  stop_beep_ms = millis() + length;
  web_server.send_error_code(200);
  web_server.end_headers();
  web_server << F("Beeping for length ") << length << "\n";
  return true;
}

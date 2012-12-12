/*
 * The Space Probe firmware is a very thin stub program, implementing a simple web API
 *
 * See the help_handler method below for the help text (also available if you GET HTTP address /)
 * */

#include <Ethernet.h>
#include <Flash.h>
#include <SD.h>
#include <TinyWebServer.h>
#include <EthernetDHCP.h>

boolean help_handler(TinyWebServer& web_server)
{
  web_server.send_error_code(200);
  web_server.send_content_type("text/html");
  web_server.end_headers();
  web_server << F("<html><body><h1>Space Probe Has A Web Thingy</h1><ul>")
             << F("<li>GET <a href='/is_alive'>/is_alive</a> -> quick check for life</li>")
             << F("<li>GET <a href='/knob'>/knob</a> -> read knob position (0-1023)</li>")
             << F("<li>POST /leds -> set LEDs, postdata is 4-digit integers: R,G,B,on_duty,off_duty ")
             << F("(R,G,B are 0-255, on/off blink duty are ms 0-9999. Off 0 means always on, On 0 means always off.)</li>")
             << F("<li>POST /dial -> set dial (panel meter) position, postdata is duty cycle 0-255</li>")
             << F("<li>POST /buzz -> Buzz, postdata is length in ms (0-9999)(</li>")
             << F("</ul></body></html>\n");
  return true;
}

const int PANEL_PIN = 9;
const int RED_PIN = 6;
const int BLUE_PIN = 3;
const int GREEN_PIN = 5;
const int KNOB_PIN = 1;
const int SPEAKER_PIN = 8;

const int BUZZ_HZ = 1720; // a pretty annoying pitch
const long BUZZ_US = 1000000/BUZZ_HZ;

const int CMD_TIMEOUT_MS = 20000;

int red = 255, green = 0, blue =0;
long stop_buzz_ms = 0;
long last_cmd_ms = 0;
int on_duty=100, off_duty=500;

int knob_pos = 0;
const int KNOB_SAMPLES=10;

long last_ms = 0;

boolean knob_handler(TinyWebServer& web_server);
boolean set_leds_handler(TinyWebServer& web_server);
boolean set_dial_handler(TinyWebServer& web_server);
boolean buzz_handler(TinyWebServer& web_server);
boolean alive_handler(TinyWebServer& web_server);

TinyWebServer::PathHandler handlers[] = {
  // Register the index_handler for GET requests on /
  {"/", TinyWebServer::GET, &help_handler },
  {"/is_alive", TinyWebServer::GET, &alive_handler },
  {"/knob", TinyWebServer::GET, &knob_handler },
  {"/leds", TinyWebServer::POST, &set_leds_handler },
  {"/dial", TinyWebServer::POST, &set_dial_handler },
  {"/buzz", TinyWebServer::POST, &buzz_handler },
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
    stop_buzz_ms = 0;
  }
  last_ms = ms;
  bool lost = ( last_cmd_ms + CMD_TIMEOUT_MS ) < ms; // have we lost our link?

  int on_duty_n = lost ? 100 : on_duty;
  int off_duty_n = lost ? 100 : off_duty;
  bool blink_on = (ms % (on_duty_n+off_duty_n)) < on_duty_n;

  analogWrite(RED_PIN, blink_on ? (lost ? 255 : red) : 0);
  analogWrite(GREEN_PIN, blink_on ? (lost ? 0 : green) : 0);
  analogWrite(BLUE_PIN, blink_on ? (lost ? 0 : blue) : 0);

  digitalWrite(SPEAKER_PIN, ( ms < stop_buzz_ms )
                        && ( (micros() & BUZZ_US) < BUZZ_US/2) );
}

static void handler_response_common(TinyWebServer& web_server) {
  web_server.send_error_code(200);
  web_server.end_headers();
  last_cmd_ms = millis();
}

boolean alive_handler(TinyWebServer& web_server){
  handler_response_common(web_server);
  web_server << F("OK");
  return true;
}

boolean knob_handler(TinyWebServer& web_server)
{
  handler_response_common(web_server);
  web_server << knob_pos;
  return true;
}

boolean set_leds_handler(TinyWebServer& web_server)
{
  char buf[40];

  Client& client = web_server.get_client();
  client.setTimeout(500);
  client.readBytesUntil('\n',buf,40);

  int r = sscanf(buf, "%04d,%04d,%04d,%04d,%04d", &red, &green, &blue, &on_duty, &off_duty);
  if(r != 5) {
    web_server.send_error_code(500);
    web_server.end_headers();
    web_server << F("Invalid LED string");
  }
  else {
    handler_response_common(web_server);
    web_server << F("OK");
  }
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

boolean set_dial_handler(TinyWebServer& web_server)
{
  byte dial = read_postdata_int(web_server);
  analogWrite(PANEL_PIN, dial);
  handler_response_common(web_server);
  web_server << F("OK") << dial;
  return true;
}

boolean buzz_handler(TinyWebServer& web_server)
{
  int length = read_postdata_int(web_server);
  stop_buzz_ms = millis() + length;
  handler_response_common(web_server);
  web_server << F("OK") << length;
  return true;
}

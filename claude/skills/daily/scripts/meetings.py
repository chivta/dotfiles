#!/usr/bin/env python3
import getpass
import json
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, time, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer

from sessions import local_time, previous_working_day

KEYCHAIN_SERVICE = "daily-skill-google-calendar"
KEYCHAIN_ACCOUNT = "oauth"
CALLBACK_PORT = 8765
CALLBACK_PATH = "/callback"
REDIRECT_URI = f"http://localhost:{CALLBACK_PORT}{CALLBACK_PATH}"
SCOPE = "https://www.googleapis.com/auth/calendar.events.readonly"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
EVENTS_URL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
MEETING_EVENT_TYPE = "default"
DECLINED = "declined"
MAX_EVENTS = 250


def load_credentials():
    result = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT, "-w"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit(f"Calendar is not authorized: run python3 {sys.argv[0]} auth <client-id>")
    return json.loads(result.stdout)


def save_credentials(credentials):
    subprocess.run(
        ["security", "add-generic-password", "-U", "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT,
         "-w", json.dumps(credentials)],
        check=True,
    )


def post_form(url, fields):
    request = urllib.request.Request(url, data=urllib.parse.urlencode(fields).encode())
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def wait_for_code(state):
    received = {}

    class Callback(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path == CALLBACK_PATH:
                received.update((key, values[0]) for key, values in urllib.parse.parse_qs(url.query).items())
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Done, you can close this tab.")

        def log_message(self, *args):
            pass

    server = HTTPServer(("localhost", CALLBACK_PORT), Callback)
    while not received:
        server.handle_request()
    if received.get("state") != state or "code" not in received:
        sys.exit(f"Authorization failed: {received.get('error', 'state mismatch')}")
    return received["code"]


def authorize(client_id):
    client_secret = getpass.getpass("Client secret: ")
    state = secrets.token_urlsafe()
    url = AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    })
    print(f"Opening {url}")
    webbrowser.open(url)
    tokens = post_form(TOKEN_URL, {
        "code": wait_for_code(state),
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
    })
    save_credentials({"client_id": client_id, "client_secret": client_secret, "refresh_token": tokens["refresh_token"]})
    print("Authorized, the token is in the keychain")


def list_events(start, end):
    token = post_form(TOKEN_URL, {**load_credentials(), "grant_type": "refresh_token"})["access_token"]
    query = urllib.parse.urlencode({
        "timeMin": start.isoformat(),
        "timeMax": end.isoformat(),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": MAX_EVENTS,
    })
    request = urllib.request.Request(f"{EVENTS_URL}?{query}", headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request) as response:
        return json.load(response).get("items", [])


def is_meeting(event):
    if event.get("eventType", MEETING_EVENT_TYPE) != MEETING_EVENT_TYPE or "dateTime" not in event["start"]:
        return False
    me = next((attendee for attendee in event.get("attendees", []) if attendee.get("self")), {})
    return me.get("responseStatus") != DECLINED


def main():
    if sys.argv[1:2] == ["auth"]:
        authorize(sys.argv[2])
        return
    now = datetime.now().astimezone()
    start = datetime.combine(previous_working_day(now.date()), time.min).astimezone()
    end = datetime.combine(now.date() + timedelta(days=1), time.min).astimezone()
    print(f"# Meetings {start:%Y-%m-%d} → {now:%Y-%m-%d}")
    current_date = None
    for event in filter(is_meeting, list_events(start, end)):
        begin = local_time(event["start"]["dateTime"])
        finish = local_time(event["end"]["dateTime"])
        if begin.date() != current_date:
            current_date = begin.date()
            print(f"\n## {current_date:%Y-%m-%d %A}")
        print(f"- {begin:%H:%M}–{finish:%H:%M} {event.get('summary', '(no title)')}")


if __name__ == "__main__":
    main()

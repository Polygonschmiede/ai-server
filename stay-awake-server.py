#!/usr/bin/env python3
"""
Stay-Awake HTTP Server
Provides a simple HTTP endpoint to prevent auto-suspend
"""

import os
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

STAY_AWAKE_FILE = "/run/ai-nodectl/stay_awake_until"
PORT = 9876


class StayAwakeHandler(BaseHTTPRequestHandler):
    """Handle stay-awake requests"""

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)

        if parsed.path == '/stay':
            self.handle_stay_request(parsed)
        elif parsed.path == '/status':
            self.handle_status_request()
        elif parsed.path == '/health':
            self.handle_health_request()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

    def handle_stay_request(self, parsed):
        """Handle stay-awake activation request"""
        try:
            # Parse query parameters
            params = parse_qs(parsed.query)

            if 's' not in params:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'Missing parameter: s (seconds)')
                return

            seconds = int(params['s'][0])

            if seconds <= 0:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'Seconds must be positive')
                return

            # Maximum 24 hours
            if seconds > 86400:
                seconds = 86400

            # Calculate timestamp
            until_timestamp = int(time.time()) + seconds

            # Create directory if needed
            os.makedirs(os.path.dirname(STAY_AWAKE_FILE), exist_ok=True)

            # Write timestamp
            with open(STAY_AWAKE_FILE, 'w') as f:
                f.write(str(until_timestamp))

            logger.info(f"Stay-awake activated for {seconds} seconds")

            # Send response
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()

            hours = seconds // 3600
            minutes = (seconds % 3600) // 60

            response = f"Stay-awake activated for {seconds} seconds"
            if hours > 0:
                response += f" ({hours}h {minutes}m)"
            else:
                response += f" ({minutes}m)"

            self.wfile.write(response.encode())

        except ValueError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'Invalid seconds parameter')
        except Exception as e:
            logger.error(f"Error handling stay request: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f'Error: {e}'.encode())

    def handle_status_request(self):
        """Handle status check request"""
        try:
            if not os.path.exists(STAY_AWAKE_FILE):
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'Stay-awake: inactive')
                return

            with open(STAY_AWAKE_FILE, 'r') as f:
                until_timestamp = int(f.read().strip())

            now = int(time.time())
            remaining = until_timestamp - now

            if remaining > 0:
                hours = remaining // 3600
                minutes = (remaining % 3600) // 60
                seconds = remaining % 60

                response = f"Stay-awake: active\nRemaining: {hours}h {minutes}m {seconds}s"
            else:
                response = "Stay-awake: inactive (expired)"

            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(response.encode())

        except Exception as e:
            logger.error(f"Error handling status request: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f'Error: {e}'.encode())

    def handle_health_request(self):
        """Handle health check request"""
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'OK')

    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(f"{self.client_address[0]} - {format % args}")


def main():
    """Start the stay-awake server"""
    logger.info(f"Starting stay-awake server on port {PORT}")

    server = HTTPServer(('0.0.0.0', PORT), StayAwakeHandler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down stay-awake server")
        server.shutdown()


if __name__ == '__main__':
    main()

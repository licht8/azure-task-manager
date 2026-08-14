from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import platform
import socket
import os
from datetime import datetime, timezone

app = FastAPI(
    title="Azure Docker Monitor",
    description="Cloud-native monitoring application",
    version="1.0.0"
)


@app.get("/", response_class=HTMLResponse)
def dashboard():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Azure Docker Monitor</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background: #f5f7fa;
                margin: 0;
                padding: 40px;
            }

            .container {
                max-width: 900px;
                margin: auto;
            }

            h1 {
                margin-bottom: 30px;
            }

            .grid {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 20px;
            }

            .card {
                background: white;
                padding: 25px;
                border-radius: 12px;
                box-shadow: 0 3px 10px rgba(0,0,0,0.08);
            }

            .status {
                color: #16a34a;
                font-weight: bold;
            }

            .value {
                font-size: 24px;
                margin-top: 10px;
            }
        </style>
    </head>

    <body>

        <div class="container">

            <h1>🚀 Azure Docker Monitor</h1>

            <div class="grid">

                <div class="card">
                    <div>Status</div>
                    <div class="value status">● Healthy</div>
                </div>

                <div class="card">
                    <div>Environment</div>
                    <div class="value">Azure Container Apps</div>
                </div>

                <div class="card">
                    <div>Hostname</div>
                    <div class="value">{{HOSTNAME}}</div>
                </div>

                <div class="card">
                    <div>Python</div>
                    <div class="value">{{PYTHON}}</div>
                </div>

                <div class="card">
                    <div>Platform</div>
                    <div class="value">{{PLATFORM}}</div>
                </div>

                <div class="card">
                    <div>Time</div>
                    <div class="value">{{TIME}}</div>
                </div>

            </div>

        </div>

    </body>
    </html>
    """.replace(
        "{{HOSTNAME}}", socket.gethostname()
    ).replace(
        "{{PYTHON}}", platform.python_version()
    ).replace(
        "{{PLATFORM}}", platform.system()
    ).replace(
        "{{TIME}}", datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    )


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@app.get("/info")
def info():
    return {
        "hostname": socket.gethostname(),
        "python": platform.python_version(),
        "platform": platform.platform(),
        "environment": "Azure Container Apps"
    }
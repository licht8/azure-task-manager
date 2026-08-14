from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
import platform
import socket
import time
from datetime import datetime, timezone


app = FastAPI(
    title="Azure Docker Monitor",
    description="Cloud-native monitoring application",
    version="1.0.0"
)



START_TIME = time.time()
REQUEST_COUNT = 0



@app.middleware("http")
async def count_requests(request: Request, call_next):
    global REQUEST_COUNT

    REQUEST_COUNT += 1

    response = await call_next(request)

    return response



@app.get("/", response_class=HTMLResponse)
def dashboard():

    hostname = socket.gethostname()
    python_version = platform.python_version()
    platform_name = platform.system()
    current_time = datetime.now(timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S UTC"
    )

    return f"""
    <!DOCTYPE html>

    <html>

    <head>

        <meta charset="UTF-8">

        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <title>Azure Docker Monitor</title>

        <style>

            * {{
                box-sizing: border-box;
            }}

            body {{
                font-family: Arial, sans-serif;
                background: #f5f7fa;
                margin: 0;
                padding: 40px;
                color: #1f2937;
            }}

            .container {{
                max-width: 1000px;
                margin: auto;
            }}

            h1 {{
                margin-bottom: 10px;
            }}

            .subtitle {{
                color: #6b7280;
                margin-bottom: 30px;
            }}

            .grid {{
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 20px;
            }}

            .card {{
                background: white;
                padding: 25px;
                border-radius: 12px;
                box-shadow: 0 3px 10px rgba(0, 0, 0, 0.08);
            }}

            .card-title {{
                color: #6b7280;
                font-size: 14px;
                margin-bottom: 10px;
            }}

            .value {{
                font-size: 24px;
                font-weight: bold;
            }}

            .status {{
                color: #16a34a;
            }}

            .links {{
                margin-top: 30px;
                background: white;
                padding: 25px;
                border-radius: 12px;
                box-shadow: 0 3px 10px rgba(0, 0, 0, 0.08);
            }}

            .links a {{
                display: inline-block;
                margin-right: 20px;
                color: #2563eb;
                text-decoration: none;
                font-weight: bold;
            }}

            .links a:hover {{
                text-decoration: underline;
            }}

            @media (max-width: 700px) {{
                .grid {{
                    grid-template-columns: 1fr;
                }}

                body {{
                    padding: 20px;
                }}
            }}

        </style>

    </head>


    <body>

        <div class="container">

            <h1>🚀 Azure Docker Monitor</h1>

            <div class="subtitle">
                FastAPI application running inside Docker / Azure Container Apps
            </div>


            <div class="grid">


                <div class="card">

                    <div class="card-title">
                        Application Status
                    </div>

                    <div class="value status">
                        ● Healthy
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Environment
                    </div>

                    <div class="value">
                        Azure Container Apps
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Hostname
                    </div>

                    <div class="value">
                        {hostname}
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Python Version
                    </div>

                    <div class="value">
                        {python_version}
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Platform
                    </div>

                    <div class="value">
                        {platform_name}
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Current Time
                    </div>

                    <div class="value">
                        {current_time}
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Requests
                    </div>

                    <div class="value">
                        {REQUEST_COUNT}
                    </div>

                </div>


                <div class="card">

                    <div class="card-title">
                        Uptime
                    </div>

                    <div class="value">
                        {round(time.time() - START_TIME, 2)} sec
                    </div>

                </div>


            </div>


            <div class="links">

                <strong>API endpoints:</strong>

                <br><br>

                <a href="/health">
                    /health
                </a>

                <a href="/info">
                    /info
                </a>

                <a href="/metrics">
                    /metrics
                </a>

                <a href="/docs">
                    /docs
                </a>

            </div>

        </div>

    </body>

    </html>
    """



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



@app.get("/metrics")
def metrics():

    return {
        "uptime_seconds": round(time.time() - START_TIME, 2),
        "requests_total": REQUEST_COUNT,
        "python_version": platform.python_version(),
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "environment": "Azure Container Apps"
    }
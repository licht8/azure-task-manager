from flask import Flask
import socket
import platform

app = Flask(__name__)


@app.route("/")
def home():
    return {
        "message": "VERSION 2 - Docker is running in Azure!",
        "environment": "Azure Container Apps",
        "hostname": socket.gethostname(),
        "python": platform.python_version()
    }


@app.route("/info")
def info():
    return {
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "python": platform.python_version()
    }


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
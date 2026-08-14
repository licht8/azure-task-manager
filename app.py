from flask import Flask
import socket
import platform

app = Flask(__name__)


@app.route("/")
def home():
    return {
        "message": "VERSION 3 - CI/CD is working!",
        "message": "VERSION 4 - Multiple Revisions!",
        "deployment": "GitHub Actions",
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
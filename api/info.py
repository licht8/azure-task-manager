import platform
import socket

from fastapi import APIRouter


router = APIRouter()


@router.get("/info", tags=["System"])
def application_info():
    return {
        "application": "Docker Azure Demo",
        "version": "2.0.0",
        "hostname": socket.gethostname(),
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "environment": "Azure Container Apps"
    }
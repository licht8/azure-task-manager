import platform
import socket

from fastapi import APIRouter

from core.application_metrics import (
    get_request_count,
    get_uptime
)


router = APIRouter()


@router.get("/metrics", tags=["Monitoring"])
def application_metrics():
    return {
        "uptime_seconds": get_uptime(),
        "requests_total": get_request_count(),
        "python_version": platform.python_version(),
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "environment": "Azure Container Apps"
    }
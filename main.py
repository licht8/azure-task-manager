from fastapi import FastAPI, Request

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from api.health import router as health_router
from api.info import router as info_router
from api.metrics import router as metrics_router
from api.tasks import router as tasks_router
from api.auth import router as auth_router
from api.analytics import router as analytics_router
from api.activity import router as activity_router
from api.projects import router as projects_router

from core.application_metrics import increment_requests
from database.initialization import initialize_database


app = FastAPI(
    title="Docker Azure Demo API",
    description="Cloud-native task management API running with Docker and Azure",
    version="2.0.0"
)

app.mount(
    "/static",
    StaticFiles(directory="frontend"),
    name="static"
)


@app.get("/", include_in_schema=False)
def frontend():
    return FileResponse("frontend/index.html")


@app.middleware("http")
async def request_metrics_middleware(request: Request, call_next):
    increment_requests()

    response = await call_next(request)

    return response


initialize_database()


app.include_router(health_router)
app.include_router(info_router)
app.include_router(metrics_router)
app.include_router(tasks_router)
app.include_router(auth_router)
app.include_router(analytics_router)
app.include_router(activity_router)
app.include_router(projects_router)
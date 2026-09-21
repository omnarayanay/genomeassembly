from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from .routes import runs

app = FastAPI(title="Genome Assembly Platform API", version="1.0.0")

app.include_router(runs.router)

# Mount static files
app.mount("/static", StaticFiles(directory="api/static"), name="static")

@app.get("/")
def read_root():
    return FileResponse("api/static/index.html")

@app.get("/health")
def health_check():
    return {"status": "ok"}

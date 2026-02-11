from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models import UsageStats, BackupData
from .database import db

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/report")
async def report_usage(stats: UsageStats):
    if db is None:
        raise HTTPException(status_code=503, detail="Database not configured")
    try:
        report_data = stats.model_dump()
        await db.reports.insert_one(report_data)
        return {"status": "success", "message": "Usage stats reported"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/backup")
async def backup_data(data: BackupData):
    if db is None:
        raise HTTPException(status_code=503, detail="Database not configured")
    try:
        backup_doc = data.model_dump()
        await db.backups.insert_one(backup_doc)
        return {"status": "success", "message": "Backup received"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {"message": "Workout Logger Backend Running"}

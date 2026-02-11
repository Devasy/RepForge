import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader

from .models import UsageStats, BackupData, AppEvent, HeartbeatPayload
from .database import db

logger = logging.getLogger(__name__)

app = FastAPI(title="RepForge Analytics API", version="1.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ────────────────────── auth ──────────────────────

ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", "")

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_admin(api_key: Optional[str] = Security(_api_key_header)):
    """Enforce admin API key on analytics read endpoints."""
    if not ADMIN_API_KEY:
        raise HTTPException(status_code=503, detail="Admin key not configured")
    if api_key != ADMIN_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


# ────────────────────── helpers ──────────────────────

def _ensure_db():
    if db is None:
        raise HTTPException(status_code=503, detail="Database not configured")


# ────────────────────── ingest endpoints ──────────────────────

@app.post("/report")
async def report_usage(stats: UsageStats):
    """Receive periodic usage-stats snapshots from a device."""
    _ensure_db()
    try:
        doc = stats.model_dump()
        # upsert: latest report per user_app_id replaces older one
        await db.reports.update_one(
            {"user_app_id": stats.user_app_id},
            {"$set": dict(doc)},   # copy to avoid _id mutation leaking
            upsert=True,
        )
        # also keep a time-series log for trend analysis
        doc.pop("_id", None)
        await db.report_log.insert_one(doc)
        return {"status": "success", "message": "Usage stats reported"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("report_usage failed")
        raise HTTPException(status_code=500, detail="Internal server error") from e


@app.post("/backup")
async def backup_data(data: BackupData):
    """Receive a full data backup from a device."""
    _ensure_db()
    try:
        doc = data.parsed_backup()  # decode any JSON-string list items
        # keep only latest backup per user; overwrite previous
        await db.backups.update_one(
            {"user_app_id": data.user_app_id},
            {"$set": doc},
            upsert=True,
        )
        return {"status": "success", "message": "Backup received"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("backup_data failed")
        raise HTTPException(status_code=500, detail="Internal server error") from e


@app.post("/event")
async def track_event(event: AppEvent):
    """Record a lightweight analytics event."""
    _ensure_db()
    try:
        await db.events.insert_one(event.model_dump())
        return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("track_event failed")
        raise HTTPException(status_code=500, detail="Internal server error") from e


@app.post("/heartbeat")
async def heartbeat(payload: HeartbeatPayload):
    """Minimal ping on every app-open for DAU/MAU tracking."""
    _ensure_db()
    try:
        doc = payload.model_dump()
        # upsert user record
        await db.users.update_one(
            {"user_app_id": payload.user_app_id},
            {
                "$set": {
                    "last_seen": doc["timestamp"],
                    "app_version": doc.get("app_version"),
                    "platform": doc.get("platform"),
                },
                "$setOnInsert": {"first_seen": doc["timestamp"]},
                "$inc": {"total_opens": 1},
            },
            upsert=True,
        )
        # also append to heartbeat log for DAU/MAU queries
        await db.heartbeats.insert_one(doc)
        return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("heartbeat failed")
        raise HTTPException(status_code=500, detail="Internal server error") from e


# ────────────────────── analytics / read endpoints ──────────────────────
# All analytics routes require ADMIN_API_KEY via X-API-Key header.

@app.get("/analytics/overview", dependencies=[Depends(require_admin)])
async def analytics_overview():
    """High-level numbers: total users, DAU, WAU, MAU, total workouts."""
    _ensure_db()
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(days=1)
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    total_users = await db.users.count_documents({})
    # DAU = distinct users with heartbeat in last 24 h
    dau_ids = await db.heartbeats.distinct(
        "user_app_id", {"timestamp": {"$gte": day_ago}}
    )
    wau_ids = await db.heartbeats.distinct(
        "user_app_id", {"timestamp": {"$gte": week_ago}}
    )
    mau_ids = await db.heartbeats.distinct(
        "user_app_id", {"timestamp": {"$gte": month_ago}}
    )

    # aggregate total workouts across latest reports
    pipeline = [{"$group": {"_id": None, "total": {"$sum": "$total_workouts"}}}]
    cursor = db.reports.aggregate(pipeline)
    agg = await cursor.to_list(1)
    total_workouts = agg[0]["total"] if agg else 0

    return {
        "total_users": total_users,
        "dau": len(dau_ids),
        "wau": len(wau_ids),
        "mau": len(mau_ids),
        "total_workouts_all_users": total_workouts,
    }


@app.get("/analytics/retention", dependencies=[Depends(require_admin)])
async def analytics_retention(days: int = Query(30, ge=1, le=365)):
    """Return daily active-user counts for the last N days (retention curve)."""
    _ensure_db()
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)
    pipeline = [
        {"$match": {"timestamp": {"$gte": start}}},
        {
            "$group": {
                "_id": {
                    "$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}
                },
                "unique_users": {"$addToSet": "$user_app_id"},
            }
        },
        {
            "$project": {
                "date": "$_id",
                "active_users": {"$size": "$unique_users"},
                "_id": 0,
            }
        },
        {"$sort": {"date": 1}},
    ]
    cursor = db.heartbeats.aggregate(pipeline)
    results = await cursor.to_list(days + 1)
    return {"days": days, "retention": results}


@app.get("/analytics/events", dependencies=[Depends(require_admin)])
async def analytics_events(
    event: Optional[str] = None,
    days: int = Query(7, ge=1, le=365),
):
    """Aggregate event counts, optionally filtered by event name."""
    _ensure_db()
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)
    match: dict = {"timestamp": {"$gte": start}}
    if event:
        match["event"] = event

    pipeline = [
        {"$match": match},
        {"$group": {"_id": "$event", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
    ]
    cursor = db.events.aggregate(pipeline)
    results = await cursor.to_list(100)
    return {"days": days, "events": [{"event": r["_id"], "count": r["count"]} for r in results]}


@app.get("/analytics/users", dependencies=[Depends(require_admin)])
async def analytics_users(
    limit: int = Query(50, ge=1, le=500),
    sort_by: str = Query("last_seen", regex="^(last_seen|first_seen|total_opens)$"),
):
    """List user records (PII-redacted) for drill-down."""
    _ensure_db()
    cursor = db.users.find(
        {}, {"_id": 0}
    ).sort(sort_by, -1).limit(limit)
    users = await cursor.to_list(limit)
    return {"count": len(users), "users": users}


@app.get("/analytics/user/{user_app_id}", dependencies=[Depends(require_admin)])
async def analytics_user_detail(user_app_id: str):
    """Full detail for a single installation: profile, latest report, events."""
    _ensure_db()
    user = await db.users.find_one({"user_app_id": user_app_id}, {"_id": 0})
    report = await db.reports.find_one({"user_app_id": user_app_id}, {"_id": 0})
    events_cursor = db.events.find(
        {"user_app_id": user_app_id}, {"_id": 0}
    ).sort("timestamp", -1).limit(50)
    events = await events_cursor.to_list(50)
    return {"user": user, "latest_report": report, "recent_events": events}


# ────────────────────── health ──────────────────────

@app.get("/")
async def root():
    return {"message": "RepForge Analytics Backend Running", "version": "1.2.0"}

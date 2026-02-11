"""
RepForge Analytics Dashboard
────────────────────────────
Connects to the same MongoDB Atlas used by the FastAPI backend
and visualises usage stats, retention, events, and user drill-downs.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ConfigurationError
from datetime import datetime, timedelta, timezone

# ─── page config ───
st.set_page_config(
    page_title="RepForge Analytics",
    page_icon="🏋️",
    layout="wide",
)

# ─── MongoDB connection (cached) ───
@st.cache_resource
def get_db():
    try:
        uri = st.secrets["mongo"]["uri"]
    except (KeyError, FileNotFoundError):
        st.error("MongoDB URI not found. Add `[mongo]` with `uri` to `.streamlit/secrets.toml`.")
        return None
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=5000)
        # Force a connection check
        client.admin.command("ping")
        return client.get_database("workout_logger")
    except (ConnectionFailure, ConfigurationError) as e:
        st.error(f"Failed to connect to MongoDB: {e}")
        return None


db = get_db()
if db is None:
    st.stop()

# ─── sidebar ───
st.sidebar.title("🏋️ RepForge Analytics")
page = st.sidebar.radio(
    "Navigate",
    ["Overview", "Retention", "Events", "Users", "Backups"],
)
st.sidebar.markdown("---")
st.sidebar.caption(f"Data as of {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC")


# ════════════════════════════════════════════════════════════
# OVERVIEW
# ════════════════════════════════════════════════════════════
if page == "Overview":
    st.title("📊 Overview")

    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(days=1)
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    total_users = db.users.count_documents({})
    dau = len(db.heartbeats.distinct("user_app_id", {"timestamp": {"$gte": day_ago}}))
    wau = len(db.heartbeats.distinct("user_app_id", {"timestamp": {"$gte": week_ago}}))
    mau = len(db.heartbeats.distinct("user_app_id", {"timestamp": {"$gte": month_ago}}))

    # total workouts across all latest reports
    agg = list(db.reports.aggregate([{"$group": {"_id": None, "total": {"$sum": "$total_workouts"}}}]))
    total_workouts = agg[0]["total"] if agg else 0

    total_backups = db.backups.count_documents({})
    total_events = db.events.count_documents({})

    # KPI cards
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Installs", total_users)
    c2.metric("DAU", dau)
    c3.metric("WAU", wau)
    c4.metric("MAU", mau)

    c5, c6, c7 = st.columns(3)
    c5.metric("Total Workouts (all users)", total_workouts)
    c6.metric("Total Backups", total_backups)
    c7.metric("Total Events Logged", total_events)

    st.markdown("---")

    # Platform distribution
    st.subheader("Platform Distribution")
    platform_data = list(db.users.aggregate([
        {"$group": {"_id": "$platform", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
    ]))
    if platform_data:
        df_plat = pd.DataFrame(platform_data).rename(columns={"_id": "platform"})
        fig = px.pie(df_plat, names="platform", values="count", hole=0.4)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No platform data yet.")

    # Daily heartbeats (last 30 days)
    st.subheader("Daily Active Heartbeats (30 days)")
    hb_pipeline = [
        {"$match": {"timestamp": {"$gte": month_ago}}},
        {"$group": {
            "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
            "unique_users": {"$addToSet": "$user_app_id"},
        }},
        {"$project": {"date": "$_id", "active_users": {"$size": "$unique_users"}, "_id": 0}},
        {"$sort": {"date": 1}},
    ]
    hb_data = list(db.heartbeats.aggregate(hb_pipeline))
    if hb_data:
        df_hb = pd.DataFrame(hb_data)
        fig2 = px.bar(df_hb, x="date", y="active_users", labels={"active_users": "Unique Users"})
        st.plotly_chart(fig2, use_container_width=True)
    else:
        st.info("No heartbeat data yet.")


# ════════════════════════════════════════════════════════════
# RETENTION
# ════════════════════════════════════════════════════════════
elif page == "Retention":
    st.title("📈 User Retention")

    days = st.slider("Lookback window (days)", 7, 180, 30)
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)

    pipeline = [
        {"$match": {"timestamp": {"$gte": start}}},
        {"$group": {
            "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
            "unique_users": {"$addToSet": "$user_app_id"},
        }},
        {"$project": {"date": "$_id", "active_users": {"$size": "$unique_users"}, "_id": 0}},
        {"$sort": {"date": 1}},
    ]
    data = list(db.heartbeats.aggregate(pipeline))
    if data:
        df = pd.DataFrame(data)
        fig = px.area(df, x="date", y="active_users", title="Daily Active Users")
        st.plotly_chart(fig, use_container_width=True)

        # New vs returning users (users whose first_seen is in the window)
        st.subheader("New Installs per Day")
        new_pipeline = [
            {"$match": {"first_seen": {"$gte": start}}},
            {"$group": {
                "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$first_seen"}},
                "new_users": {"$sum": 1},
            }},
            {"$project": {"date": "$_id", "new_users": 1, "_id": 0}},
            {"$sort": {"date": 1}},
        ]
        new_data = list(db.users.aggregate(new_pipeline))
        if new_data:
            df_new = pd.DataFrame(new_data)
            fig2 = px.bar(df_new, x="date", y="new_users", title="New Installs")
            st.plotly_chart(fig2, use_container_width=True)
        else:
            st.info("No new-install data yet.")
    else:
        st.info("No heartbeat data in the selected window.")


# ════════════════════════════════════════════════════════════
# EVENTS
# ════════════════════════════════════════════════════════════
elif page == "Events":
    st.title("⚡ Event Analytics")

    days = st.slider("Lookback (days)", 1, 90, 7)
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)

    # Aggregate event counts
    pipeline = [
        {"$match": {"timestamp": {"$gte": start}}},
        {"$group": {"_id": "$event", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
    ]
    ev_data = list(db.events.aggregate(pipeline))
    if ev_data:
        df = pd.DataFrame(ev_data).rename(columns={"_id": "event"})
        fig = px.bar(df, x="event", y="count", color="event", title="Event Counts")
        st.plotly_chart(fig, use_container_width=True)

        # Event timeline
        st.subheader("Events Over Time")
        tl_pipeline = [
            {"$match": {"timestamp": {"$gte": start}}},
            {"$group": {
                "_id": {
                    "date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
                    "event": "$event",
                },
                "count": {"$sum": 1},
            }},
            {"$project": {"date": "$_id.date", "event": "$_id.event", "count": 1, "_id": 0}},
            {"$sort": {"date": 1}},
        ]
        tl_data = list(db.events.aggregate(tl_pipeline))
        if tl_data:
            df_tl = pd.DataFrame(tl_data)
            fig2 = px.line(df_tl, x="date", y="count", color="event", title="Events Over Time")
            st.plotly_chart(fig2, use_container_width=True)
    else:
        st.info("No events in the selected window.")


# ════════════════════════════════════════════════════════════
# USERS
# ════════════════════════════════════════════════════════════
elif page == "Users":
    st.title("👤 User Directory")

    sort_by = st.selectbox("Sort by", ["last_seen", "first_seen", "total_opens"])
    limit = st.number_input("Limit", 10, 500, 50)

    users = list(
        db.users.find({}, {"_id": 0})
        .sort(sort_by, -1)
        .limit(limit)
    )

    if users:
        df = pd.DataFrame(users)
        st.dataframe(df, use_container_width=True)

        # Drill-down
        st.markdown("---")
        st.subheader("User Detail")
        app_ids = [u.get("user_app_id", "?") for u in users]
        selected = st.selectbox("Select user_app_id", app_ids)

        if selected:
            col1, col2 = st.columns(2)
            with col1:
                st.markdown("**User record**")
                user_doc = db.users.find_one({"user_app_id": selected}, {"_id": 0})
                st.json(user_doc or {})

            with col2:
                st.markdown("**Latest Usage Report**")
                report = db.reports.find_one({"user_app_id": selected}, {"_id": 0})
                if report:
                    st.json(report)
                else:
                    st.info("No report yet.")

            st.markdown("**Recent Events**")
            evts = list(
                db.events.find({"user_app_id": selected}, {"_id": 0})
                .sort("timestamp", -1)
                .limit(30)
            )
            if evts:
                st.dataframe(pd.DataFrame(evts), use_container_width=True)
            else:
                st.info("No events for this user.")
    else:
        st.info("No users found.")


# ════════════════════════════════════════════════════════════
# BACKUPS
# ════════════════════════════════════════════════════════════
elif page == "Backups":
    st.title("💾 Backup Explorer")

    backups = list(
        db.backups.find({}, {"_id": 0, "sessions": 0, "routines": 0,
                             "targets": 0, "muscleGroups": 0, "customExercises": 0})
        .sort("backup_received_at", -1)
        .limit(100)
    )

    if backups:
        df = pd.DataFrame(backups)
        st.dataframe(df, use_container_width=True)

        st.markdown("---")
        st.subheader("Backup Detail")
        ids = [b.get("user_app_id", "?") for b in backups]
        sel = st.selectbox("Select user_app_id", ids, key="backup_user")
        if sel:
            # Fetch only lightweight metadata first (project out heavy arrays)
            meta = db.backups.find_one(
                {"user_app_id": sel},
                {"_id": 0, "sessions": 0, "routines": 0,
                 "targets": 0, "muscleGroups": 0, "customExercises": 0},
            )
            # Fetch counts via separate aggregation to avoid loading full arrays
            counts_doc = db.backups.find_one(
                {"user_app_id": sel},
                {
                    "_id": 0,
                    "sessions_count": {"$size": {"$ifNull": ["$sessions", []]}},
                    "routines_count": {"$size": {"$ifNull": ["$routines", []]}},
                    "custom_count": {"$size": {"$ifNull": ["$customExercises", []]}},
                },
            )
            # Fallback: if $size projection not supported, load counts differently
            if counts_doc and "sessions_count" in counts_doc:
                n_sessions = counts_doc["sessions_count"]
                n_routines = counts_doc["routines_count"]
                n_custom = counts_doc["custom_count"]
            else:
                # Lightweight fallback: just load count fields
                full = db.backups.find_one({"user_app_id": sel}, {"_id": 0})
                n_sessions = len(full.get("sessions", [])) if full else 0
                n_routines = len(full.get("routines", [])) if full else 0
                n_custom = len(full.get("customExercises", [])) if full else 0

            mc1, mc2, mc3 = st.columns(3)
            mc1.metric("Sessions", n_sessions)
            mc2.metric("Routines", n_routines)
            mc3.metric("Custom Exercises", n_custom)

            if meta:
                st.json(meta)

            # Only load full document on explicit user action
            total_items = n_sessions + n_routines + n_custom
            if total_items > 500:
                st.warning(f"This backup contains {total_items} items. Loading the full document may be slow.")
            with st.expander("Load full backup JSON"):
                if st.button("Fetch full backup", key="load_full_backup"):
                    full_doc = db.backups.find_one({"user_app_id": sel}, {"_id": 0})
                    if full_doc:
                        # Show truncated preview (first 5 items per array)
                        for arr_key in ("sessions", "routines", "targets", "muscleGroups", "customExercises"):
                            arr = full_doc.get(arr_key, [])
                            if len(arr) > 5:
                                full_doc[arr_key] = arr[:5] + [f"... and {len(arr) - 5} more"]
                        st.json(full_doc)
    else:
        st.info("No backups found.")

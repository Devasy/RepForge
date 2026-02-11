import os
from motor.motor_asyncio import AsyncIOMotorClient

MONGODB_URI = os.environ.get("MONGODB_URI")

if MONGODB_URI:
    client = AsyncIOMotorClient(MONGODB_URI)
    db = client.get_database("workout_logger")
else:
    db = None

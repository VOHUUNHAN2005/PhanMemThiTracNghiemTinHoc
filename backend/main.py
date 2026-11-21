import os

from app.routers import friends, topics, practice_session, official_exam, admin, realtime, user_history


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth
from fastapi.staticfiles import StaticFiles
os.makedirs("static/upload_avatars", exist_ok=True)
app = FastAPI(title="IT Quiz App API", version="1.0.0")
app.mount("/static", StaticFiles(directory="static"), name="static")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(friends.router)
app.include_router(auth.router)
app.include_router(topics.router)
app.include_router(practice_session.router)
app.include_router(official_exam.router)
app.include_router(admin.router)
app.include_router(user_history.router)
app.include_router(realtime.router)
@app.get("/", tags=["Health Check"])
def health_check():
    return {"status": "ok", "message": "IT Quiz Backend đang hoạt động!"}
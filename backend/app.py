from __future__ import annotations
import asyncio
import base64
import hashlib
import html
import json
import logging
import os
import re
import secrets
import pickle
import uuid
import threading
import time
from datetime import datetime, timedelta, date
from itertools import islice
from pathlib import Path
from typing import Any, Dict, List, Optional, AsyncGenerator, Tuple, Literal, TYPE_CHECKING
from urllib.parse import unquote_plus, urlparse
import io
import zipfile
from fastapi import APIRouter, Query

import httpx
import requests
from requests import exceptions as req_exc
import jwt
from fastapi import FastAPI, Request, HTTPException, status, Depends, UploadFile, File, Form 
from fastapi.responses import StreamingResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, ValidationError ,Field
try:
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession as _AuthorizedSession
except Exception:  # noqa: BLE001
    service_account = None
    _AuthorizedSession = None  # type: ignore[assignment]
if TYPE_CHECKING:
    from google.auth.transport.requests import AuthorizedSession as GoogleAuthorizedSession
else:
    GoogleAuthorizedSession = Any  # type: ignore[assignment]
AuthorizedSession = _AuthorizedSession
from g4f import Provider
from g4f.client import AsyncClient  # g4f async client (supports streaming)
from googlesearch import search as google_search
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text, ForeignKey, select, Date, or_, JSON, Index , Float
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
try:
    from telebot import TeleBot, types as tb_types
except Exception:  # noqa: BLE001
    TeleBot = None  # type: ignore[assignment]
    tb_types = None  # type: ignore[assignment]
load_dotenv()
try:
    from g4f.Provider.search.DDGS import DDGS as G4F_DDGS, SearchResults, SearchResultEntry 
except Exception:  # noqa: BLE001
    G4F_DDGS = None
    SearchResults = None  # type: ignore[assignment]
    SearchResultEntry = None  # type: ignore[assignment]
try:  # Ensure google backend is available for ddgs searches.
    from ddgs.engines import ENGINES as DDGS_ENGINES
    from ddgs.engines.google import Google as DDGS_Google
    if getattr(DDGS_Google, "disabled", True):
        DDGS_Google.disabled = False
    DDGS_ENGINES.setdefault("text", {})["google"] = DDGS_Google
except Exception:  # noqa: BLE001
    DDGS_Google = None  # type: ignore[assignment]
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("chat-sse")
PUTER_API_KEY = os.getenv(
    "PUTER_API_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0IjoicyIsInYiOiIwLjAuMCIsInUiOiJaMTFXd3lwYlNKYVVSWEMzdHN6aG5BPT0iLCJ1dSI6Im9OQVUzM0U2UmFhY0tUOVFxMWZROHc9PSIsImlhdCI6MTc2MTY1NzQ0Nn0.aTjV1tTVVVtvjR3BvGW5Ql6-UOh8rDy0Q3dI50JWv4Y",
)
BASE_DIR = Path(__file__).resolve().parent
HAR_COOKIE_DIR = Path(os.getenv("HAR_COOKIE_DIR", BASE_DIR / "har_and_cookies")).resolve()
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///app.db")
AUTH_SECRET = os.getenv("AUTH_SECRET", "WEUH@&#Y&TRGY@#&^@#")
AUTH_TOKEN_EXPIRES = int(os.getenv("AUTH_TOKEN_EXPIRES", str(7 * 24 * 3600)))  # default: 7 days (1 week)
IPPANEL_API_TOKEN = os.getenv("IPPANEL_API_TOKEN" , "WGqzmLDMNJ5AM-odaPr-yf_CUqtLGi6OxTf6epBUwak=")
IPPANEL_FROM_NUMBER = os.getenv("IPPANEL_FROM_NUMBER" , "+983000505")
IPPANEL_PATTERN_CODE = os.getenv("IPPANEL_PATTERN_CODE" , "s79arntai6a37tf")
IPPANEL_BASE_URL = os.getenv("IPPANEL_BASE_URL", "https://edge.ippanel.com/v1")
OTP_EXPIRES_SECONDS = int(os.getenv("OTP_EXPIRES_SECONDS", "300"))
OTP_RESEND_COOLDOWN = int(os.getenv("OTP_RESEND_COOLDOWN", "60"))
OTP_MAX_ATTEMPTS = int(os.getenv("OTP_MAX_ATTEMPTS", "5"))
APP_LATEST_VERSION = os.getenv("APP_LATEST_VERSION", "1.0.0")
APP_DOWNLOAD_URL = os.getenv("APP_DOWNLOAD_URL", "https://example.com/download")
IMAGE_TOOL_MODEL = os.getenv("IMAGE_TOOL_MODEL", "gpt-image-1")
IMAGE_TOOL_PROVIDER = os.getenv("IMAGE_TOOL_PROVIDER")
IMAGE_RESPONSE_FORMAT = os.getenv("IMAGE_RESPONSE_FORMAT", "url")
LOCAL_IMAGE_GENERATE_URL = os.getenv("LOCAL_IMAGE_GENERATE_URL", "http://localhost:3000/generate")
IMAGE_ENHANCE_TIMEOUT = float(os.getenv("IMAGE_ENHANCE_TIMEOUT", "8"))  # reduced from 12 seconds
LOCAL_IMAGE_TIMEOUT = float(os.getenv("LOCAL_IMAGE_TIMEOUT", "60"))  # reduced from 90 seconds
LOCAL_IMAGE_PICK_SECONDS = float(os.getenv("LOCAL_IMAGE_PICK_SECONDS", "120"))  # reduced from 180 seconds
GOOGLE_AI_STUDIO_API_KEY = os.getenv("GOOGLE_AI_STUDIO_API_KEY", "AIzaSyDpjhmRQxJ2q_B1J_amFOIeBDBzzFHFTMU")
# پیش‌فرض مسیر سشن را مثل بقیه تنظیمات نسبی به فولدر پروژه می‌کنیم تا
# فرق cwd بین اجرای مستقیم و اجرای uvicorn باعث FileNotFound نشود.
GEMINI_SESSION_FILE = os.getenv("GEMINI_SESSION_FILE", str(BASE_DIR / "gemini_cookies.pkl"))
GEMINI_PROFILE_DIR = os.getenv("GEMINI_PROFILE_DIR", str(BASE_DIR / "chrome_profile_gemini"))
GEMINI_OUTPUT_DIR = os.getenv("GEMINI_OUTPUT_DIR", str(BASE_DIR / "generated"))
GEMINI_OUTPUT_PATH = Path(GEMINI_OUTPUT_DIR).resolve()
GEMINI_OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
GEMINI_MAX_PARALLEL = int(os.getenv("GEMINI_MAX_PARALLEL", "1"))
GEMINI_REQUEST_TIMEOUT = 210
# مثل test2.py، headless بودن را از متغیر محیطی بگیریم تا رفتار یکی باشد.
GEMINI_HEADLESS = os.getenv("GEMINI_HEADLESS", "1") == "1"
GEMINI_CHROME_BINARY = os.getenv("GEMINI_CHROME_BINARY")
GEMINI_CHROMEDRIVER_PATH = os.getenv("GEMINI_CHROMEDRIVER_PATH")
GEMINI_DAILY_LIMIT = int(os.getenv("GEMINI_DAILY_LIMIT", "10"))
AGENT_TASK_POLL_INTERVAL = float(os.getenv("AGENT_TASK_POLL_INTERVAL", "2.5"))
PUSH_WEBHOOK_URL = os.getenv("PUSH_WEBHOOK_URL")  # optional HTTP webhook for device notifications
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY","AAAArTxfXOo:APA91bH1kUBOBCTVt9aTuhBnrgMhyT-5pk4mYRerYie0lG3lZ-k0QT58YaEPeKOpG4W_iLoyD2hueKfJVDMaIrMsCKGELxjYx13mjRektH4exbFzLUZY7XAuqwrMxRiHZFN8ne-mpeD1")  # Firebase legacy server key (recommended to set)
FCM_PROJECT_ID = os.getenv("FCM_PROJECT_ID")
FCM_SERVICE_ACCOUNT_FILE = os.getenv("FCM_SERVICE_ACCOUNT_FILE")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_ADMIN_IDS = {
    int(cid.strip())
    for cid in os.getenv("TELEGRAM_ADMIN_IDS", "").split(",")
    if cid.strip().isdigit()
}
MAX_SESSION_TOKEN_ESTIMATE = int(os.getenv("MAX_SESSION_TOKEN_ESTIMATE", "7000"))
MAX_REQUEST_TOKEN_ESTIMATE = int(os.getenv("MAX_REQUEST_TOKEN_ESTIMATE", "6500"))
MAX_SESSION_MESSAGES = int(os.getenv("MAX_SESSION_MESSAGES", "64"))
SESSION_RECENT_MESSAGES = int(os.getenv("SESSION_RECENT_MESSAGES", "12"))
EXPERT_RECENT_MESSAGES = int(os.getenv("EXPERT_RECENT_MESSAGES", "10"))
SUMMARY_CHAR_LIMIT = int(os.getenv("SUMMARY_CHAR_LIMIT", "6000"))
SUMMARY_TARGET_WORDS = int(os.getenv("SUMMARY_TARGET_WORDS", "160"))
# Agent scheduler globals
AGENT_SCHEDULER_TASK: Optional[asyncio.Task] = None
AGENT_SCHEDULER_STOP = asyncio.Event()
_FCM_SESSION: Optional[Any] = None
_APP_LOOP: Optional[asyncio.AbstractEventLoop] = None
def _init_openai_cookie_support() -> bool:
    if not HAR_COOKIE_DIR.exists():
        return False
    har_assets = list(HAR_COOKIE_DIR.glob("*.har"))
    json_assets = list(HAR_COOKIE_DIR.glob("*.json"))
    if not har_assets and not json_assets:
        log.info("har_and_cookies directory exists but contains no .har/.json files: %s", HAR_COOKIE_DIR)
        return False
    try:
        from g4f.cookies import read_cookie_files, set_cookies_dir
    except Exception as exc:  # noqa: BLE001
        log.warning("Unable to import g4f cookie helpers; OpenAI cookie fallback disabled: %s", exc)
        return False
    try:
        set_cookies_dir(str(HAR_COOKIE_DIR))
        read_cookie_files(domains_filter=[
            "chatgpt.com",
            ".chatgpt.com",
            "openai.com",
            ".openai.com",
            "copilot.microsoft.com"
        ])
        log.info("Loaded OpenAI cookie assets from %s", HAR_COOKIE_DIR)
        return True
    except Exception as exc:  # noqa: BLE001
        log.warning("Failed to initialize OpenAI cookie assets from %s: %s", HAR_COOKIE_DIR, exc)
        return False
OPENAI_COOKIE_READY = _init_openai_cookie_support()
app = FastAPI(title="Chat Stream (g4f) with auto-fallback")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or "*"
    allow_credentials=True,
    allow_methods=["*"],    
    allow_headers=["*"],
)
app.mount("/generated", StaticFiles(directory=GEMINI_OUTPUT_PATH), name="generated")
Base = declarative_base()
engine = create_async_engine(DATABASE_URL, future=True, pool_pre_ping=True)
async_session = sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
bearer_scheme = HTTPBearer(auto_error=False)
# فقط برای استفاده داخلی سرویس؛ کاربر به آن دسترسی ندارد:
# می‌توانید این ترتیب را بعداً با health-check پویا کنید.
router = APIRouter(prefix="/user", tags=["notifications"])
app.include_router(router)

# فرمت "model@provider" => اگر provider خالی باشد، g4f خودش انتخاب می‌کند.
FALLBACK_CHAIN = [
    "gpt-4o@PuterJS",
    "gpt-4o-mini@PuterJS",
    "gpt-4.1@PuterJS",
    "gpt-5@OpenaiAccount",
    "gpt-4o@OpenaiChat",
    "gpt-5@OpenaiChat",
    "claude-3-7-ch-exp@ApiAirforce",
    "gpt-4.1-mini@OpenaiChat",
]
PER_ATTEMPT_TIMEOUT = 15.0  # ثانیه
STREAM_INIT_TIMEOUT = 30.0  # ثانیه - timeout برای شروع stream
STREAM_PING_EVERY = 15.0    # ثانیه (برای زنده نگه‌داشتن اتصال SSE)
MAX_FILE_BYTES = 10_000_000  # حداکثر 10 مگابایت برای ورودی فایل
MAX_FILE_TEXT_CHARS = 6000  # حداکثر کاراکتر inject شده از هر فایل
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff"}
TEXT_EXTENSIONS = {".txt", ".md", ".markdown", ".csv", ".tsv", ".json", ".log", ".yaml", ".yml", ".ini", ".cfg"}
BLOCKED_EXTENSIONS = {
    ".zip", ".rar", ".7z", ".tar", ".gz",
    ".mp3", ".wav", ".m4a", ".ogg",
    ".mp4", ".mkv", ".mov", ".sh" , ".bash"
}
class Message(BaseModel):
    role: str
    content: str
class ChatRequest(BaseModel):
    messages: List[Message]
    session_id: Optional[str] = None
    reset: bool = False
    web_search: bool = False
    expert_domain: Optional[str] = None  # psychology, real_estate, mechanics, talent_assessment
    file_urls: Optional[List[str]] = None  # مسیر/URL فایل‌هایی که باید به متن تبدیل شوند
    # هیچ ورودی برای model/provider از سمت کاربر پذیرفته نمی‌شود.
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(32), unique=True, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_login = Column(DateTime, nullable=True)
class OTPRequestModel(Base):
    __tablename__ = "otp_requests"
    id = Column(Integer, primary_key=True)
    phone = Column(String(32), index=True, nullable=False)
    code_hash = Column(String(128), nullable=False)
    sent_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, default=0, nullable=False)
    verified = Column(Boolean, default=False, nullable=False)
class AgentTask(Base):
    __tablename__ = "agent_tasks"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    brief = Column(Text, nullable=False)
    tone = Column(String(64), nullable=True)
    audience = Column(String(255), nullable=True)
    language = Column(String(32), nullable=False, default="fa")
    outline = Column(Text, nullable=True)
    word_count = Column(Integer, nullable=True)
    status = Column(String(32), nullable=False, default="created")
    result_text = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_error = Column(String(512), nullable=True)
class DeviceToken(Base):
    __tablename__ = "device_tokens"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_token = Column(String(512), unique=True, nullable=False)
    platform = Column(String(32), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=False)
class AIMemory(Base):
    __tablename__ = "ai_memories"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    key = Column(String(128), nullable=True, index=True)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
class ImageUsage(Base):
    __tablename__ = "image_usage"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    count = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
class TelegramSubscriber(Base):
    __tablename__ = "telegram_subscribers"
    id = Column(Integer, primary_key=True)
    chat_id = Column(String(64), unique=True, nullable=False, index=True)
    username = Column(String(64), nullable=True)
    first_name = Column(String(128), nullable=True)
    last_name = Column(String(128), nullable=True)
    app_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=False)
# ═══════════════════════════════════════════════════════════════════
# PERSONALIZATION SYSTEM - Phase 1 Database Models
# ═══════════════════════════════════════════════════════════════════
class UserProfile(Base):
    """User profile with preferences and schedule"""
    __tablename__ = "user_profiles"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    name = Column(String(255), nullable=False)
    role = Column(String(128), nullable=False)  # Student, Professional, Entrepreneur, etc.
    timezone = Column(String(64), nullable=False, default="Asia/Tehran")
    interests = Column(Text, nullable=True)  # JSON: ["tag1", "tag2", ...]
    
    # Schedule info
    wake_up_time = Column(Integer, nullable=False, default=6)  # 0-23
    sleep_time = Column(Integer, nullable=False, default=23)  # 0-23
    focus_hours = Column(Integer, nullable=False, default=6)  # Max daily focus hours
    
    # Calculated/derived
    avg_energy = Column(Integer, nullable=True)  # 1-10
    avg_mood = Column(Integer, nullable=True)  # 1-10
    last_mood_update = Column(DateTime, nullable=True)
    active_goal_ids = Column(Text, nullable=True)  # JSON: ["goal1", "goal2", ...]
    
    # Preferences
    preferred_break_duration = Column(Integer, nullable=False, default=15)
    enable_motivation = Column(Boolean, nullable=False, default=True)
    communication_style = Column(String(64), nullable=False, default="Casual")
    track_habits = Column(Boolean, nullable=False, default=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
class UserGoal(Base):
    """User goals with milestones and progress tracking"""
    __tablename__ = "user_goals"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    goal_id = Column(String(36), nullable=False, unique=True, index=True)  # UUID
    title = Column(String(255), nullable=False)
    category = Column(String(64), nullable=False)  # Work, Health, Learning, Personal, Creative
    description = Column(Text, nullable=True)
    
    deadline = Column(DateTime, nullable=False, index=True)
    priority = Column(Integer, nullable=False)  # 1-5
    
    # Tracking
    milestones = Column(Text, nullable=True)  # JSON: ["milestone1", "milestone2", ...]
    progress_percentage = Column(Integer, nullable=False, default=0)
    completed_at = Column(DateTime, nullable=True)
    
    status = Column(String(32), nullable=False, default="active")  # active, completed, archived
    
    # Auto-tracking
    linked_task_ids = Column(JSON, default=list)  # Task IDs linked to this goal
    linked_habit_ids = Column(JSON, default=list)  # Habit IDs linked to this goal
    auto_progress_enabled = Column(Boolean, default=True)  # Auto-calculate from tasks/habits
    last_auto_update = Column(DateTime, nullable=True)
    
    # Motivation
    motivation_message = Column(Text, nullable=True)  # AI-generated motivation
    last_ai_message = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class GoalMilestone(Base):
    """Individual milestones for goals"""
    __tablename__ = "goal_milestones"
    
    id = Column(Integer, primary_key=True)
    goal_id = Column(Integer, ForeignKey("user_goals.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    milestone_id = Column(String(36), unique=True, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    
    target_date = Column(DateTime, nullable=True)
    order = Column(Integer, default=0)
    
    status = Column(String(32), default="pending")  # pending, in_progress, completed
    completed_at = Column(DateTime, nullable=True)
    
    progress_contribution = Column(Integer, default=0)  # percentage of goal (0-100)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class GoalProgressLog(Base):
    """Log progress updates for goals"""
    __tablename__ = "goal_progress_logs"
    
    id = Column(Integer, primary_key=True)
    goal_id = Column(Integer, ForeignKey("user_goals.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    old_progress = Column(Integer)
    new_progress = Column(Integer)
    reason = Column(String(255))  # manual, task_completion, habit_progress, auto_update
    
    created_at = Column(DateTime, default=datetime.utcnow)

class MoodSnapshot(Base):
    """Mood and energy tracking for personalization"""
    __tablename__ = "mood_snapshots"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    snapshot_id = Column(String(36), nullable=False, unique=True)  # UUID
    
    timestamp = Column(DateTime, nullable=False, index=True, default=datetime.utcnow)
    energy = Column(Integer, nullable=False)  # 1-10
    mood = Column(Integer, nullable=False)  # 1-10
    
    context = Column(String(128), nullable=False)  # At work, Home, Gym, etc.
    activity = Column(String(128), nullable=True)  # Coding, Exercising, Reading, etc.
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
class Habit(Base):
    """Habits for tracking daily/weekly routines"""
    __tablename__ = "habits"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    habit_id = Column(String(36), nullable=False, unique=True)  # UUID
    
    name = Column(String(255), nullable=False)
    category = Column(String(64), nullable=False)  # Health, Learning, Productivity, Personal
    frequency = Column(String(32), nullable=False)  # Daily, Weekly, Custom
    target_count = Column(Integer, nullable=False, default=1)  # e.g., 3 for "3 times/week"
    unit = Column(String(32), nullable=False, default="times")  # times, hours, pages, km
    linked_goal_id = Column(String(36), nullable=True)  # Optional FK to goal
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    archived_at = Column(DateTime, nullable=True)
class HabitLog(Base):
    """Log individual habit completions"""
    __tablename__ = "habit_logs"
    id = Column(Integer, primary_key=True)
    habit_id = Column(Integer, ForeignKey("habits.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    logged_date = Column(Date, nullable=False, index=True)
    count = Column(Integer, nullable=False, default=1)
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
# ═══════════════════════════════════════════════════════════════════
# PHASE 2: DAILY PROGRAM & SMART SCHEDULING
# ═══════════════════════════════════════════════════════════════════
class DailyProgram(Base):
    """Daily program with scheduled activities"""
    __tablename__ = "daily_programs"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    program_id = Column(String(36), unique=True, nullable=False)
    date = Column(Date, nullable=False)
    activities = Column(JSON, default=list)  # JSON array of activities
    expected_productivity = Column(Float)  # 0-100
    expected_mood = Column(Float)  # 1-10
    focus_theme = Column(String(100))
    is_completed = Column(Boolean, default=False)
    actual_productivity = Column(Float)  # Actual score after day
    created_at = Column(DateTime, default=datetime.utcnow)
    generated_at = Column(DateTime)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (Index('ix_user_program_date', 'user_id', 'date'),)
class SchedulingAnalysis(Base):
    """Smart scheduling analysis results"""
    __tablename__ = "scheduling_analyses"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    analysis_id = Column(String(36), unique=True, nullable=False)
    recommendations = Column(JSON, default=list)  # JSON array of recommendations
    overall_productivity_score = Column(Float)  # 0-100
    schedule_health_status = Column(String(50))  # optimal, good, fair, poor
    improvements = Column(JSON, default=list)  # JSON array of suggestions
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# =========================
# Pydantic Models (مثل Dart)
# =========================

class ImportantMessage(BaseModel):
    message_id: str = Field(default="")
    sender: str = ""
    subject: str = ""
    preview: str = ""
    importance: str = "medium"  # critical, high, medium, low
    keywords: List[str] = []
    received_at: datetime


class CriticalAlert(BaseModel):
    alert_id: str = Field(default="")
    title: str = ""
    description: str = ""
    severity: str = "high"  # critical, high, medium
    action: Optional[str] = None
    created_at: datetime


class ActionItem(BaseModel):
    item_id: str = Field(default="")
    title: str = ""
    description: str = ""
    due_date: Optional[str] = None
    assignee: Optional[str] = None
    priority: str = "medium"  # high, medium, low
    source: str = ""
    completed: bool = False


class NotificationSummary(BaseModel):
    summary_id: str = Field(default="")
    total_notifications: int = 0
    read_count: int = 0
    unread_count: int = 0
    important_messages: List[ImportantMessage] = []
    critical_alerts: List[CriticalAlert] = []
    action_items: List[ActionItem] = []
    ai_generated_summary: Optional[str] = None
    sentiment_score: float = 0.0  # -1..1
    dominant_topic: str = ""
    key_people: List[str] = []
    generated_at: datetime


class NotificationCategory(BaseModel):
    category: str = "other"   # work, personal, social, system, ...
    urgency: str = "medium"   # critical, high, medium, low
    confidence: float = 0.0
    suggested_action: Optional[str] = None


class NotificationTrends(BaseModel):
    total_notifications: int = 0
    average_per_day: int = 0
    top_senders: List[str] = []
    category_breakdown: Dict[str, int] = {}
    average_sentiment: float = 0.0
    emerging_topics: List[str] = []


class SummaryStats(BaseModel):
    total_notifications: int = 0
    critical_count: int = 0
    important_count: int = 0
    action_items_count: int = 0
    sentiment_score: float = 0.0
    last_updated: datetime = Field(default_factory=datetime.utcnow)


# ===============
# Request models
# ===============

class SummarizeRequest(BaseModel):
    notifications: List[Dict[str, Any]]
    messages: List[Dict[str, Any]]
    focus_area: Optional[str] = None
    hours_back: Optional[int] = None


class TodaySummaryResponse(BaseModel):
    summary: Optional[NotificationSummary] = None


class ImportantMessagesResponse(BaseModel):
    messages: List[ImportantMessage]


class CriticalAlertsResponse(BaseModel):
    alerts: List[CriticalAlert]


class InsightsResponse(BaseModel):
    most_contacted: Any
    conversation_topics: Any
    sentiment_trend: Any
    pending_actions: Any
    follow_ups_needed: Any


class CategorizeRequest(BaseModel):
    title: str
    body: str


class SnoozeRequest(BaseModel):
    snooze_minutes: int
    category: Optional[str] = None


class ActionItemsResponse(BaseModel):
    action_items: List[ActionItem]


class NotificationTrendsResponse(NotificationTrends):
    pass
# ═══════════════════════════════════════════════════════════════════
# TASK MANAGEMENT SYSTEM
# ═══════════════════════════════════════════════════════════════════
class UserTask(Base):
    """User tasks with smart scheduling and reminders"""
    __tablename__ = "user_tasks"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    task_id = Column(String(36), nullable=False, unique=True, index=True)  # UUID
    
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(64), nullable=False)  # Work, Personal, Health, Learning, Shopping
    
    # Timing
    due_date = Column(DateTime, nullable=True, index=True)
    scheduled_time = Column(DateTime, nullable=True)  # when to execute
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)
    
    # Priority & Status
    priority = Column(Integer, nullable=False, default=3)  # 1-5
    status = Column(String(32), nullable=False, default="pending")  # pending, in_progress, completed, cancelled
    
    # Smart features
    estimated_duration_minutes = Column(Integer, nullable=True)  # how long it takes
    linked_goal_id = Column(String(36), nullable=True)  # FK to UserGoal
    subtasks = Column(JSON, default=list)  # JSON array of {"title", "completed", "order"}
    location = Column(String(255), nullable=True)  # for geofencing
    
    # Reminders
    reminder_before_minutes = Column(Integer, default=30)  # 30 min before
    reminder_sent = Column(Boolean, default=False)
    
    # Notes
    notes = Column(Text, nullable=True)
    tags = Column(JSON, default=list)  # JSON array of tags
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index('ix_user_task_status', 'user_id', 'status'),
        Index('ix_user_task_due', 'user_id', 'due_date'),
    )

class TaskRecurrence(Base):
    """Recurring task patterns"""
    __tablename__ = "task_recurrences"
    
    id = Column(Integer, primary_key=True)
    task_id = Column(Integer, ForeignKey("user_tasks.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    pattern = Column(String(64), nullable=False)  # daily, weekly, monthly, custom
    frequency = Column(Integer, nullable=False, default=1)  # every N days/weeks/etc
    days_of_week = Column(JSON, nullable=True)  # for weekly: [0,1,2,3,4,5,6] (Mon-Sun)
    end_date = Column(DateTime, nullable=True)  # when to stop recurring
    
    created_at = Column(DateTime, default=datetime.utcnow)

class TaskReminder(Base):
    """Reminder history and scheduling"""
    __tablename__ = "task_reminders"
    
    id = Column(Integer, primary_key=True)
    task_id = Column(Integer, ForeignKey("user_tasks.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    scheduled_at = Column(DateTime, nullable=False, index=True)
    sent_at = Column(DateTime, nullable=True)
    channel = Column(String(32), nullable=False, default="push")  # push, sms, email
    status = Column(String(32), nullable=False, default="scheduled")  # scheduled, sent, failed
    message = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)


class GeoFence(Base):
    """Location-based reminder geofences"""
    __tablename__ = "geofences"
    
    id = Column(Integer, primary_key=True)
    geofence_id = Column(String(36), unique=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    task_id = Column(Integer, ForeignKey("user_tasks.id"), nullable=False, index=True)
    
    name = Column(String(255), nullable=False)  # e.g., "Office", "Home", "Gym"
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Integer, nullable=False, default=100)  # Default 100m radius
    
    entry_action = Column(String(32), nullable=True, default="remind")  # remind, notify, silent
    exit_action = Column(String(32), nullable=True)
    
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index("idx_user_geofences", "user_id", "is_active"),
        Index("idx_task_geofences", "task_id", "is_active"),
    )


class LocationCheckIn(Base):
    """Log of user location check-ins for geofence tracking"""
    __tablename__ = "location_checkins"
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    geofence_id = Column(Integer, ForeignKey("geofences.id"), nullable=False, index=True)
    
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    action = Column(String(32), nullable=False)  # entry, exit, inside, outside
    
    reminder_sent = Column(Boolean, default=False)
    reminder_sent_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class InstagramIdeaRequest(BaseModel):
    topic: str
    audience: Optional[str] = None
    goals: Optional[str] = None
    language: str = "fa"

# ═══════════════════════════════════════════════════════════════════
# TASK MANAGEMENT REQUEST/RESPONSE MODELS
# ═══════════════════════════════════════════════════════════════════
class Subtask(BaseModel):
    title: str
    completed: bool = False
    order: int = 0

class TaskCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    category: str  # Work, Personal, Health, Learning, Shopping
    due_date: Optional[str] = None  # ISO datetime
    priority: int = 3  # 1-5
    estimated_duration_minutes: Optional[int] = None
    linked_goal_id: Optional[str] = None
    location: Optional[str] = None
    subtasks: Optional[List[Subtask]] = None
    tags: Optional[List[str]] = None

class TaskUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None  # pending, in_progress, completed, cancelled
    priority: Optional[int] = None
    due_date: Optional[str] = None
    subtasks: Optional[List[Subtask]] = None
    notes: Optional[str] = None

class TaskResponse(BaseModel):
    task_id: str
    title: str
    description: Optional[str]
    category: str
    status: str
    priority: int
    due_date: Optional[datetime]
    scheduled_time: Optional[datetime]
    estimated_duration_minutes: Optional[int]
    linked_goal_id: Optional[str]
    subtasks: Optional[List[Subtask]]
    location: Optional[str]
    tags: Optional[List[str]]
    created_at: datetime
    completed_at: Optional[datetime]
    reminder_sent: bool

class TaskListResponse(BaseModel):
    total: int
    tasks: List[TaskResponse]
    overdue_count: int
    today_count: int

class RecurrencePattern(BaseModel):
    pattern: str  # daily, weekly, monthly, custom
    frequency: int = 1
    days_of_week: Optional[List[int]] = None
    end_date: Optional[str] = None

class RecurringTaskRequest(BaseModel):
    title: str
    description: Optional[str] = None
    category: str
    recurrence: RecurrencePattern
    priority: int = 3
    estimated_duration_minutes: Optional[int] = None
    tags: Optional[List[str]] = None

class InstagramIdeaResponse(BaseModel):
    topic: str
    ideas: List[Dict[str, Any]]
    raw_text: str
class ContentCalendarRequest(BaseModel):
    idea: str
    duration_weeks: int = 4
    posts_per_week: int = 3
    pillars: Optional[List[str]] = None
    include_reels: bool = True
    language: str = "fa"
class ContentCalendarEntry(BaseModel):
    day: str
    hook: str
    format: str
    outline: str
    cta: str
    notes: Optional[str] = None

# ═══════════════════════════════════════════════════════════════════
# GOAL TRACKING REQUEST/RESPONSE MODELS
# ═══════════════════════════════════════════════════════════════════
class MilestoneCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    target_date: Optional[str] = None
    progress_contribution: int = 0  # how much of goal (0-100)

class GoalCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    category: str  # Work, Health, Learning, Personal, Creative
    deadline: str  # ISO datetime
    priority: int = 3  # 1-5
    milestones: Optional[List[MilestoneCreateRequest]] = None
    linked_task_ids: Optional[List[str]] = None
    linked_habit_ids: Optional[List[str]] = None

class GoalUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    progress_percentage: Optional[int] = None
    status: Optional[str] = None
    priority: Optional[int] = None
    deadline: Optional[str] = None

class MilestoneResponse(BaseModel):
    milestone_id: str
    title: str
    description: Optional[str]
    target_date: Optional[datetime]
    status: str
    progress_contribution: int
    completed_at: Optional[datetime]

class GoalProgressResponse(BaseModel):
    progress_percentage: int
    last_updated: datetime
    days_remaining: Optional[int]
    on_track: bool  # whether goal is on schedule to complete by deadline
    trend: str  # "increasing", "steady", "decreasing"

class GoalResponse(BaseModel):
    goal_id: str
    title: str
    description: Optional[str]
    category: str
    deadline: datetime
    priority: int
    status: str
    progress_percentage: int
    milestones: Optional[List[MilestoneResponse]]
    linked_task_count: int
    linked_habit_count: int
    auto_progress_enabled: bool
    motivation_message: Optional[str]
    created_at: datetime
    completed_at: Optional[datetime]
    progress_trend: GoalProgressResponse

class GoalListResponse(BaseModel):
    total: int
    active_count: int
    completed_count: int
    goals: List[GoalResponse]

class ContentCalendarResponse(BaseModel):
    idea: str
    duration_weeks: int
    posts_per_week: int
    entries: List[ContentCalendarEntry]
    raw_text: str
# ---------------------------------------------------------------------------
# Smart assistant (NLP intent + productivity features)
# ---------------------------------------------------------------------------
class SmartIntentRequest(BaseModel):
    text: str
    timezone: Optional[str] = None
    now: Optional[str] = None  # ISO datetime string from client
    mode: Optional[str] = None  # work/home/focus/travel...
    energy: Optional[str] = None  # low/normal/high
    context: Optional[Dict[str, Any]] = None  # arbitrary app context (tasks, contacts, etc.)
class SmartIntentResponse(BaseModel):
    action: str
    payload: Dict[str, Any]
    raw_text: str
class GenericAIResponse(BaseModel):
    payload: Dict[str, Any]
    raw_text: str
class DailyBriefingRequest(BaseModel):
    timezone: Optional[str] = None
    now: Optional[str] = None
    tasks: Optional[List[Dict[str, Any]]] = None  # e.g. [{"title": "", "datetime": ""}]
    messages: Optional[List[str]] = None
    energy: Optional[str] = None
    sleep: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
class NextActionRequest(BaseModel):
    available_minutes: Optional[int] = None
    energy: Optional[str] = None
    mode: Optional[str] = None
    # برخی کلاینت‌ها آرایهٔ رشته یا اشیاء می‌فرستند؛ اجازه می‌دهیم هر نوعی را بپذیریم.
    tasks: Optional[List[Any]] = None
    context: Optional[Dict[str, Any]] = None
class NotificationIntelRequest(BaseModel):
    notifications: List[Dict[str, Any]]
    mode: Optional[str] = None
    timezone: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
class InboxIntelRequest(BaseModel):
    message: str
    channel: Optional[str] = None  # whatsapp/sms/email
    context: Optional[Dict[str, Any]] = None
class WeeklySchedulerRequest(BaseModel):
    goals: List[str]
    hard_events: Optional[List[Dict[str, Any]]] = None  # existing calendar events
    timezone: Optional[str] = None
    now: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
class MemoryUpsertRequest(BaseModel):
    facts: List[str]
    key: Optional[str] = None
class MemorySearchRequest(BaseModel):
    query: Optional[str] = None
    limit: int = 5
class MemorySearchResponse(BaseModel):
    items: List[Dict[str, Any]]
class OTPRequestBody(BaseModel):
    phone: str
class OTPVerifyBody(BaseModel):
    phone: str
    code: str
    device_token: Optional[str] = None
    device_platform: Optional[str] = None  # ios/android/web
class OTPVerifyResponse(BaseModel):
    token: str
    user_id: int
    phone: str
class MeResponse(BaseModel):
    user_id: int
    phone: str
    created_at: datetime
    last_login: Optional[datetime] = None
class ResearchSection(BaseModel):
    title: str
    summary: str
    takeaways: List[str]
    sources: Optional[List[Dict[str, Any]]] = None
class DeepResearchRequest(BaseModel):
    query: str
    depth: Literal["summary", "detailed", "comprehensive"] = "detailed"
    audience: Optional[str] = None
    language: str = "fa"
    languages: Optional[List[str]] = None  # زبان‌های هدف برای جست‌وجو (مثلاً ["fa", "en"])
    max_queries: int = 6  # حداکثر تعداد کوئری‌های جست‌وجو
    max_sources: int = 8  # حداکثر تعداد منبع برای اسکرپ
    include_outline: bool = True
    include_sources: bool = True
class DeepResearchResponse(BaseModel):
    query: str
    depth: str
    summary: str
    sections: List[ResearchSection]
    outline: Optional[List[str]] = None
    sources: Optional[List[Dict[str, Any]]] = None
    raw_text: str
class AppVersionRequest(BaseModel):
    version: str
class AppVersionResponse(BaseModel):
    update_required: bool
    latest_version: str
    download_url: Optional[str] = None
# ═══════════════════════════════════════════════════════════════════
# PERSONALIZATION API - Phase 1 Request/Response Models
# ═══════════════════════════════════════════════════════════════════
class UserProfileSetupRequest(BaseModel):
    """Profile setup during onboarding"""
    name: str
    role: str
    timezone: str = "Asia/Tehran"
    interests: List[str]
    wake_up_time: int = 6
    sleep_time: int = 23
    focus_hours: int = 6
class UserProfileResponse(BaseModel):
    """User profile response"""
    user_id: int
    name: str
    role: str
    timezone: str
    interests: List[str]
    wake_up_time: int
    sleep_time: int
    focus_hours: int
    avg_energy: Optional[int] = None
    avg_mood: Optional[int] = None
    active_goal_ids: List[str]
    preferred_break_duration: int
    enable_motivation: bool
    communication_style: str
    track_habits: bool
    created_at: datetime
class UserProfileUpdateRequest(BaseModel):
    """Update user profile"""
    name: Optional[str] = None
    timezone: Optional[str] = None
    interests: Optional[List[str]] = None
    preferred_break_duration: Optional[int] = None
    enable_motivation: Optional[bool] = None
    communication_style: Optional[str] = None
class UserGoalCreateRequest(BaseModel):
    """Create a new goal"""
    title: str
    category: str  # Work, Health, Learning, Personal, Creative
    description: str
    deadline: str  # ISO datetime string
    priority: int  # 1-5
    milestones: Optional[List[str]] = None
class UserGoalResponse(BaseModel):
    """Goal response"""
    goal_id: str
    user_id: int
    title: str
    category: str
    description: str
    deadline: str
    priority: int
    progress_percentage: int
    status: str  # active, completed, archived
    created_at: str
class UserGoalUpdateRequest(BaseModel):
    """Update goal progress"""
    progress_percentage: Optional[int] = None
    status: Optional[str] = None
    milestones: Optional[List[str]] = None
class MoodSnapshotRequest(BaseModel):
    """Record mood snapshot"""
    energy: int  # 1-10
    mood: int  # 1-10
    context: str  # At work, Home, Gym, etc.
    activity: Optional[str] = None
    notes: Optional[str] = None
class MoodSnapshotResponse(BaseModel):
    """Mood snapshot response"""
    snapshot_id: str
    user_id: int
    timestamp: str
    energy: int
    mood: int
    context: str
    activity: Optional[str] = None
class MoodHistoryResponse(BaseModel):
    """Mood history response"""
    snapshots: List[MoodSnapshotResponse]
    avg_energy: float
    avg_mood: float
    trend: str  # improving, stable, declining
class HabitCreateRequest(BaseModel):
    """Create a new habit"""
    name: str
    category: str
    frequency: str  # Daily, Weekly
    target_count: int = 1
    unit: str = "times"
    linked_goal_id: Optional[str] = None
class HabitResponse(BaseModel):
    """Habit response"""
    habit_id: str
    name: str
    category: str
    frequency: str
    target_count: int
    unit: str
    current_streak: int = 0
    longest_streak: int = 0
    total_completed: int = 0
    completed_today: bool = False
class HabitLogRequest(BaseModel):
    """Log habit completion"""
    count: int = 1
    notes: Optional[str] = None
# ═══════════════════════════════════════════════════════════════════
# PHASE 2: DAILY PROGRAM & SMART SCHEDULING REQUESTS/RESPONSES
# ═══════════════════════════════════════════════════════════════════
class ProgramActivityRequest(BaseModel):
    """Single activity in daily program"""
    title: str
    description: Optional[str] = None
    start_time: str  # ISO format
    end_time: str    # ISO format
    category: str    # goal, habit, break, focus, rest
    priority: str = "medium"  # high, medium, low
    related_goal_id: Optional[str] = None
    related_habit_id: Optional[str] = None
    is_flexible: bool = True
class DailyProgramGenerateRequest(BaseModel):
    """Request to generate daily program"""
    date: Optional[str] = None  # ISO format, default today
    current_mood: float = 5.0  # 1-10
    current_energy: float = 5.0  # 1-10
class DailyProgramResponse(BaseModel):
    """Daily program response"""
    program_id: str
    user_id: int
    date: str
    activities: List[Dict[str, Any]] = []
    expected_productivity: Optional[float] = None
    expected_mood: Optional[float] = None
    focus_theme: Optional[str] = None
    is_completed: bool = False
    created_at: str
class SchedulingRecommendationRequest(BaseModel):
    """Request scheduling analysis"""
    pass
class SchedulingRecommendationResponse(BaseModel):
    """Single scheduling recommendation"""
    task_id: str
    task_title: str
    recommended_time: str
    reason: str
    score: float  # 0-100
    factors: List[str] = []
    is_optimal: bool = False
class SchedulingAnalysisResponse(BaseModel):
    """Scheduling analysis response"""
    recommendations: List[SchedulingRecommendationResponse] = []
    overall_productivity_score: float
    schedule_health_status: str
    improvements: List[str] = []
    generated_at: str
class MCPWebSearchRequest(BaseModel):
    query: str
    language: str = "fa"
    max_sources: int = 3
    temperature: float = 0.0
class MCPWebSearchResponse(BaseModel):
    query: str
    answer: str
    model: str
    provider: Optional[str] = None
    sources: Optional[List[Dict[str, Any]]] = None
class MCPWebScrapeRequest(BaseModel):
    url: str
    limit: int = 2000
    summarize: bool = True
    summary_prompt: Optional[str] = None
class MCPWebScrapeResponse(BaseModel):
    url: str
    title: str
    text: str
    summary: Optional[str] = None
    summary_prompt_used: Optional[str] = None
    model: Optional[str] = None
    provider: Optional[str] = None
class MCPImageData(BaseModel):
    url: Optional[str] = None
    b64_json: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
class MCPImageGenerationRequest(BaseModel):
    prompt: str
    model: Optional[str] = None
    provider: Optional[str] = None
    response_format: Literal["url", "b64_json"] = "url"
    size: Optional[str] = None
    n: int = 1
class MCPImageGenerationResponse(BaseModel):
    model: str
    provider: Optional[str] = None
    prompt: Optional[str] = None  # final English prompt sent to the image model
    original_prompt: Optional[str] = None
    images: List[MCPImageData]
def _public_base_url(request: Request) -> Optional[str]:
    """Resolve the outward-facing base URL respecting reverse proxy headers."""
    scheme = request.headers.get("x-forwarded-proto") or request.url.scheme
    host = request.headers.get("x-forwarded-host") or request.headers.get("host")
    if not host:
        hostname = request.url.hostname
        port = request.url.port
        if hostname:
            host = f"{hostname}:{port}" if port else hostname
    if scheme and host:
        return f"{scheme}://{host}".rstrip("/")
    return None
def _enhance_prompt_with_quality(prompt: str, size: Optional[str] = None) -> str:
    """
    اضافه کردن keywords کیفیت برای بهتر شدن تصاویر
    """
    quality_keywords = [
        "high quality", "detailed", "professional", "HD",
        "artstation", "trending", "masterpiece"
    ]
    
    # اگر قبلاً quality keywords دارند، skip کن
    if any(kw.lower() in prompt.lower() for kw in quality_keywords):
        return prompt
    
    # انتخاب حجم مناسب برای اضافه کردن
    size_hint = ""
    if size and "1024" in size:
        size_hint = ", 4k resolution"
    elif size and "512" in size:
        size_hint = ", high quality"
    
    return f"{prompt}, professional quality{size_hint}, well-detailed --ar {_get_aspect_ratio(size)}"
def _get_aspect_ratio(size: Optional[str]) -> str:
    """
    تبدیل size به aspect ratio
    """
    if not size:
        return "16:9"
    
    size_map = {
        "1024x1024": "1:1",
        "512x512": "1:1",
        "1024x768": "4:3",
        "768x1024": "3:4",
        "1280x720": "16:9",
        "720x1280": "9:16",
    }
    
    return size_map.get(size, "16:9")
def _generate_enhancement_prompt(style: str) -> str:
    """تولید prompt برای بهبود تصویر"""
    styles = {
        "enhance": "بهبود دقت، رزولوشن 4K، جزئیات بیشتر",
        "cartoon": "تبدیل به سبک کارتون، رنگ‌های پر جنب و جوش",
        "artistic": "سبک هنری، رنگ‌های رنگین، اثر دستی",
        "realistic": "واقع‌گرایی بیشتر، نورپردازی حرفه‌ای، جزئیات طبیعی",
    }
    return styles.get(style, styles["enhance"])
def _rewrite_image_url_for_client(
    image_url: Optional[str],
    request: Request,
    filename: Optional[str] = None,
) -> Optional[str]:
    """Rewrite localhost/relative image URLs to the public FastAPI base URL."""
    if not image_url and filename:
        image_url = f"/images/{filename}"
    if not image_url:
        return None
    parsed = urlparse(image_url)
    base_url = _public_base_url(request)
    needs_rewrite = parsed.hostname in {"localhost", "127.0.0.1", "0.0.0.0"} or not parsed.scheme
    if needs_rewrite and base_url:
        path = parsed.path or "/"
        query = f"?{parsed.query}" if parsed.query else ""
        return f"{base_url.rstrip('/')}/{path.lstrip('/')}{query}"
    if not parsed.scheme and parsed.path:
        # relative path: attach current base
        return f"{(base_url or '').rstrip('/')}/{parsed.path.lstrip('/')}"
    return image_url
async def _generate_image_local_service(
    prompt: str,
    response_format: str,
    request: Request,
    size: Optional[str],
    n: int,
) -> List[MCPImageData]:
    """
    Try the local image generator (http://localhost:3000/generate) before g4f.
    Returns MCPImageData list with URLs rewritten to the public base.
    """
    payload: Dict[str, Any] = {"prompt": prompt}
    if size:
        payload["size"] = size
    if n and n > 1:
        payload["n"] = n
    try:
        timeout = httpx.Timeout(LOCAL_IMAGE_TIMEOUT, read=LOCAL_IMAGE_TIMEOUT, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(LOCAL_IMAGE_GENERATE_URL, json=payload)
    except Exception as exc:  # noqa: BLE001
        detail = f"Local image service error: {exc}" if str(exc) else f"Local image service error ({exc.__class__.__name__})"
        raise HTTPException(status_code=502, detail=detail) from exc
    if resp.status_code >= 400:
        raise HTTPException(status_code=resp.status_code, detail=f"Local image service returned {resp.status_code}: {resp.text}")
    try:
        data: Dict[str, Any] = resp.json()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Invalid JSON from local image service: {exc}") from exc
    if not isinstance(data, dict):
        raise HTTPException(status_code=502, detail="Local image service did not return an image.")
    # اگر سرویس success=False برگرداند، ولی آدرس یا فایل‌نام داد، یک بار دیگر سعی می‌کنیم خودِ تصویر را بگیریم
    if not data.get("success"):
        filename_hint = data.get("filename")
        raw_url_hint = data.get("image_url")
        candidate_url = raw_url_hint or (filename_hint and f"{_local_images_base_url()}/images/{filename_hint}")
        if candidate_url:
            try:
                timeout = httpx.Timeout(LOCAL_IMAGE_TIMEOUT, read=LOCAL_IMAGE_TIMEOUT, connect=10.0)
                async with httpx.AsyncClient(timeout=timeout) as client:
                    probe = await client.get(candidate_url)
                if probe.status_code < 400:
                    # تصویر در دسترس است؛ به مسیر معمول برگردیم
                    data["success"] = True
                    data["image_url"] = candidate_url
                    data.setdefault("filename", filename_hint or candidate_url.rsplit("/", 1)[-1])
                else:
                    raise HTTPException(status_code=probe.status_code, detail="Local image service did not return an image.")
            except HTTPException:
                raise
            except Exception:
                raise HTTPException(status_code=502, detail="Local image service did not return an image.")
        else:
            raise HTTPException(status_code=502, detail="Local image service did not return an image.")
    filename = data.get("filename")
    public_url = _rewrite_image_url_for_client(data.get("image_url"), request, filename)
    raw_url = data.get("image_url")
    images: List[MCPImageData] = []
    if response_format == "b64_json":
        target_url = raw_url or public_url
        if not target_url:
            raise HTTPException(status_code=502, detail="Local image service returned no image URL.")
        try:
            timeout = httpx.Timeout(LOCAL_IMAGE_TIMEOUT, read=LOCAL_IMAGE_TIMEOUT, connect=10.0)
            async with httpx.AsyncClient(timeout=timeout) as client:
                img_resp = await client.get(target_url)
            img_resp.raise_for_status()
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=502, detail=f"Failed to fetch image content: {exc}") from exc
        b64_value = base64.b64encode(img_resp.content).decode("ascii")
        images.append(MCPImageData(b64_json=b64_value, metadata={"filename": filename, "source": "local"}))
    else:
        if not public_url and raw_url:
            public_url = _rewrite_image_url_for_client(raw_url, request, filename)
        if not public_url:
            raise HTTPException(status_code=502, detail="Local image service returned no image URL.")
        images.append(MCPImageData(url=public_url, metadata={"filename": filename, "source": "local"}))
    return images
async def _generate_image_g4f(
    prompt: str,
    model_name: str,
    response_format: str,
    provider: Optional[Any],
    provider_kwargs: Optional[Dict[str, Any]],
    size: Optional[str],
    n: int,
) -> List[MCPImageData]:
    client = AsyncClient()
    kwargs: Dict[str, Any] = {
        "prompt": prompt,
        "model": model_name,
        "response_format": response_format,
        "n": n,
    }
    if provider:
        kwargs["provider"] = provider
    if size:
        kwargs["size"] = size
    if provider_kwargs:
        kwargs.update(provider_kwargs)
    image_response = await client.images.async_generate(**kwargs)
    data = getattr(image_response, "data", None)
    if not data:
        raise HTTPException(status_code=502, detail="پاسخی از سرویس g4f دریافت نشد.")
    images: List[MCPImageData] = []
    for item in data:
        url_value = item.get("url") if isinstance(item, dict) else getattr(item, "url", None)
        b64_value = item.get("b64_json") if isinstance(item, dict) else getattr(item, "b64_json", None)
        metadata_value = item.get("metadata") if isinstance(item, dict) else getattr(item, "metadata", None)
        payload: Dict[str, Any] = {}
        if url_value:
            payload["url"] = url_value
        if b64_value:
            payload["b64_json"] = b64_value
        if metadata_value:
            payload["metadata"] = metadata_value
        if payload:
            images.append(MCPImageData(**payload))
    if not images:
        raise HTTPException(status_code=502, detail="داده تصویر خالی از g4f برگشت.")
    return images
async def _generate_image_google_ai_studio(
    prompt: str,
    model: str,
    response_format: str = "b64_json",
    size: Optional[str] = None,
) -> List[MCPImageData]:
    """
    Direct call to Google AI Studio image generation (Gemini/Imagen).
    Returns a list of MCPImageData populated with base64 images.
    """
    if not GOOGLE_AI_STUDIO_API_KEY:
        raise HTTPException(status_code=503, detail="Google AI Studio API key is missing.")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": GOOGLE_AI_STUDIO_API_KEY,
    }
    # size hint is appended into the prompt because the API does not expose explicit size in all models.
    size_hint = f" --target size {size}" if size else ""
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": f"{prompt}{size_hint}".strip()},
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.4,
        },
    }
    async with httpx.AsyncClient(timeout=25.0) as client:
        resp = await client.post(url, headers=headers, json=payload)
    if resp.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"Google AI Studio error: {resp.text}")
    data = resp.json()
    candidates = data.get("candidates") or []
    images: List[MCPImageData] = []
    for cand in candidates:
        content = cand.get("content") or {}
        parts = content.get("parts") or []
        for part in parts:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline:
                b64_value = inline.get("data")
                mime_type = inline.get("mimeType") or inline.get("mime_type")
                payload: Dict[str, Any] = {}
                if b64_value:
                    payload["b64_json"] = b64_value
                if mime_type:
                    payload["metadata"] = {"mime_type": mime_type}
                if payload:
                    images.append(MCPImageData(**payload))
            # Some responses may use the legacy "fileData" key
            file_data = part.get("fileData") or part.get("file_data")
            if file_data:
                uri = file_data.get("fileUri") or file_data.get("file_uri")
                if uri:
                    images.append(MCPImageData(url=uri, metadata={"type": "file_uri"}))
    if not images:
        raise HTTPException(status_code=502, detail="Google AI Studio returned no images.")
    return images
class AgentTaskCreate(BaseModel):
    title: str
    brief: str
    audience: Optional[str] = None
    tone: Optional[str] = None
    language: str = "fa"
    outline: Optional[List[str]] = None
    word_count: Optional[int] = None
    include_research: bool = True
class AgentTaskResponse(BaseModel):
    id: int
    title: str
    status: str
    result_text: Optional[str] = None
    language: str
    outline: Optional[List[str]] = None
    created_at: datetime
    updated_at: datetime
    last_error: Optional[str] = None
def _get_fcm_session() -> GoogleAuthorizedSession:
    global _FCM_SESSION
    if _FCM_SESSION is not None:
        return _FCM_SESSION
    if service_account is None or AuthorizedSession is None:
        raise HTTPException(status_code=500, detail="google-auth برای FCM نصب نشده است.")
    if not FCM_SERVICE_ACCOUNT_FILE or not FCM_PROJECT_ID:
        raise HTTPException(status_code=500, detail="FCM_SERVICE_ACCOUNT_FILE یا FCM_PROJECT_ID تنظیم نشده است.")
    creds = service_account.Credentials.from_service_account_file(
        FCM_SERVICE_ACCOUNT_FILE,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    _FCM_SESSION = AuthorizedSession(creds)
    return _FCM_SESSION
_TELEGRAM_BOT: Optional[TeleBot] = None
_TELEGRAM_STATES: Dict[int, Dict[str, Any]] = {}
def _telegram_enabled() -> bool:
    return TeleBot is not None and TELEGRAM_BOT_TOKEN is not None
def _telegram_is_admin(chat_id: int) -> bool:
    if not TELEGRAM_ADMIN_IDS:
        return True
    return chat_id in TELEGRAM_ADMIN_IDS
def _run_async(coro):
    loop = _APP_LOOP
    if loop and loop.is_running():
        fut = asyncio.run_coroutine_threadsafe(coro, loop)
        return fut.result()
    return asyncio.run(coro)
async def _upsert_telegram_subscriber(message) -> None:
    chat = message.chat
    async with async_session() as session:
        stmt = select(TelegramSubscriber).where(TelegramSubscriber.chat_id == str(chat.id)).limit(1)
        result = await session.execute(stmt)
        record = result.scalar_one_or_none()
        now = datetime.utcnow()
        if record is None:
            record = TelegramSubscriber(
                chat_id=str(chat.id),
                username=chat.username,
                first_name=chat.first_name,
                last_name=chat.last_name,
                created_at=now,
                last_seen=now,
            )
            session.add(record)
        else:
            record.username = chat.username
            record.first_name = chat.first_name
            record.last_name = chat.last_name
            record.last_seen = now
        await session.commit()
async def _list_telegram_subscribers() -> List[TelegramSubscriber]:
    async with async_session() as session:
        result = await session.execute(
            select(TelegramSubscriber).order_by(TelegramSubscriber.created_at.desc())
        )
        return result.scalars().all()
async def _get_subscriber_by_id(subscriber_id: int) -> Optional[TelegramSubscriber]:
    async with async_session() as session:
        result = await session.execute(
            select(TelegramSubscriber).where(TelegramSubscriber.id == subscriber_id).limit(1)
        )
        return result.scalar_one_or_none()
async def _list_users_with_device_tokens(limit: int = 50) -> List[Tuple[int, Optional[str]]]:
    async with async_session() as session:
        stmt = (
            select(User.id, User.phone)
            .join(DeviceToken, DeviceToken.user_id == User.id)
            .group_by(User.id, User.phone)
            .order_by(User.id.desc())
            .limit(limit)
        )
        result = await session.execute(stmt)
        return [(row[0], row[1]) for row in result.fetchall()]
async def _broadcast_push_to_all(body: str, title: str = "پیام از ربات تلگرام") -> int:
    targets = await _list_users_with_device_tokens(limit=500)
    sent = 0
    for user_id, _phone in targets:
        try:
            await _send_push_notification(user_id, title, body)
            sent += 1
        except Exception as exc:  # noqa: BLE001
            log.warning("Broadcast push failed for user %s: %s", user_id, exc)
    return sent
def _setup_telegram_handlers(bot: TeleBot) -> None:
    @bot.message_handler(commands=["start"])
    def _start(message):
        try:
            _run_async(_upsert_telegram_subscriber(message))
        except Exception as exc:  # noqa: BLE001
            log.warning("Failed to persist Telegram subscriber: %s", exc)
        markup = tb_types.ReplyKeyboardMarkup(resize_keyboard=True)
        markup.row("ارسال همگانی", "ارسال تکی")
        bot.reply_to(
            message,
            "سلام! از این دکمه‌ها برای ارسال نوتیف استفاده کن.",
            reply_markup=markup,
        )
    @bot.message_handler(func=lambda m: m.text == "ارسال همگانی")
    def _broadcast_prompt(message):
        if not _telegram_is_admin(message.chat.id):
            bot.reply_to(message, "دسترسی نداری.")
            return
        _TELEGRAM_STATES[message.chat.id] = {"mode": "broadcast"}
        bot.reply_to(message, "عنوان و متن نوتیف را بفرست (خط اول عنوان، خطوط بعدی متن). اگر یک خط بفرستی عنوان پیش‌فرض استفاده می‌شود.")
    @bot.message_handler(func=lambda m: m.text == "ارسال تکی")
    def _direct_prompt(message):
        if not _telegram_is_admin(message.chat.id):
            bot.reply_to(message, "دسترسی نداری.")
            return
        targets = _run_async(_list_users_with_device_tokens())
        if not targets:
            bot.reply_to(message, "هیچ دستگاه فعالی پیدا نشد.")
            return
        markup = tb_types.InlineKeyboardMarkup()
        for uid, phone in targets[:20]:
            label = f"{phone or 'user'} (id {uid})"
            markup.add(tb_types.InlineKeyboardButton(label, callback_data=f"tg_send:{uid}"))
        bot.reply_to(message, "کاربر را انتخاب کن (Push):", reply_markup=markup)
    @bot.callback_query_handler(func=lambda call: call.data.startswith("tg_send:"))
    def _select_user(call):
        if not _telegram_is_admin(call.message.chat.id):
            bot.answer_callback_query(call.id, "اجازه نداری.", show_alert=True)
            return
        try:
            target_id = int(call.data.split(":")[1])
        except (IndexError, ValueError):
            bot.answer_callback_query(call.id, "خطا در انتخاب.", show_alert=True)
            return
        _TELEGRAM_STATES[call.message.chat.id] = {"mode": "direct", "target_id": target_id}
        bot.answer_callback_query(call.id, "کاربر انتخاب شد.")
        bot.send_message(
            call.message.chat.id,
            "عنوان و متن نوتیف را بفرست (خط اول عنوان، خطوط بعدی متن). اگر یک خط بفرستی عنوان پیش‌فرض استفاده می‌شود.",
        )
    @bot.message_handler(func=lambda m: m.chat.id in _TELEGRAM_STATES)
    def _handle_message(message):
        state = _TELEGRAM_STATES.get(message.chat.id)
        if not state:
            return
        if state.get("mode") == "broadcast":
            raw_text = message.text or ""
            del _TELEGRAM_STATES[message.chat.id]
            if "\n" in raw_text:
                title_line, body_text = raw_text.split("\n", 1)
                title = title_line.strip() or "پیام از ربات تلگرام"
                body = body_text.strip()
            else:
                title = "پیام از ربات تلگرام"
                body = raw_text.strip()
            sent = _run_async(_broadcast_push_to_all(body, title))
            bot.reply_to(message, f"Push به {sent} کاربر ارسال شد.")
        elif state.get("mode") == "direct":
            target_id = state.get("target_id")
            del _TELEGRAM_STATES[message.chat.id]
            if target_id is None:
                bot.reply_to(message, "کاربر انتخاب نشده.")
                return
            raw_text = message.text or ""
            if "\n" in raw_text:
                title_line, body_text = raw_text.split("\n", 1)
                title = title_line.strip() or "پیام مستقیم از ربات تلگرام"
                body = body_text.strip()
            else:
                title = "پیام مستقیم از ربات تلگرام"
                body = raw_text.strip()
            try:
                _run_async(_send_push_notification(int(target_id), title, body))
                bot.reply_to(message, "Push ارسال شد.")
            except Exception as exc:  # noqa: BLE001
                log.warning("Telegram direct send failed: %s", exc)
                bot.reply_to(message, "ارسال نشد.")
def _start_telegram_bot() -> None:
    global _TELEGRAM_BOT
    if _TELEGRAM_BOT is not None:
        return
    if not _telegram_enabled():
        log.info("Telegram bot disabled (missing token or library).")
        return
    try:
        _TELEGRAM_BOT = TeleBot(TELEGRAM_BOT_TOKEN)  # type: ignore[arg-type]
        _setup_telegram_handlers(_TELEGRAM_BOT)
        thread = threading.Thread(
            target=_TELEGRAM_BOT.polling,
            kwargs={"none_stop": True, "allowed_updates": ["message", "callback_query"]},
            daemon=True,
        )
        thread.start()
        log.info("Telegram bot polling started.")
    except Exception as exc:  # noqa: BLE001
        _TELEGRAM_BOT = None
        log.warning("Failed to start Telegram bot: %s", exc)
async def _send_push_notification(user_id: int, title: str, body: str) -> None:
    """
    Push notifications via FCM HTTP v1; fallback to webhook if provided.
    """
    sent = False
    async def _get_tokens() -> List[str]:
        async with async_session() as session:
            stmt = select(DeviceToken.device_token).where(DeviceToken.user_id == user_id)
            result = await session.execute(stmt)
            return [row[0] for row in result.fetchall() if row[0]]
    tokens: List[str] = await _get_tokens()
    # Send via FCM v1 if configured
    try:
        session = _get_fcm_session()
        endpoint = f"https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send"
        targets = tokens or [None]  # None => topic fallback
        for tok in targets:
            msg: Dict[str, Any] = {
                "message": {
                    "notification": {"title": title, "body": body},
                    "data": {"user_id": str(user_id), "title": title, "body": body},
                }
            }
            if tok:
                msg["message"]["token"] = tok
            else:
                msg["message"]["topic"] = f"user-{user_id}"
            resp = session.post(endpoint, json=msg)
            if resp.status_code < 400:
                sent = True
            else:
                log.warning("FCM v1 push failed: %s", resp.text)
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        log.warning("FCM v1 push exception: %s", exc)
    # Fallback webhook if provided
    if not sent and PUSH_WEBHOOK_URL:
        payload = {"user_id": user_id, "title": title, "body": body}
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                resp = await client.post(PUSH_WEBHOOK_URL, json=payload)
                resp.raise_for_status()
                sent = True
        except Exception as exc:  # noqa: BLE001
            log.warning("Push webhook failed: %s", exc)
    log.info("Push notification => user=%s | %s | %s", user_id, title, body)
SESSIONS: Dict[str, List[Message]] = {}
SESSIONS_LOCK = asyncio.Lock()
def _estimate_tokens_for_text(text: str) -> int:
    # quick heuristic: ~4 chars per token + small overhead
    return max(1, len(text) // 4 + 1)
def _estimate_tokens_for_messages(messages: List[Message]) -> int:
    return sum(_estimate_tokens_for_text(m.content) + 4 for m in messages)
def _trim_messages_to_budget(messages: List[Message], token_budget: int, max_messages: int) -> List[Message]:
    if not messages:
        return []
    trimmed = _clone_messages(messages)
    prefix: List[Message] = []
    while trimmed and trimmed[0].role == "system" and len(prefix) < 2:
        prefix.append(trimmed.pop(0))
    body = trimmed
    while body and (_estimate_tokens_for_messages(prefix + body) > token_budget or len(prefix + body) > max_messages):
        body.pop(0)
    return prefix + body
async def _summarize_messages_for_history(messages: List[Message]) -> str:
    if not messages:
        return "گفت‌وگوی قبلی خلاصه‌ای نداشت."
    text = "\n".join(f"{m.role}: {m.content}" for m in messages)
    if len(text) > SUMMARY_CHAR_LIMIT:
        text = text[-SUMMARY_CHAR_LIMIT:]
    summary_messages = [
        {
            "role": "system",
            "content": (
                "You are a concise conversation summarizer. Summarize the prior dialogue in Persian, "
                f"no more than {SUMMARY_TARGET_WORDS} words. Keep important decisions, names, and actions."
            ),
        },
        {"role": "user", "content": text},
    ]
    try:
        summary = await _fallback_completion(summary_messages, temperature=0.2)
    except Exception as exc:  # noqa: BLE001
        log.warning("History summarization failed, using tail: %s", exc)
        summary = text[-800:]
    return summary.strip()
async def _maybe_compact_session(session_id: str) -> None:
    async with SESSIONS_LOCK:
        history = list(SESSIONS.get(session_id, []))
        if not history:
            return
    current_tokens = _estimate_tokens_for_messages(history)
    if current_tokens <= MAX_SESSION_TOKEN_ESTIMATE and len(history) <= MAX_SESSION_MESSAGES:
        return
    prefix: List[Message] = []
    body = list(history)
    if body and body[0].role == "system":
        prefix.append(body.pop(0))
    if len(body) <= SESSION_RECENT_MESSAGES:
        SESSIONS[session_id] = _trim_messages_to_budget(prefix + body, MAX_SESSION_TOKEN_ESTIMATE, MAX_SESSION_MESSAGES)
        return
    older = body[:-SESSION_RECENT_MESSAGES]
    recent = body[-SESSION_RECENT_MESSAGES:]
    summary_text = await _summarize_messages_for_history(older)
    summary_msg = Message(
        role="system",
        content=f"خلاصه‌ی مکالمات قبلی (برای حفظ محدودیت توکن): {summary_text}",
    )
    compacted = _trim_messages_to_budget(prefix + [summary_msg] + recent, MAX_SESSION_TOKEN_ESTIMATE, MAX_SESSION_MESSAGES)
    async with SESSIONS_LOCK:
        SESSIONS[session_id] = compacted
    log.info(
        "Compacted session %s history: %s -> %s tokens, %s messages",
        session_id,
        current_tokens,
        _estimate_tokens_for_messages(compacted),
        len(compacted),
    )
def _clone_messages(messages: List[Message]) -> List[Message]:
    return [Message(role=m.role, content=m.content) for m in messages]
async def _combined_session_messages(session_id: Optional[str], new_messages: List[Message]) -> List[Message]:
    if not session_id:
        return new_messages
    async with SESSIONS_LOCK:
        history = SESSIONS.get(session_id, [])
        return _clone_messages(history) + new_messages
async def _store_session_messages(session_id: Optional[str], new_messages: List[Message], assistant_text: Optional[str]) -> None:
    if not session_id:
        return
    async with SESSIONS_LOCK:
        history = SESSIONS.setdefault(session_id, [])
        history.extend(_clone_messages(new_messages))
        if assistant_text is not None:
            history.append(Message(role="assistant", content=assistant_text))
    await _maybe_compact_session(session_id)
async def _reset_session(session_id: Optional[str]) -> None:
    if not session_id:
        return
    async with SESSIONS_LOCK:
        SESSIONS.pop(session_id, None)
def _apply_request_context_budget(messages: List[Message]) -> List[Message]:
    return _trim_messages_to_budget(messages, MAX_REQUEST_TOKEN_ESTIMATE, MAX_SESSION_MESSAGES)
def _limit_messages_for_expert(messages: List[Message]) -> List[Message]:
    """Keep system prompts and the most recent N messages to avoid oversized prompts."""
    system_msgs = [m for m in messages if m.role == "system"]
    non_system = [m for m in messages if m.role != "system"]
    tail = non_system[-EXPERT_RECENT_MESSAGES:] if len(non_system) > EXPERT_RECENT_MESSAGES else non_system
    return system_msgs + tail
def _expert_guardrail(domain: str) -> str:
    today = datetime.utcnow().date().isoformat()
    return (
        f"RAIL: پاسخ فقط در حوزه تخصصی {domain} بده. "
        "خارج از این حوزه، با احترام بگو خارج از تخصص است. "
        "بر اساس شواهد و استانداردهای معتبر 2023-2025 پاسخ بده و در صورت عدم قطعیت، صریحاً بگو مطمئن نیستی. "
        "پاسخ را خلاصه و ساختاریافته بده (بولت یا مراحل). "
        "هیچ توصیه پزشکی/درمانی بدون هشدار ایمنی ارائه نکن. "
        f'تاریخ امروز (برای اشاره به جدید بودن اطلاعات): {today}.'
    )
def _decode_bytes_to_text(data: bytes, charset: Optional[str] = None) -> str:
    if charset:
        try:
            return data.decode(charset, errors="replace")
        except LookupError:
            pass
    try:
        return data.decode("utf-8")
    except Exception:
        return data.decode("utf-8", errors="replace")
def _is_probably_binary(data: bytes) -> bool:
    sample = data[:4096]
    if b"\x00" in sample:
        return True
    # اگر بیش از 35٪ کاراکترها غیرقابل چاپ باشند، باینری فرض کن
    non_printable = sum(1 for b in sample if b < 9 or (13 < b < 32) or b > 126)
    return non_printable / max(1, len(sample)) > 0.35
def _reject_binary(reason: str) -> None:
    raise HTTPException(
        status_code=400,
        detail=f"فایل باینری/غیرمتنی پشتیبانی نمی‌شود: {reason}. لطفاً نسخه متنی (txt/md/csv/json) بفرستید.",
    )
def _check_extension_is_text(_name: str) -> None:
    # قبلاً برای مسدودکردن پسوندها استفاده می‌شد؛ حالا به‌صورت noop باقی مانده تا سازگاری حفظ شود.
    return None
def _extract_docx_text(data: bytes) -> str:
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            with zf.open("word/document.xml") as doc_xml:
                xml_text = doc_xml.read().decode("utf-8", errors="ignore")
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"استخراج متن DOCX ناموفق بود: {exc}") from exc
    # تگ‌ها را حذف و فضای خالی را فشرده می‌کنیم
    text = re.sub(r"<(.|\n)*?>", " ", xml_text)
    text = html.unescape(text)
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    return "\n".join(lines)
def _extract_pdf_text(data: bytes, max_pages: int = 5) -> str:
    reader = None
    try:
        import PyPDF2  # type: ignore
        reader = PyPDF2.PdfReader(io.BytesIO(data))
    except Exception:
        try:
            import pypdf as PyPDF2  # type: ignore  # noqa: N816
            reader = PyPDF2.PdfReader(io.BytesIO(data))
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(
                status_code=400,
                detail="برای خواندن PDF به PyPDF2 یا pypdf نیاز است؛ لطفاً کتابخانه را نصب کنید.",
            ) from exc
    texts: List[str] = []
    try:
        for idx, page in enumerate(reader.pages):
            if idx >= max_pages:
                break
            txt = page.extract_text() or ""
            if txt.strip():
                texts.append(txt)
    except Exception as exc:  # noqa: BLE001
            raise HTTPException(
                status_code=400,
                detail=f"استخراج متن PDF ناموفق بود: {exc}"
            ) from exc
    return "\n".join(texts)
def _ingest_bytes(name: str, data: bytes, charset: Optional[str] = None) -> Dict[str, Optional[Any]]:
    suffix = Path(name or "").suffix.lower()
    if suffix in BLOCKED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"فرمت {suffix} پشتیبانی نمی‌شود. فقط متن/تصویر یا PDF/DOCX را بفرستید.")
    # تصاویر (vision)
    if suffix in IMAGE_EXTENSIONS:
        return {"image": data, "image_name": name or "image", "text": None}
    # DOCX
    if suffix == ".docx":
        return {"text": _extract_docx_text(data), "image": None, "image_name": None}
    # PDF
    if suffix == ".pdf":
        return {"text": _extract_pdf_text(data), "image": None, "image_name": None}
    # plain text-ish
    if suffix in TEXT_EXTENSIONS or not _is_probably_binary(data):
        return {"text": _decode_bytes_to_text(data, charset), "image": None, "image_name": None}
    # ناشناخته و باینری
    _reject_binary(f"فرمت ناشناخته ({suffix or 'binary'})")
def _read_local_file_bytes(path_str: str) -> Tuple[str, bytes, Optional[str]]:
    path = Path(path_str)
    if not path.is_absolute():
        path = (BASE_DIR / path_str).resolve()
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=400, detail=f"فایل یافت نشد: {path_str}")
    if path.stat().st_size > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    return path.name, path.read_bytes(), None
async def _fetch_remote_file_bytes(url: str) -> Tuple[str, bytes, Optional[str]]:
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=15.0) as client:
            resp = await client.get(url)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"دریافت فایل از URL ناموفق بود: {exc}") from exc
    if resp.status_code >= 400:
        raise HTTPException(status_code=400, detail=f"دریافت فایل با خطا مواجه شد: HTTP {resp.status_code}")
    data = resp.content or b""
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    content_type = (resp.headers.get("content-type") or "").lower()
    charset = None
    for part in content_type.split(";"):
        part = part.strip()
        if part.startswith("charset="):
            charset = part.split("=", 1)[1].strip() or None
            break
    filename = unquote_plus(url.split("?")[0].split("/")[-1]) or "file"
    return filename, data, charset
async def _ingest_file_uri(uri: str) -> Dict[str, Optional[Any]]:
    uri = uri.strip()
    if not uri:
        raise HTTPException(status_code=400, detail="آدرس فایل خالی است.")
    if uri.startswith("http://") or uri.startswith("https://"):
        name, data, charset = await _fetch_remote_file_bytes(uri)
    else:
        name, data, charset = _read_local_file_bytes(uri)
    return _ingest_bytes(name, data, charset)
async def _ingest_upload_file(upload: UploadFile) -> Dict[str, Optional[Any]]:
    name = upload.filename or "upload"
    if hasattr(upload, "seek"):
        await upload.seek(0)  # type: ignore[func-returns-value]
    data = await upload.read()
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    content_type = upload.content_type or ""
    charset = None
    if "charset=" in content_type:
        charset = content_type.split("charset=", 1)[1].strip() or None
    return _ingest_bytes(name, data, charset)
def _read_local_file_text(path_str: str) -> str:
    path = Path(path_str)
    if not path.is_absolute():
        path = (BASE_DIR / path_str).resolve()
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=400, detail=f"فایل یافت نشد: {path_str}")
    if path.stat().st_size > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    data = path.read_bytes()
    payload = _ingest_bytes(path.name, data, None)
    if payload.get("text") is None:
        raise HTTPException(status_code=400, detail="این فرمت برای خواندن متن پشتیبانی نمی‌شود.")
    return payload["text"]  # type: ignore[index]
async def _fetch_remote_file_text(url: str) -> str:
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=15.0) as client:
            resp = await client.get(url)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"دریافت فایل از URL ناموفق بود: {exc}") from exc
    if resp.status_code >= 400:
        raise HTTPException(status_code=400, detail=f"دریافت فایل با خطا مواجه شد: HTTP {resp.status_code}")
    data = resp.content or b""
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    _check_extension_is_text(unquote_plus(url.split("?")[0].split("/")[-1]))
    if _is_probably_binary(data):
        _reject_binary("محتوای باینری")
    content_type = (resp.headers.get("content-type") or "").lower()
    charset = None
    for part in content_type.split(";"):
        part = part.strip()
        if part.startswith("charset="):
            charset = part.split("=", 1)[1].strip() or None
            break
    return _decode_bytes_to_text(data, charset)
async def _load_file_as_text(uri: str) -> str:
    uri = uri.strip()
    if not uri:
        raise HTTPException(status_code=400, detail="آدرس فایل خالی است.")
    if uri.startswith("http://") or uri.startswith("https://"):
        return await _fetch_remote_file_text(uri)
    return _read_local_file_text(uri)
async def _read_upload_file_text(upload: UploadFile) -> str:
    data = await upload.read()
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail="حجم فایل بیش از حد مجاز است (max 10MB).")
    charset = None
    content_type = upload.content_type or ""
    if "charset=" in content_type:
        charset = content_type.split("charset=", 1)[1].strip() or None
    return _decode_bytes_to_text(data, charset)
def _parse_entry(entry: str) -> Tuple[str, Optional[str]]:
    if "@" in entry:
        m, p = entry.split("@", 1)
        return m.strip(), p.strip() or None
    return entry.strip(), None
def _extract_text_piece(chunk) -> Optional[str]:
    """
    Extract text from a streaming chunk following the AsyncClient interface.
    Prioritise delta content and gracefully fall back to other common attributes.
    """
    if chunk is None:
        return None
    try:
        choices = getattr(chunk, "choices", None)
        if choices:
            choice = choices[0]
            delta = getattr(choice, "delta", None)
            if isinstance(delta, dict):
                text_piece = delta.get("content")
            else:
                text_piece = getattr(delta, "content", None)
            if text_piece:
                return text_piece
            message = getattr(choice, "message", None)
            if isinstance(message, dict):
                text_piece = message.get("content")
            else:
                text_piece = getattr(message, "content", None)
            if text_piece:
                return text_piece
    except Exception:
        # Preserve compatibility even if the response schema changes.
        pass
    return getattr(chunk, "content", None) or getattr(chunk, "text", None)
def _normalize_token_piece(piece) -> Optional[str]:
    """
    Coerce provider-specific structures (lists, rich objects, etc.) into a plain string.
    Falls back to str(piece) so we can safely JSON-encode tokens.
    """
    if piece is None:
        return None
    if isinstance(piece, str):
        return piece
    if isinstance(piece, (list, tuple)):
        joined = "".join(filter(None, (_normalize_token_piece(item) or "" for item in piece)))
        return joined or None
    if isinstance(piece, dict):
        # prefer a direct text field if present
        for key in ("text", "content", "value"):
            if key in piece and piece[key]:
                normalized = _normalize_token_piece(piece[key])
                if normalized:
                    return normalized
        try:
            return json.dumps(piece, ensure_ascii=False)
        except Exception:
            return str(piece)
    for attr in ("text", "content", "value"):
        if hasattr(piece, attr):
            normalized = _normalize_token_piece(getattr(piece, attr))
            if normalized:
                return normalized
    try:
        return str(piece)
    except Exception:
        return repr(piece)
def _outline_to_text(outline: Optional[List[str]]) -> Optional[str]:
    if not outline:
        return None
    cleaned = [item.strip() for item in outline if item and item.strip()]
    if not cleaned:
        return None
    return json.dumps(cleaned, ensure_ascii=False)
def _text_to_outline(value: Optional[str]) -> Optional[List[str]]:
    if not value:
        return None
    try:
        parsed = json.loads(value)
        if isinstance(parsed, list):
            return [str(item) for item in parsed if item]
    except json.JSONDecodeError:
        pass
    return [value] if value else None
def _compare_versions(current: str, target: str) -> int:
    """
    Compare two dotted version strings.
    Returns -1 when current < target, 0 on equality, and 1 otherwise.
    Non-digit separators are treated as delimiters; missing segments default to 0.
    """
    def normalize(value: str) -> List[int]:
        parts = re.split(r"[^\d]+", value.strip())
        normalized = [int(part) for part in parts if part.isdigit()]
        return normalized or [0]
    current_parts = normalize(current)
    target_parts = normalize(target)
    max_len = max(len(current_parts), len(target_parts))
    current_parts.extend([0] * (max_len - len(current_parts)))
    target_parts.extend([0] * (max_len - len(target_parts)))
    for cur, tgt in zip(current_parts, target_parts):
        if cur < tgt:
            return -1
        if cur > tgt:
            return 1
    return 0
def _ensure_research_payload(parsed: Any, fallback_text: str) -> Tuple[str, List[ResearchSection], Optional[List[str]], Optional[List[Dict[str, Any]]]]:
    summary = fallback_text.strip()
    sections: List[ResearchSection] = []
    outline: Optional[List[str]] = None
    sources: Optional[List[Dict[str, Any]]] = None
    if isinstance(parsed, dict):
        summary = parsed.get("summary") or parsed.get("overview") or summary
        outline_value = parsed.get("outline")
        if isinstance(outline_value, list):
            outline = [str(item) for item in outline_value if item]
        sections_value = parsed.get("sections") or parsed.get("parts") or parsed.get("chapters")
        if isinstance(sections_value, list):
            for sec in sections_value:
                title = ""
                details = ""
                takeaways_list: List[str] = []
                sec_sources: Optional[List[Dict[str, Any]]] = None
                if isinstance(sec, dict):
                    title = str(sec.get("title") or sec.get("heading") or "")
                    details = str(sec.get("summary") or sec.get("details") or "")
                    takeaways_raw = sec.get("takeaways") or sec.get("bullets") or []
                    if isinstance(takeaways_raw, list):
                        takeaways_list = [str(item) for item in takeaways_raw if item]
                    elif isinstance(takeaways_raw, str):
                        takeaways_list = [takeaways_raw]
                    sec_sources_raw = sec.get("sources")
                    if isinstance(sec_sources_raw, list):
                        sec_sources = []
                        for source in sec_sources_raw:
                            if isinstance(source, dict):
                                sec_sources.append(source)
                            elif isinstance(source, str):
                                sec_sources.append({"title": source})
                elif isinstance(sec, str):
                    details = sec
                if not title:
                    title = "بخش"
                if not details:
                    details = summary
                if not takeaways_list:
                    takeaways_list = [details[:200]]
                sections.append(ResearchSection(
                    title=title,
                    summary=details,
                    takeaways=takeaways_list,
                    sources=sec_sources,
                ))
        sources_value = parsed.get("sources")
        if isinstance(sources_value, list):
            sources = []
            for source in sources_value:
                if isinstance(source, dict):
                    sources.append(source)
                elif isinstance(source, str):
                    sources.append({"title": source})
    if not sections:
        preview = summary[:280] or fallback_text[:280]
        sections.append(ResearchSection(
            title="نتیجه کلی",
            summary=preview,
            takeaways=[preview],
            sources=None,
        ))
    return summary, sections, outline, sources
def _merge_sources(primary: Optional[List[Dict[str, Any]]], secondary: Optional[List[Dict[str, Any]]]) -> Optional[List[Dict[str, Any]]]:
    if not primary and not secondary:
        return None
    combined: List[Dict[str, Any]] = []
    seen = set()
    for collection in (primary or []), (secondary or []):
        for item in collection:
            url = str(item.get("url") or item.get("link") or item.get("source") or "").strip()
            key = url or item.get("title") or json.dumps(item, ensure_ascii=False)
            if key in seen:
                continue
            seen.add(key)
            combined.append(item)
    return combined
def _strip_html(raw: str) -> str:
    text = re.sub(r"(?is)<(script|style).*?>.*?(</\1>)", "", raw)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"https?://\S+", "", text)
    return text.strip()
async def _fetch_page_details(url: str, limit: int = 1500) -> Optional[Dict[str, str]]:
    def _extract_main_body(html_text: str) -> Optional[str]:
        """
        Heuristic extraction of main article text to avoid menus/ads.
        """
        candidates: List[str] = []
        patterns = [
            r"(?is)<article[^>]*>(.*?)</article>",
            r"(?is)<main[^>]*>(.*?)</main>",
            r'(?is)<div[^>]*(id|class)="?(content|post|article|main|entry)[^>]*>(.*?)</div>',
        ]
        for pattern in patterns:
            for match in re.finditer(pattern, html_text):
                groups = match.groups()
                body_html = groups[-1] if groups else match.group(0)
                text = _strip_html(body_html)
                if len(text) >= 200:
                    candidates.append(text)
        if not candidates:
            return None
        return max(candidates, key=len)
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/119.0 Safari/537.36",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
            resp = await client.get(url)
    except Exception:
        return None
    if resp.status_code >= 400:
        return None
    raw_html = resp.text
    main_text = _extract_main_body(raw_html) or _strip_html(raw_html)
    if not main_text:
        return None
    # Deduplicate repetitive menu items by keeping longest unique sentences until limit
    parts: List[str] = []
    seen = set()
    for chunk in re.split(r"(?<=[\.!\?])\s+", main_text):
        norm = chunk.strip()
        if not norm or norm in seen:
            continue
        seen.add(norm)
        parts.append(norm)
        if len(" ".join(parts)) >= limit:
            break
    cleaned = " ".join(parts)[:limit]
    title_match = re.search(r"<title[^>]*>(.*?)</title>", raw_html, re.IGNORECASE | re.DOTALL)
    title = html.unescape(title_match.group(1)).strip() if title_match else url
    return {"text": cleaned, "title": title or url}
async def _fetch_clean_text(url: str, limit: int = 1500) -> Optional[str]:
    details = await _fetch_page_details(url, limit)
    if not details:
        return None
    return details["text"]
async def _scrape_google_results(query: str, max_results: int = 5) -> List[Dict[str, str]]:
    """
    Fallback scraper when DDGS/Google API fails. Parses the classic SERP HTML.
    """
    params = {
        "q": query,
        "hl": "fa",
        "gl": "ir",
        "num": max_results,
        "ie": "UTF-8",
        "oe": "UTF-8",
    }
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/119.0 Safari/537.36",
        "Accept-Language": "fa-IR,fa;q=0.9,en;q=0.8",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
            resp = await client.get("https://www.google.com/search", params=params)
    except Exception:
        return []
    if resp.status_code >= 400:
        return []
    html_text = resp.text
    pattern = re.compile(
        r'<a href="/url\?q=(?P<link>[^"&]+).*?>\s*<h3.*?>(?P<title>.*?)</h3>',
        re.IGNORECASE | re.DOTALL,
    )
    results: List[Dict[str, str]] = []
    for match in pattern.finditer(html_text):
        link = unquote_plus(match.group("link"))
        if not link.startswith("http"):
            continue
        title = re.sub(r"<.*?>", "", match.group("title"))
        title = html.unescape(title).strip() or "Untitled"
        snippet = ""
        snippet_match = re.search(
            r"<span[^>]*>(.*?)</span>", html_text[match.end():match.end() + 500], re.DOTALL
        )
        if snippet_match:
            snippet = re.sub(r"<.*?>", "", snippet_match.group(1))
            snippet = html.unescape(snippet).strip()
        results.append({"title": title, "url": link, "text": snippet})
        if len(results) >= max_results:
            break
    return results
async def _scrape_duckduckgo_results(query: str, max_results: int = 5) -> List[Dict[str, str]]:
    """
    Fallback DuckDuckGo scraper when Google blocks (e.g., sorry page/captcha).
    Uses the HTML endpoint to avoid JS.
    """
    params = {
        "q": query,
        "kl": "ir-fa",
        "ia": "web",
    }
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/119.0 Safari/537.36",
        "Accept-Language": "fa-IR,fa;q=0.9,en;q=0.8",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
            resp = await client.get("https://duckduckgo.com/html/", params=params)
    except Exception:
        return []
    if resp.status_code >= 400:
        return []
    html_text = resp.text
    results: List[Dict[str, str]] = []
    # Extract title/url
    pattern = re.compile(r'<a[^>]+class="result__a"[^>]+href="(?P<href>[^"]+)"[^>]*>(?P<title>.*?)</a>', re.IGNORECASE | re.DOTALL)
    for match in pattern.finditer(html_text):
        url = html.unescape(match.group("href"))
        title = re.sub(r"<.*?>", "", match.group("title"))
        title = html.unescape(title).strip() or "Untitled"
        snippet = ""
        # Try to find snippet near the match
        snippet_match = re.search(
            r'<a[^>]+class="result__snippet"[^>]*>(?P<snippet>.*?)</a>',
            html_text[match.end(): match.end() + 500],
            re.IGNORECASE | re.DOTALL,
        )
        if snippet_match:
            snippet = re.sub(r"<.*?>", "", snippet_match.group("snippet"))
            snippet = html.unescape(snippet).strip()
        else:
            snippet_match = re.search(
                r'<div[^>]+class="result__snippet"[^>]*>(?P<snippet>.*?)</div>',
                html_text[match.end(): match.end() + 500],
                re.IGNORECASE | re.DOTALL,
            )
            if snippet_match:
                snippet = re.sub(r"<.*?>", "", snippet_match.group("snippet"))
                snippet = html.unescape(snippet).strip()
        if url and url.startswith("http"):
            results.append({"title": title, "url": url, "text": snippet})
        if len(results) >= max_results:
            break
    return results
async def _google_search_urls(query: str, max_results: int = 3, lang: str = "fa") -> List[str]:
    def _run_search():
        try:
            return list(islice(google_search(query, num_results=max_results, stop=max_results, lang=lang), max_results))
        except TypeError:
            pass
        try:
            return list(islice(google_search(query, num_results=max_results, lang=lang), max_results))
        except TypeError:
            pass
        try:
            return list(islice(google_search(query, lang=lang), max_results))
        except TypeError:
            pass
        # Last-resort bare call
        return list(islice(google_search(query), max_results))
    try:
        return await asyncio.to_thread(_run_search)
    except Exception as exc:  # noqa: BLE001
        log.warning("googlesearch-python failed for '%s': %s", query[:80], exc)
        return []
def _serialize_agent_task(task: AgentTask) -> AgentTaskResponse:
    return AgentTaskResponse(
        id=task.id,
        title=task.title,
        status=task.status,
        result_text=task.result_text,
        language=task.language,
        outline=_text_to_outline(task.outline),
        created_at=task.created_at,
        updated_at=task.updated_at,
        last_error=task.last_error,
    )
async def _generate_agent_article(body: AgentTaskCreate) -> str:
    research_context = ""
    if body.include_research:
        research_prompt, _sources = await _google_search_summary(
            body.brief,
            fetch_pages=True,
            max_pages=3,
        )
        if research_prompt:
            research_context = f"\n\n### Context from research\n{research_prompt}"
    outline_text = ""
    if body.outline:
        outline_lines = "\n".join(f"- {item}" for item in body.outline if item)
        outline_text = f"\nDesired outline:\n{outline_lines}\n"
    user_prompt = (
        f"Task title: {body.title}\n"
        f"Brief: {body.brief}\n"
        f"Audience: {body.audience or 'عمومی'}\n"
        f"Tone: {body.tone or 'neutral'}\n"
        f"Language: {body.language}\n"
        f"Target word count: {body.word_count or 'flexible'}\n"
        f"{outline_text}"
        "Write a comprehensive long-form article with introduction, body sections with headings, "
        "actionable insights, and a conclusion. Use persuasive storytelling when relevant and keep formatting in Markdown."
        f"{research_context}"
    )
    messages = [
        {
            "role": "system",
            "content": (
                "You are an autonomous senior content agent. "
                "Always follow instructions precisely and deliver polished Markdown articles."
            ),
        },
        {"role": "user", "content": user_prompt},
    ]
    return await _fallback_completion(messages, temperature=0.45)
async def _reset_stale_agent_tasks() -> None:
    """
    When the server restarts, any tasks stuck in 'processing' are re-queued.
    """
    async with async_session() as session:
        stmt = select(AgentTask).where(AgentTask.status.in_(["processing"]))
        result = await session.execute(stmt)
        tasks = result.scalars().all()
        if not tasks:
            return
        now = datetime.utcnow()
        for task in tasks:
            task.status = "queued"
            task.updated_at = now
        await session.commit()
async def _claim_next_agent_task() -> Optional[AgentTask]:
    """
    Fetch the next queued task and mark it as processing.
    """
    async with async_session() as session:
        stmt = (
            select(AgentTask)
            .where(AgentTask.status.in_(["created", "queued", "pending", "retry"]))
            .order_by(AgentTask.created_at.asc())
            .limit(1)
        )
        result = await session.execute(stmt)
        task = result.scalar_one_or_none()
        if task is None:
            return None
        task.status = "processing"
        task.updated_at = datetime.utcnow()
        await session.commit()
        await session.refresh(task)
        session.expunge(task)  # detach for safe use outside session
        return task
async def _mark_task_failed(task_id: int, message: str) -> None:
    async with async_session() as session:
        db_task = await session.get(AgentTask, task_id)
        if db_task:
            db_task.status = "failed"
            db_task.last_error = message[:500]
            db_task.updated_at = datetime.utcnow()
            await session.commit()
async def _process_agent_task(task: AgentTask) -> None:
    """
    Run the heavy generation work for a single task and persist the result.
    """
    body = AgentTaskCreate(
        title=task.title,
        brief=task.brief,
        audience=task.audience,
        tone=task.tone,
        language=task.language,
        outline=_text_to_outline(task.outline),
        word_count=task.word_count,
        include_research=True,
    )
    try:
        article = await _generate_agent_article(body)
    except Exception as exc:  # noqa: BLE001
        await _mark_task_failed(task.id, str(exc))
        await _send_push_notification(task.user_id, "Agent task failed", f"{task.title}: {exc}")
        raise
    async with async_session() as session:
        db_task = await session.get(AgentTask, task.id)
        if db_task:
            db_task.result_text = article
            db_task.status = "completed"
            db_task.updated_at = datetime.utcnow()
            db_task.last_error = None
            await session.commit()
    await _send_push_notification(task.user_id, "Agent task completed", f"تسک '{task.title}' آماده است.")
async def _agent_task_worker() -> None:
    log.info("Agent scheduler worker started.")
    try:
        while not AGENT_SCHEDULER_STOP.is_set():
            task = await _claim_next_agent_task()
            if task is None:
                try:
                    await asyncio.wait_for(AGENT_SCHEDULER_STOP.wait(), timeout=AGENT_TASK_POLL_INTERVAL)
                    break
                except asyncio.TimeoutError:
                    continue
            try:
                await _process_agent_task(task)
            except Exception as exc:  # noqa: BLE001
                log.exception("Agent task %s failed: %s", task.id, exc)
            await asyncio.sleep(0)  # yield control
    finally:
        log.info("Agent scheduler worker stopped.")
async def _run_deep_research(body: DeepResearchRequest) -> Tuple[str, Optional[List[Dict[str, Any]]]]:
    research_prompt = None
    google_sources: Optional[List[Dict[str, Any]]] = None
    languages = body.languages or [body.language, "en"]
    # پاکسازی و یکتا کردن لیست زبان‌ها
    languages = [lang for idx, lang in enumerate(languages) if lang and lang not in languages[:idx]]
    if body.include_sources:
        research_prompt, google_sources = await _google_search_summary(
            body.query,
            fetch_pages=True,
            max_pages=5 if body.depth == "comprehensive" else 3,
            languages=languages,
            max_sources=body.max_sources,
        )
    context_block = ""
    if research_prompt:
        context_block = f"\n\n### Curated context\n{research_prompt}"
    user_prompt = (
        f"Target query: {body.query}\n"
        f"Audience: {body.audience or 'عمومی'}\n"
        f"Depth level: {body.depth}\n"
        f"Language: {body.language}\n"
        f"Search languages: {', '.join(languages)}\n"
        f"Max sources: {body.max_sources}\n"
        f"Need outline: {'yes' if body.include_outline else 'no'}\n"
        "Deliver JSON with keys summary (string), sections (array of {title, summary, takeaways[], sources[]}), "
        "outline (array) and sources (array). Each takeaway must be concise and actionable."
        f"{context_block}"
    )
    messages = [
        {
            "role": "system",
            "content": (
                "You are a meticulous research analyst. "
                "Ground every claim in reputable sources and respond only with valid JSON."
            ),
        },
        {"role": "user", "content": user_prompt},
    ]
    raw_text = await _fallback_completion(messages, temperature=0.35)
    return raw_text, google_sources
async def _suggest_search_queries(
    prompt_text: str,
    language: str = "fa",
    max_queries: int = 3,
) -> List[str]:
    system = (
        "You generate focused web search queries. "
        "Return JSON like {\"queries\": [\"...\"]} sorted by priority. "
        "Avoid overly broad keywords; include key entities or intent."
    )
    user = (
        f"User request (language: {language}):\n{prompt_text}\n"
        f"Return up to {max_queries} queries optimized for the latest public web search."
    )
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    try:
        raw = await _fallback_completion(messages, temperature=0.2)
    except Exception:
        return []
    parsed = _try_json_loads(raw)
    if isinstance(parsed, dict):
        items = parsed.get("queries")
        if isinstance(items, list):
            cleaned = []
            for item in items:
                if not item:
                    continue
                cleaned.append(str(item).strip())
                if len(cleaned) >= max_queries:
                    break
            if cleaned:
                return cleaned
    return [prompt_text.strip()[:120]]
def _resolve_provider(provider_name: Optional[str]):
    if not provider_name:
        return None
    return getattr(Provider, provider_name, provider_name)
def _provider_requirements(provider_name: Optional[str]) -> Tuple[bool, Optional[str], Dict[str, Any]]:
    extras: Dict[str, Any] = {}
    if provider_name == "PuterJS":
        if not PUTER_API_KEY:
            return False, "missing Puter.js API key", extras
        extras["api_key"] = PUTER_API_KEY
    elif provider_name == "OpenaiChat":
        if not OPENAI_COOKIE_READY:
            return False, f"missing HAR/cookie files under {HAR_COOKIE_DIR}", extras
    return True, None, extras
def _ensure_provider_available(provider_name: Optional[str]) -> Tuple[Optional[Any], Dict[str, Any]]:
    """
    Ensure a provider has the prerequisites configured and return both the resolved provider reference
    and any extra kwargs it requires.
    """
    can_use, reason, extras = _provider_requirements(provider_name)
    if not can_use:
        detail = reason or f"provider '{provider_name}' is not available"
        raise HTTPException(status_code=503, detail=detail)
    return _resolve_provider(provider_name), extras
def _parse_model_list(model_value: Optional[str]) -> List[str]:
    if not model_value:
        return []
    models = [item.strip() for item in model_value.split(",") if item.strip()]
    return models
async def _google_search_summary(
    query: str,
    fetch_pages: bool = False,
    max_pages: int = 3,
    languages: Optional[List[str]] = None,
    max_sources: int = 6,
) -> Tuple[Optional[str], Optional[List[Dict[str, Any]]]]:
    """
    Execute a Google-only search and return (prompt, sources) pair suitable for
    augmenting the final user message. Returns (None, None) if search fails or
    the Google backend is unavailable.
    """
    if not query or not query.strip():
        return None, None
    def _calc_queries_per_lang(langs: List[str], total: int) -> int:
        if not langs:
            return total
        return max(2, (total + len(langs) - 1) // len(langs))
    langs = languages or [None]
    queries: List[str] = []
    per_lang = _calc_queries_per_lang([l for l in langs if l], max_sources)
    for lang in langs:
        lang_code = lang or "fa"
        generated = await _suggest_search_queries(query, language=lang_code, max_queries=per_lang)
        for item in generated:
            if item not in queries:
                queries.append(item)
            if len(queries) >= max_sources:
                break
        if len(queries) >= max_sources:
            break
    if not queries:
        queries = [query.strip()[:120]]
    sections: List[str] = []
    sources: List[Dict[str, Any]] = []
    seen_urls: set[str] = set()
    source_counter = 0
    for query_idx, q in enumerate(queries):
        urls = await _google_search_urls(q, max_results=max_pages)
        if not urls:
            fallback_urls = [item.get("url") for item in await _scrape_google_results(q, max_pages) if item.get("url")]
            urls = fallback_urls
        for url in urls:
            if not url or url in seen_urls:
                continue
            seen_urls.add(url)
            page_details = await _fetch_page_details(url)
            if not page_details:
                continue
            snippet = page_details["text"]
            title = page_details["title"]
            section = (
                f"### Query: {q}\n"
                f"**Source [{source_counter}]** [{title}]({url})\n\n"
                f"{snippet}"
            )
            sections.append(section)
            sources.append({
                "index": source_counter,
                "title": title,
                "url": url,
                "query": q,
                "text": snippet,
            })
            source_counter += 1
            if fetch_pages and source_counter >= max_sources:
                break
    # If Google paths failed (e.g., captcha/sorry pages), try DuckDuckGo HTML fallback.
    if not sections:
        for q in queries:
            ddg_results = await _scrape_duckduckgo_results(q, max_results=max_pages)
            for item in ddg_results:
                url = item.get("url")
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)
                snippet = item.get("text") or ""
                title = item.get("title") or url
                section = (
                    f"### Query: {q}\n"
                    f"**Source [{source_counter}]** [{title}]({url})\n\n"
                    f"{snippet}"
                )
                sections.append(section)
                sources.append({
                    "index": source_counter,
                    "title": title,
                    "url": url,
                    "query": q,
                    "text": snippet,
                })
                source_counter += 1
                if fetch_pages and source_counter >= max_sources:
                    break
            if fetch_pages and source_counter >= max_sources:
                break
    if not sections:
        return None, None
    assembled = "\n\n\n".join(sections)
    prompt = (
        f"{assembled}\n\n"
        "Instruction: Answer the user's question strictly using the sources above. "
        "Cite them using [[index]](url) format."
        f"\n\nUser request:\n{query}"
    )
    return prompt, sources
async def _prepare_messages_with_search(
    messages: List[Message],
    use_web_search: bool,
) -> Tuple[List[Message], Optional[List[Dict[str, Any]]], bool]:
    """
    Optionally augment the latest user message with Google search context.
    Returns a tuple of:
    - messages to send to the provider,
    - collected sources (if any),
    - whether provider-native web_search should still be enabled as a fallback.
    """
    if not use_web_search:
        return messages, None, False
    last_user_index = next(
        (idx for idx in range(len(messages) - 1, -1, -1) if messages[idx].role == "user"),
        None,
    )
    if last_user_index is None:
        return messages, None, False
    search_prompt, sources = await _google_search_summary(messages[last_user_index].content, fetch_pages=True, max_pages=3)
    if not search_prompt:
        return messages, None, True
    augmented_messages = _clone_messages(messages)
    augmented_messages[last_user_index] = Message(role="user", content=search_prompt)
    return augmented_messages, sources, False
def _sse_event(event: str, data: str) -> bytes:
    """سریال‌سازی استاندارد SSE."""
    return f"event: {event}\ndata: {data}\n\n".encode("utf-8")
@app.get("/images/{image_path:path}")
async def proxy_local_image(image_path: str):
    """
    Proxy image requests to the local generator service so nginx points to FastAPI.
    """
    base = _local_images_base_url()
    upstream_url = f"{base}/images/{image_path.lstrip('/')}"
    timeout = httpx.Timeout(LOCAL_IMAGE_TIMEOUT, read=LOCAL_IMAGE_TIMEOUT, connect=10.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(upstream_url)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Failed to fetch image from local service: {exc}") from exc
    if resp.status_code >= 400:
        raise HTTPException(status_code=resp.status_code, detail=f"Local image fetch returned {resp.status_code}")
    content_type = resp.headers.get("content-type") or "image/png"
    return Response(content=resp.content, media_type=content_type)
def _normalize_phone(phone: str) -> str:
    cleaned = phone.strip().replace(" ", "")
    if not cleaned.startswith("+"):
        if cleaned.startswith("00"):
            cleaned = "+" + cleaned[2:]
        elif cleaned.startswith("0"):
            cleaned = "+98" + cleaned[1:]
        else:
            cleaned = "+" + cleaned
    return cleaned
def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()
def _generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"
def _ensure_auth_secret() -> None:
    if not AUTH_SECRET or AUTH_SECRET == "change-me":
        raise HTTPException(status_code=500, detail="AUTH_SECRET تنظیم نشده است.")
def _ensure_ippanel_config() -> None:
    missing = []
    if not IPPANEL_API_TOKEN:
        missing.append("IPPANEL_API_TOKEN")
    if not IPPANEL_FROM_NUMBER:
        missing.append("IPPANEL_FROM_NUMBER")
    if not IPPANEL_PATTERN_CODE:
        missing.append("IPPANEL_PATTERN_CODE")
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"تنظیمات IPPanel ناقص است: {', '.join(missing)}",
        )
async def _send_otp_sms(phone: str, code: str) -> None:
    _ensure_ippanel_config()
    url = f"{IPPANEL_BASE_URL.rstrip('/')}/api/send"
    payload = {
        "sending_type": "pattern",
        "from_number": IPPANEL_FROM_NUMBER,
        "code": IPPANEL_PATTERN_CODE,
        "recipients": [phone],
        "params": {"otp": code},
    }
    headers = {
        "Authorization": IPPANEL_API_TOKEN,
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(url, json=payload, headers=headers)
        if resp.status_code >= 400:
            raise HTTPException(
                status_code=502,
                detail=f"ارسال OTP با خطا مواجه شد: {resp.text}",
            )
def _issue_jwt(user_id: int, phone: str) -> str:
    _ensure_auth_secret()
    expire = datetime.utcnow() + timedelta(seconds=AUTH_TOKEN_EXPIRES)
    payload = {
        "sub": str(user_id),
        "phone": phone,
        "type": "access",
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, AUTH_SECRET, algorithm="HS256")
def _issue_otp_token(otp_id: int, phone: str) -> str:
    _ensure_auth_secret()
    expire = datetime.utcnow() + timedelta(seconds=OTP_EXPIRES_SECONDS)
    payload = {
        "otp_id": otp_id,
        "phone": phone,
        "type": "otp",
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, AUTH_SECRET, algorithm="HS256")
async def _register_device_token(
    user_id: int, token: Optional[str], platform: Optional[str], session: Optional[AsyncSession] = None
) -> None:
    if not token:
        return
    cleaned = token.strip()
    if not cleaned:
        return
    now = datetime.utcnow()
    async def _upsert(target_session: AsyncSession) -> None:
        if engine.sync_engine.dialect.name == "mysql":
            stmt = mysql_insert(DeviceToken).values(
                user_id=user_id,
                device_token=cleaned,
                platform=platform,
                created_at=now,
                last_seen=now,
            )
            on_duplicate = stmt.on_duplicate_key_update(
                user_id=user_id,
                platform=platform if platform is not None else DeviceToken.platform,
                last_seen=now,
            )
            await target_session.execute(on_duplicate)
        else:
            db_stmt = select(DeviceToken).where(DeviceToken.device_token == cleaned)
            result = await target_session.execute(db_stmt)
            existing = result.scalar_one_or_none()
            if existing:
                existing.user_id = user_id
                existing.platform = platform or existing.platform
                existing.last_seen = now
            else:
                target_session.add(DeviceToken(
                    user_id=user_id,
                    device_token=cleaned,
                    platform=platform,
                    created_at=now,
                    last_seen=now,
                ))
    if session is not None:
        await _upsert(session)
        await session.flush()
        return
    for attempt in range(3):
        try:
            async with async_session() as session:
                await _upsert(session)
                await session.commit()
            break
        except OperationalError as exc:  # noqa: PERF203
            code = getattr(getattr(exc, "orig", None), "args", [None])[0]
            if code in (1205, 1213) and attempt < 2:
                await asyncio.sleep(0.2 * (attempt + 1))
                continue
            raise
def _decode_otp_token(token: str) -> Tuple[int, str]:
    try:
        payload = jwt.decode(token, AUTH_SECRET, algorithms=["HS256"])
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن OTP نامعتبر است.")
    if payload.get("type") != "otp":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن OTP معتبر نیست.")
    otp_id = payload.get("otp_id")
    phone = payload.get("phone")
    if otp_id is None or phone is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن OTP ناقص است.")
    return int(otp_id), str(phone)
async def _get_user_by_id(user_id: int) -> Optional[User]:
    async with async_session() as session:
        return await session.get(User, user_id)
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن ارسال نشده است.")
    token = credentials.credentials
    try:
        payload = jwt.decode(token, AUTH_SECRET, algorithms=["HS256"])
        if payload.get("type") != "access":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="نوع توکن مجاز نیست.")
        user_id = int(payload.get("sub"))
        phone = payload.get("phone")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن نامعتبر است.")
    user = await _get_user_by_id(user_id)
    if user is None or user.phone != phone:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="کاربر یافت نشد.")
    return user
def _extract_message_text(response: Any) -> Optional[str]:
    """استخراج متن پاسخ از حالت non-stream."""
    if response is None:
        return None
    choices = getattr(response, "choices", None) or []
    if not choices:
        return None
    primary = choices[0]
    message = getattr(primary, "message", None)
    content = None
    if isinstance(message, dict):
        content = message.get("content")
    elif message is not None:
        content = getattr(message, "content", None)
    if content is None:
        content = getattr(primary, "text", None)
    return _normalize_token_piece(content)
async def _execute_fallback_completion(
    messages: List[Dict[str, str]],
    temperature: float = 0.6,
    web_search: bool = False,
) -> Tuple[str, str, Optional[str]]:
    """
    Run the completion fallback chain and return (text, model, provider_label).
    When web_search=True the provider-native search capability is requested.
    """
    client = AsyncClient()
    last_error: Optional[str] = None
    for entry in FALLBACK_CHAIN:
        model, provider_label = _parse_entry(entry)
        resolved_provider = _resolve_provider(provider_label)
        can_use, skip_reason, provider_kwargs = _provider_requirements(provider_label)
        if not can_use:
            last_error = skip_reason
            continue
        kwargs: Dict[str, Any] = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
        }
        if resolved_provider:
            kwargs["provider"] = resolved_provider
        if web_search:
            kwargs["web_search"] = True
        if provider_kwargs:
            kwargs.update(provider_kwargs)
        try:
            response = await client.chat.completions.create(**kwargs)
        except Exception as exc:  # noqa: BLE001
            last_error = repr(exc)
            continue
        text = _extract_message_text(response)
        if text:
            return text, model, provider_label
    raise RuntimeError(f"all providers failed to return text: {last_error}")
async def _fallback_completion(
    messages: List[Dict[str, str]],
    temperature: float = 0.6,
) -> str:
    """
    اجرای completion غیرجریانی با همان زنجیره fallback.
    در صورت شکست همهٔ providerها خطا پرتاب می‌شود.
    """
    text, _, _ = await _execute_fallback_completion(messages, temperature=temperature)
    return text
def _try_json_loads(raw_text: str) -> Optional[Any]:
    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        # common case: model wraps JSON in markdown fences such as ```json ... ```
        fenced_match = re.search(r"```(?:json)?\\s*(.*?)```", raw_text, flags=re.DOTALL | re.IGNORECASE)
        if fenced_match:
            candidate = fenced_match.group(1).strip()
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass
        # fallback: try to extract the first JSON-looking substring
        brace_start = raw_text.find("{")
        brace_end = raw_text.rfind("}")
        if brace_start != -1 and brace_end != -1 and brace_end > brace_start:
            candidate = raw_text[brace_start : brace_end + 1]
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass
        bracket_start = raw_text.find("[")
        bracket_end = raw_text.rfind("]")
        if bracket_start != -1 and bracket_end != -1 and bracket_end > bracket_start:
            candidate = raw_text[bracket_start : bracket_end + 1]
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass
        return None
SMART_ACTIONS = [
    "reminder",
    "follow_up",
    "send_message",
    "call",
    "open_app",
    "open_link",
    "open_camera",
    "open_gallery",
    "calendar_event",
    "web_search",
    "note",
    "mode_switch",
    "notification_triage",
    "memory_upsert",
    "routine",
    "automation",
    "suggestion",
    "daily_briefing",
]
async def _run_structured_completion(system_prompt: str, user_prompt: str, temperature: float = 0.35) -> Tuple[Any, str]:
    """
    Helper to ask the LLM for strict JSON and parse it.
    Raises HTTPException if the model does not return valid JSON.
    """
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
    raw_text = await _fallback_completion(messages, temperature=temperature)
    parsed = _try_json_loads(raw_text)
    if parsed is None:
        raise HTTPException(status_code=502, detail="پاسخ مدل JSON معتبر نداد.")
    return parsed, raw_text

# ═══════════════════════════════════════════════════════════════════
# GOAL TRACKING HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════
async def _update_goal_progress_auto(user_id: int, goal_id: int) -> int:
    """Auto-update goal progress based on linked tasks and habits"""
    async with async_session() as session:
        goal = await session.get(UserGoal, goal_id)
        if not goal or not goal.auto_progress_enabled:
            return goal.progress_percentage if goal else 0
        
        # Get linked task completion percentage
        task_ids = goal.linked_task_ids or []
        habit_ids = goal.linked_habit_ids or []
        
        total_progress = 0
        weight_sum = 0
        
        if task_ids:
            stmt = select(UserTask).where(UserTask.task_id.in_(task_ids))
            result = await session.execute(stmt)
            tasks = result.scalars().all()
            
            completed_tasks = sum(1 for t in tasks if t.status == "completed")
            if tasks:
                task_progress = (completed_tasks / len(tasks)) * 100 * 0.6  # 60% weight
                total_progress += task_progress
                weight_sum += 0.6
        
        if habit_ids:
            stmt = select(Habit).where(Habit.habit_id.in_(habit_ids))
            result = await session.execute(stmt)
            habits = result.scalars().all()
            
            # Get recent habit logs
            today = datetime.utcnow().date()
            habit_progress = 0
            if habits:
                for habit in habits:
                    log_stmt = select(HabitLog).where(
                        HabitLog.habit_id == habit.id,
                        HabitLog.logged_date == today
                    )
                    log_result = await session.execute(log_stmt)
                    has_log = log_result.scalar_one_or_none() is not None
                    if has_log:
                        habit_progress += (1 / len(habits)) * 100 * 0.4  # 40% weight
                total_progress += habit_progress
                weight_sum += 0.4
        
        new_progress = int(total_progress / weight_sum) if weight_sum > 0 else goal.progress_percentage
        new_progress = min(100, max(0, new_progress))
        
        if new_progress != goal.progress_percentage:
            # Log the change
            log_entry = GoalProgressLog(
                goal_id=goal_id,
                user_id=user_id,
                old_progress=goal.progress_percentage,
                new_progress=new_progress,
                reason="auto_update"
            )
            session.add(log_entry)
            
            goal.progress_percentage = new_progress
            goal.last_auto_update = datetime.utcnow()
            await session.commit()
        
        return new_progress

async def _get_goal_progress_trend(goal_id: int) -> str:
    """Analyze goal progress trend"""
    async with async_session() as session:
        stmt = select(GoalProgressLog).where(
            GoalProgressLog.goal_id == goal_id
        ).order_by(GoalProgressLog.created_at.desc()).limit(5)
        
        result = await session.execute(stmt)
        logs = result.scalars().all()
        
        if not logs or len(logs) < 2:
            return "steady"
        
        # Check last 5 changes
        progresses = [log.new_progress for log in reversed(logs)]
        
        # Simple trend: compare recent vs older
        if progresses[-1] > progresses[0]:
            return "increasing"
        elif progresses[-1] < progresses[0]:
            return "decreasing"
        else:
            return "steady"

async def _is_goal_on_track(goal: UserGoal) -> bool:
    """Check if goal is on track to complete by deadline"""
    if not goal.deadline or goal.status == "completed":
        return True
    
    now = datetime.utcnow()
    total_days = (goal.deadline - goal.created_at).days
    elapsed_days = (now - goal.created_at).days
    
    if total_days <= 0:
        return False
    
    expected_progress = (elapsed_days / total_days) * 100
    return goal.progress_percentage >= expected_progress * 0.9  # 90% of expected

async def _generate_motivation_message(goal: UserGoal, progress_trend: str) -> str:
    """Generate AI motivation message for goal"""
    system_prompt = (
        "تو یک کوچ انگیزشی هستی. پیامی کوتاه (یک خط) برای انگیزش دادن درباره پیشرفت هدف بده. "
        "تن حرفه‌ای اما دوستانه باشد."
    )
    user_prompt = (
        f"هدف: {goal.title}\n"
        f"دسته: {goal.category}\n"
        f"پیشرفت: {goal.progress_percentage}%\n"
        f"روند: {progress_trend}\n"
        f"موعد نهایی: {goal.deadline.isoformat()}\n"
        "یک پیام انگیزشی کوتاه برای این کاربر بده."
    )
    
    try:
        message = await _fallback_completion(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7
        )
        return message.strip()[:200]
    except:
        return "خوب پیش می‌رود! ادامه بده! 💪"

async def _store_memories(user_id: int, facts: List[str], key: Optional[str] = None) -> int:
    cleaned = [item.strip() for item in facts if item and str(item).strip()]
    if not cleaned:
        return 0
    now = datetime.utcnow()
    async with async_session() as session:
        for fact in cleaned:
            entry = AIMemory(
                user_id=user_id,
                key=key,
                content=fact,
                created_at=now,
            )
            session.add(entry)
        await session.commit()
    return len(cleaned)
async def _search_memories(user_id: int, query: Optional[str], limit: int = 5) -> List[AIMemory]:
    async with async_session() as session:
        stmt = select(AIMemory).where(AIMemory.user_id == user_id)
        if query:
            pattern = f"%{query}%"
            stmt = stmt.where(or_(AIMemory.content.ilike(pattern), AIMemory.key.ilike(pattern)))
        stmt = stmt.order_by(AIMemory.created_at.desc()).limit(max(1, min(limit, 50)))
        result = await session.execute(stmt)
        return result.scalars().all()
async def _enhance_image_prompt(prompt: str, size: Optional[str] = None) -> str:
    """
    Upgrade a user image prompt for better visual outputs by first hitting a text model.
    Tries to produce a robust, diffusion-friendly English prompt that preserves all user details.
    Falls back to the original on failure.
    """
    base = prompt.strip()
    if not base:
        return prompt
    # به مدل می‌گوییم نسبت تصویر را هم توصیف کند (برای کمک به مدل‌های ضعیف)
    if size:
        size_hint = (
            f"Aspect ratio or framing should match approximately {size}. "
            "If the size suggests a portrait, describe it as vertical poster; "
            "if landscape, describe it as wide cinematic frame."
        )
    else:
        size_hint = "Use a natural aspect ratio that fits the scene."
    messages = [
        {
            "role": "system",
            "content": (
                "You are an expert prompt engineer for generic diffusion-style image models "
                "(e.g., Stable Diffusion, SDXL, weaker custom models). "
                "The user wants an image of a specific subject. "
                "Write ONE single, high-quality, precise English prompt, max 400 characters.\n\n"
                "HARD RULES:\n"
                "- Preserve and explicitly include ALL important user details: subjects, number of people, colors, clothes, objects, text on screen, mood, time of day, setting, style (realistic / anime / painting, etc.).\n"
                "- Prefer simple, concrete visual language; avoid metaphors and abstract phrases.\n"
                "- Mention composition (camera angle, distance, framing), lighting, and level of detail.\n"
                "- Optimize for weak models: be clear and literal, avoid long clauses, avoid contradictions.\n"
                "- Include generic quality boosters like: highly detailed, sharp focus, high resolution, 8k, ultra detailed.\n"
                "- Include a short negative tail like: no text, no watermark, no logo, no border, no frame, no artifacts.\n"
                "- Do NOT output explanations, notes, or quotes. Only the final prompt text."
            ),
        },
        {
            "role": "user",
            "content": (
                f"I want to generate an image with this description (in Persian){' and this size hint' if size else ''}:\n"
                f"\"{base}\"\n\n"
                "First, carefully infer all visual details mentioned in my text, then rewrite them as a clean English prompt for an image model. "
                f"{size_hint}\n"
                "Only answer with the final English prompt text, nothing else."
            ),
        },
    ]
    enhanced = await _fallback_completion(messages, temperature=0.25)
    cleaned = (enhanced or "").strip().strip('"').strip("'")
    # اگر مدل چیزی عجیب/خالی داد، به پرامپت اصلی برمی‌گردیم
    return cleaned or prompt
async def _enhance_image_prompt_with_timeout(prompt: str, size: Optional[str] = None) -> str:
    """
    Wrapper to bound prompt enhancement time to avoid upstream 504s if providers hang.
    """
    try:
        return await asyncio.wait_for(_enhance_image_prompt(prompt, size), timeout=IMAGE_ENHANCE_TIMEOUT)
    except asyncio.TimeoutError:
        log.warning("Prompt enhancement timed out after %.1fs; using original prompt", IMAGE_ENHANCE_TIMEOUT)
        return prompt
    except Exception as exc:  # noqa: BLE001
        log.warning("Prompt enhancement failed; using original prompt: %s", exc)
        return prompt
def _local_images_base_url() -> str:
    """Return base URL (scheme + host) for the local image service."""
    parsed = urlparse(LOCAL_IMAGE_GENERATE_URL)
    return f"{parsed.scheme}://{parsed.netloc}".rstrip("/")
async def _stream_attempt(
    client: AsyncClient,
    model: str,
    provider: Optional[Any],
    provider_label: Optional[str],
    messages: List[Message],
    request: Request,
    web_search: bool = False,
    sources: Optional[List[Dict[str, Any]]] = None,
    provider_kwargs: Optional[Dict[str, Any]] = None,
    image_payload: Optional[Tuple[bytes, str]] = None,
) -> AsyncGenerator[bytes, None]:
    """Stream a single provider attempt using the AsyncClient interface."""
    stream_client = client or AsyncClient()
    start = time.time()
    request_messages = [m.dict() for m in messages]
    kwargs = {"model": model, "messages": request_messages}
    if provider:
        kwargs["provider"] = provider
    if web_search:
        kwargs["web_search"] = True
    if provider_kwargs:
        kwargs.update(provider_kwargs)
    if image_payload:
        kwargs["image"] = image_payload[0]
        kwargs["image_name"] = image_payload[1]
    # ارسال typing indicator
    yield _sse_event("typing", json.dumps({
        "status": "thinking",
        "message": "در حال پردازش..."
    }))
    
    if web_search:
        yield _sse_event("typing", json.dumps({
            "status": "searching",
            "message": "در حال جستجوی منابع..."
        }))
    # تلاش برای ساخت stream با timeout - stream_client.chat.completions.stream() می‌تواند blocking باشد
    stream = None
    try:
        # اگر stream_client.chat.completions.stream sync است، از loop executor استفاده کنیم
        loop = asyncio.get_event_loop()
        stream = await asyncio.wait_for(
            loop.run_in_executor(None, lambda: stream_client.chat.completions.stream(**kwargs)),
            timeout=STREAM_INIT_TIMEOUT
        )
    except asyncio.TimeoutError:
        log.error("Stream initialization timed out after %s seconds", STREAM_INIT_TIMEOUT)
        yield _sse_event("error", json.dumps({
            "message": "stream initialization timeout",
            "detail": f"سرور برای شروع stream بیش از {STREAM_INIT_TIMEOUT} ثانیه زمان لازم داشت"
        }))
        yield _sse_event("done", json.dumps({"reason": "init_timeout"}))
        return
    except Exception as init_err:
        log.error("Failed to initialize stream: %s", init_err)
        yield _sse_event("error", json.dumps({
            "message": "stream initialization failed",
            "detail": str(init_err)[:200]
        }))
        yield _sse_event("done", json.dumps({"reason": "init_error"}))
        return
    if stream is None:
        log.error("Stream object is None after initialization")
        yield _sse_event("error", json.dumps({
            "message": "stream object is None",
            "detail": "stream initialization returned None"
        }))
        yield _sse_event("done", json.dumps({"reason": "init_none"}))
        return
    try:
        agen = stream.__aiter__()
    except Exception as iter_err:
        log.error("Failed to get stream iterator: %s", iter_err)
        yield _sse_event("error", json.dumps({
            "message": "stream iterator initialization failed",
            "detail": str(iter_err)[:200]
        }))
        yield _sse_event("done", json.dumps({"reason": "iter_error"}))
        return
    last_ping = start
    collected_chunks: List[str] = []
    try:
        # ارسال typing indicator برای generating
        yield _sse_event("typing", json.dumps({
            "status": "generating",
            "message": "در حال تولید پاسخ..."
        }))
        
        while True:
            try:
                chunk = await asyncio.wait_for(agen.__anext__(), timeout=PER_ATTEMPT_TIMEOUT)
            except StopAsyncIteration:
                break
            if await request.is_disconnected():
                log.info("Client disconnected; aborting stream.")
                return
            text_piece = _normalize_token_piece(_extract_text_piece(chunk))
            if text_piece:
                collected_chunks.append(text_piece)
                yield _sse_event("token", json.dumps({"text": text_piece}))
            now = time.time()
            if now - last_ping >= STREAM_PING_EVERY:
                last_ping = now
                yield _sse_event("ping", json.dumps({"t": int(now)}))
    except asyncio.TimeoutError:
        raise
    finally:
        close_callable = getattr(stream, "aclose", None) or getattr(agen, "aclose", None)
        if callable(close_callable):
            try:
                await close_callable()  # type: ignore[misc]
            except Exception:
                pass
    latency_ms = int((time.time() - start) * 1000)
    done_payload = {
        "latency_ms": latency_ms,
        "model": model,
        "provider": provider_label,
        "text": "".join(collected_chunks),
    }
    if sources:
        done_payload["sources"] = sources
    
    # اضافه کردن suggested followups
    if collected_chunks:
        done_payload["suggested_followups"] = [
            "آیا می‌خواهید بیشتر بدانید؟",
            "سوال دیگری دارید؟",
        ]
    
    yield _sse_event("done", json.dumps(done_payload))
async def _fallback_stream(
    messages: List[Message],
    request: Request,
    web_search: bool = False,
    sources: Optional[List[Dict[str, Any]]] = None,
    image_payload: Optional[Tuple[bytes, str]] = None,
) -> AsyncGenerator[bytes, None]:
    client = AsyncClient()
    last_error: Optional[str] = None

    for idx, entry in enumerate(FALLBACK_CHAIN, start=1):
        model, provider = _parse_entry(entry)
        resolved_provider = _resolve_provider(provider)
        can_use, skip_reason, provider_kwargs = _provider_requirements(provider)

        yield _sse_event(
            "meta",
            json.dumps({"attempt": idx, "model": model, "provider": provider}),
        )

        if not can_use:
            last_error = skip_reason
            yield _sse_event(
                "warn",
                json.dumps(
                    {
                        "attempt": idx,
                        "error": "skipped",
                        "detail": skip_reason,
                        "model": model,
                        "provider": provider,
                    }
                ),
            )
            continue

        if await request.is_disconnected():
            log.info("Client disconnected; aborting stream.")
            return

        try:
            agen = _stream_attempt(
                client,
                model,
                resolved_provider,
                provider,
                messages,
                request,
                web_search,
                sources,
                provider_kwargs,
                image_payload,
            )

            async for ev in agen:
                yield ev

            # اگر استریم provider بدون خطا تموم شد، دیگه سراغ بعدی نرو
            return

        except Exception as e:
            last_error = repr(e)
            log.exception("Attempt %d failed for %s@%s: %s", idx, model, provider, e)
            yield _sse_event(
                "warn",
                json.dumps(
                    {
                        "attempt": idx,
                        "error": "exception",
                        "detail": str(e)[:200],
                        "model": model,
                        "provider": provider,
                    }
                ),
            )
            await asyncio.sleep(min(2.0, 0.25 * idx))

    error_payload = {"message": "all providers failed", "last_error": last_error}
    yield _sse_event("error", json.dumps(error_payload))
    yield _sse_event("done", json.dumps({"reason": "failed_fallback"}))

@app.post("/tools/web-search", response_model=MCPWebSearchResponse)
async def tool_web_search(body: MCPWebSearchRequest, current_user: User = Depends(get_current_user)) -> MCPWebSearchResponse:
    query = body.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="عبارت جست‌وجو خالی است.")
    search_prompt, sources = await _google_search_summary(query, fetch_pages=True, max_pages=max(1, body.max_sources))
    # اگر هیچ منبعی یافت نشد، با web_search بومی مدل تلاش می‌کنیم تا کاربر 404 نبیند.
    if not sources:
        messages = [
            {
                "role": "system",
                "content": (
                    "You are a factual web research assistant. Use live web search if available and answer concisely in Persian. "
                    "Cite sources when possible."
                ),
            },
            {"role": "user", "content": query},
        ]
        answer, model, provider = await _execute_fallback_completion(
            messages,
            temperature=max(0.0, min(body.temperature, 1.0)),
            web_search=True,
        )
        return MCPWebSearchResponse(
            query=query,
            answer=answer,
            model=model,
            provider=provider,
            sources=None,
        )
    use_count = max(1, min(len(sources), body.max_sources))
    selected_sources = sources[:use_count]
    sources_block_parts: List[str] = []
    for src in selected_sources:
        text = (src.get("text") or "")[:1000]
        sources_block_parts.append(f"[{src['index']}] {src.get('title') or ''} ({src.get('url')})\\n{text}")
    sources_block = "\\n\\n".join(sources_block_parts)
    messages = [
        {
            "role": "system",
            "content": (
                "You are a factual web research assistant. Answer ONLY using the provided sources and cite each claim with [[index]](url). "
                "If the sources lack the needed information, explicitly say so."
            ),
        },
        {
            "role": "user",
            "content": (
                f"User query (Persian): {query}\\n\\n"
                f"Sources:\\n{sources_block}\\n\\n"
                "Provide a concise Persian answer with citations."
            ),
        },
    ]
    answer, model, provider = await _execute_fallback_completion(
        messages,
        temperature=max(0.0, min(body.temperature, 1.0)),
        web_search=False,
    )
    if sources and "[[" not in answer:
        citations = " ".join(f"[[{src['index']}]]({src['url']})" for src in sources[:3])
        answer = f"{answer}\n\nمنابع: {citations}"
    return MCPWebSearchResponse(
        query=query,
        answer=answer,
        model=model,
        provider=provider,
        sources=sources,
    )
@app.post("/tools/web-scrape", response_model=MCPWebScrapeResponse)
async def tool_web_scrape(
    body: MCPWebScrapeRequest,
    current_user: User = Depends(get_current_user)
) -> MCPWebScrapeResponse:
    url = body.url.strip()
    if not url:
        raise HTTPException(status_code=400, detail="عبارت جست‌وجو خالی است.")
    details = await _fetch_page_details(url, limit=max(500, body.limit))
    if not details:
        raise HTTPException(status_code=404, detail="امکان دریافت محتوای صفحه وجود ندارد.")
    summary: Optional[str] = None
    model_name: Optional[str] = None
    provider_name: Optional[str] = None
    summary_prompt: Optional[str] = None
    if body.summarize:
        # حداکثر طول خلاصه بر اساس limit
        target_length = body.limit
        # دستور پایه برای خلاصه‌سازی
        base_instruction = (
            "تو یک خلاصه‌کنندهٔ دقیق محتوا هستی.\n"
            f"متن زیر نتیجهٔ یک وب‌اسکرپ است. آن را در حداکثر حدود {target_length} کاراکتر "
            "خلاصه کن، سرفصل‌های مهم را فهرست کن و اگر تاریخ/منبعی وجود دارد ذکر کن.\n"
        )
        # اگر کاربر summary_prompt داده، آن را به عنوان توضیح اضافی اضافه کن
        if body.summary_prompt:
            summary_prompt = (
                base_instruction
                + "\nدستور کاربر:\n"
                + body.summary_prompt.strip()
                + "\n\nمتن برای خلاصه‌سازی:\n"
                + details["text"]
            )
        else:
            summary_prompt = (
                base_instruction
                + "\nمتن برای خلاصه‌سازی:\n"
                + details["text"]
            )
        messages = [
            {
                "role": "user",
                "content": summary_prompt,
            }
        ]
        summary, model_name, provider_name = await _execute_fallback_completion(
            messages,
            temperature=0.2,
        )
        # اگر مدل نفهمید / پرامپت را تکرار کرد / گفت لطفا متن بفرست
        if (
            not summary
            or summary.strip() == ""
            or summary.strip().startswith("لطفا متن")
            or summary.strip().startswith("لطفاً متن")
        ):
            # fallback: یک خلاصهٔ خیلی کوتاه از خود متن
            summary = details["text"][:target_length]
        # اگر خلاصه خیلی طولانی شد، در حد target_length کوتاهش کن
        if len(summary) > target_length:
            summary = summary[:target_length]
    return MCPWebScrapeResponse(
        url=url,
        title=details["title"],
        text=details["text"],
        summary=summary,
        summary_prompt_used=summary_prompt if body.summarize else None,
        model=model_name,
        provider=provider_name,
    )
async def _get_daily_image_usage(user_id: int) -> int:
    today = datetime.utcnow().date()
    async with async_session() as session:
        result = await session.execute(
            select(ImageUsage).where(ImageUsage.user_id == user_id, ImageUsage.date == today)
        )
        record: Optional[ImageUsage] = result.scalar_one_or_none()
        return record.count if record else 0
async def _increment_daily_image_usage(user_id: int, delta: int = 1) -> int:
    today = datetime.utcnow().date()
    async with async_session() as session:
        result = await session.execute(
            select(ImageUsage).where(ImageUsage.user_id == user_id, ImageUsage.date == today)
        )
        record: Optional[ImageUsage] = result.scalar_one_or_none()
        if record:
            record.count += delta
        else:
            record = ImageUsage(user_id=user_id, date=today, count=delta)
            session.add(record)
        await session.commit()
        await session.refresh(record)
        return record.count
@app.post("/tools/image-generation", response_model=MCPImageGenerationResponse)
async def tool_image_generation(
    request: Request,
    body: MCPImageGenerationRequest,
    current_user: User = Depends(get_current_user),
) -> MCPImageGenerationResponse:
    """
    بهینه‌شده برای تولید سریع‌تر و بهتر تصاویر
    - Parallel processing
    - Smart caching
    - Timeout optimization
    """
    prompt = body.prompt.strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="پرامپت خالی است.")
    if body.n <= 0 or body.n > 10:
        raise HTTPException(status_code=400, detail="تعداد باید بین 1 تا 10 باشد.")
    # اضافه کردن quality hints برای بهتر شدن تصاویر
    quality_prompt = _enhance_prompt_with_quality(prompt, body.size)
    enhanced_prompt = await _enhance_image_prompt_with_timeout(quality_prompt, body.size)
    model_candidates = _parse_model_list(body.model) or _parse_model_list(IMAGE_TOOL_MODEL) or ["gpt-image-1"]
    provider_label = body.provider or (IMAGE_TOOL_PROVIDER or None)
    resolved_provider, provider_kwargs = _ensure_provider_available(provider_label)
    response_format = body.response_format or IMAGE_RESPONSE_FORMAT or "url"
    if response_format not in {"url", "b64_json"}:
        response_format = "url"
    images: List[MCPImageData] = []
    chosen_model: Optional[str] = None
    last_error: Optional[str] = None
    local_error: Optional[str] = None
    # ابتدا سرویس local را امتحان می‌کنیم (سریع‌تر است)
    try:
        images = await _generate_image_local_service(
            prompt=enhanced_prompt,
            response_format=response_format,
            request=request,
            size=body.size,
            n=body.n,
        )
    except HTTPException as exc:
        local_error = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
        log.warning("Local image generator HTTP error: %s", local_error)
    except Exception as exc:
        local_error = str(exc)
        log.warning("Local image generator failed: %s", exc)
    if images:
        return MCPImageGenerationResponse(
            model="local",
            provider=provider_label or "local",
            prompt=enhanced_prompt,
            original_prompt=prompt,
            images=images,
        )
    images = []
    # اگر local کار نکرد، به سراغ g4f با بهتری timeout می‌رویم
    for model_name in model_candidates:
        try:
            images = await _generate_image_g4f(
                prompt=enhanced_prompt,
                model_name=model_name,
                response_format=response_format,
                provider=resolved_provider,
                provider_kwargs=provider_kwargs,
                size=body.size,
                n=body.n,
            )
            if images:
                chosen_model = model_name
                break
        except HTTPException as exc:
            last_error = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
        except Exception as exc:
            last_error = str(exc)
    if not images:
        detail = last_error or local_error or "تولید تصویر موفق نبود. لطفاً دوباره امتحان کنید."
        raise HTTPException(status_code=502, detail=detail)
    return MCPImageGenerationResponse(
        model=chosen_model or model_candidates[0],
        provider=provider_label,
        prompt=enhanced_prompt,
        original_prompt=prompt,
        images=images,
    )
@app.post("/tools/image-enhancement")
async def tool_image_enhancement(
    request: Request,
    body: Dict[str, Any],
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    بهینه سازی و بهبود تصویر موجود
    """
    image_url = body.get("image_url")
    style = body.get("style", "enhance")  # enhance, cartoon, artistic, realistic
    
    if not image_url:
        raise HTTPException(status_code=400, detail="image_url الزامی است.")
    
    try:
        # تولید prompt برای بهبود
        enhancement_prompt = _generate_enhancement_prompt(style)
        
        # دانلود تصویر موجود
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(image_url)
        
        if resp.status_code >= 400:
            raise HTTPException(status_code=502, detail="خطا در دانلود تصویر.")
        
        return {
            "status": "processing",
            "message": "تصویر برای بهبود در حال پردازش است.",
            "style": style,
        }
    except Exception as exc:
        log.error(f"Image enhancement error: {exc}")
        raise HTTPException(status_code=502, detail="خطا در بهبود تصویر.")
@app.post("/app/check-version", response_model=AppVersionResponse)
async def check_app_version(body: AppVersionRequest) -> AppVersionResponse:
    print(body)
    needs_update = _compare_versions(body.version, APP_LATEST_VERSION) < 0
    print(needs_update)
    download_url = APP_DOWNLOAD_URL if needs_update else None
    return AppVersionResponse(
        update_required=needs_update,
        latest_version=APP_LATEST_VERSION,
        download_url=download_url,
    )
# ============================================================================
# Expert Domain System Prompts
# ============================================================================
EXPERT_SYSTEM_PROMPTS = {
    "psychology": """تو یک روانشناس بالینی و متخصص سلامت روان با سال‌ها تجربه هستی. 
تخصص تو در زمینه‌های زیر است:
- تشخیص و درمان اختلالات روانی (اضطراب، افسردگی، PTSD، OCD و...)
- رواندرمانی (CBT، DBT، روانکاوی و...)
- روانشناسی سلامت و مدیریت استرس
- روابط بین فردی و خانواده درمانی
- روانشناسی رشد و کودک
قوانین مهم:
1. همیشه بر اساس آخرین تحقیقات علمی و راهنمای‌های بالینی (DSM-5, ICD-11) پاسخ بده
2. اگر سوالی خارج از حوزه تخصصی توست، صادقانه بگو و به متخصص مناسب ارجاع بده
3. هرگز تشخیص قطعی نده - فقط راهنمایی و مشاوره ارائه بده
4. در موارد بحرانی (خودکشی، آسیب به خود یا دیگران) فوراً به مراکز اورژانس ارجاع بده
5. از زبان علمی اما قابل فهم استفاده کن
6. همیشه منابع علمی را ذکر کن
7. برای اطلاعات جدید از جستجوی وب استفاده کن
زبان پاسخ: فارسی، با اصطلاحات تخصصی فارسی و انگلیسی در صورت نیاز.""",
    "psychiatry": """تو یک روانپزشک بالینی و پژوهشگر سلامت روان هستی.
حوزه‌های تخصص:
- تشخیص و درمان اختلالات روانپزشکی (اضطراب، افسردگی، دوقطبی، سایکوز، PTSD، OCD)
- پایش دارویی، تداخلات و عوارض جانبی
- درمان ترکیبی دارو + روان‌درمانی شواهد-محور (CBT, DBT, ACT)
- مدیریت اورژانس‌های روانپزشکی و ریسک خودکشی/خودآسیبی
- پایش آزمایشگاهی مرتبط با داروها (CBC, LFT, TFT و...)
قوانین مهم:
1. صرفاً بر اساس گایدلاین‌های معتبر (APA, NICE, CANMAT و سایر منابع 2023-2025) پاسخ بده.
2. درباره داروها فقط توضیح عمومی و هشدار بده و تأکید کن نسخه باید توسط پزشک معالج تصمیم‌گیری شود.
3. در صورت عدم قطعیت، صریحاً بگو «اطمینان ندارم / نیاز به ارزیابی بالینی دارد».
4. ایمنی را اولویت بده؛ در صورت علائم حاد یا ریسک، توصیه مراجعه فوری به اورژانس/متخصص.
5. از کلی‌گویی پرهیز کن؛ پاسخ دقیق، کوتاه و ساختاریافته بده.
زبان پاسخ: فارسی تخصصی با ذکر اصطلاحات بالینی.""",
    "real_estate": """تو یک مشاور املاک حرفه‌ای و متخصص بازار مسکن با سال‌ها تجربه هستی.
تخصص تو در زمینه‌های زیر است:
- ارزش‌گذاری و قیمت‌گذاری املاک
- قوانین و مقررات خرید و فروش املاک
- سرمایه‌گذاری در املاک و مستغلات
- رهن و اجاره (قوانین، قراردادها، حقوق طرفین)
- مالیات و عوارض املاک
- بازسازی و بهینه‌سازی املاک
- بازار مسکن و روندهای قیمتی
قوانین مهم:
1. همیشه بر اساس آخرین قوانین و مقررات کشور (ایران) پاسخ بده
2. اطلاعات قیمتی را با ذکر منطقه و تاریخ به‌روزرسانی کن
3. برای اطلاعات دقیق‌تر به قوانین روز و سایت‌های رسمی ارجاع بده
4. در مورد قراردادها، همیشه به مشورت با وکیل تأکید کن
5. از جستجوی وب برای آخرین قیمت‌ها و قوانین استفاده کن
6. ریسک‌های سرمایه‌گذاری را شفاف بیان کن
زبان پاسخ: فارسی، با اصطلاحات تخصصی املاک.""",
    "mechanics": """تو یک مکانیک حرفه‌ای و متخصص تعمیرات خودرو با سال‌ها تجربه عملی هستی.
تخصص تو در زمینه‌های زیر است:
- تشخیص و تعمیر مشکلات موتور (بنزین، دیزل، هیبرید، برقی)
- سیستم‌های برقی و الکترونیک خودرو
- سیستم ترمز و فرمان
- سیستم تعلیق و کمک‌فنرها
- سیستم خنک‌کننده و روغن‌کاری
- گیربکس (دستی و اتوماتیک)
- سیستم تهویه و کولر
- نگهداری و سرویس دوره‌ای
قوانین مهم:
1. همیشه بر اساس آخرین تکنولوژی‌ها و استانداردهای صنعت خودرو پاسخ بده
2. برای هر مشکل، علت احتمالی، روش تشخیص و راه حل را توضیح بده
3. در مورد ایمنی و خطرات احتمالی هشدار بده
4. برای تعمیرات پیچیده، به تعمیرگاه معتبر ارجاع بده
5. از جستجوی وب برای آخرین اطلاعات فنی و راهنماهای تعمیر استفاده کن
6. کدهای خطا (OBD) را تفسیر کن
7. هزینه‌های تقریبی را با ذکر منطقه و تاریخ ذکر کن
زبان پاسخ: فارسی، با اصطلاحات فنی فارسی و انگلیسی.""",
    "talent_assessment": """تو یک مشاور استعداد یابی و توسعه شغلی حرفه‌ای با تخصص در روانشناسی شغلی هستی.
تخصص تو در زمینه‌های زیر است:
- ارزیابی استعدادها و توانمندی‌های فردی
- تست‌های شخصیت و شغلی (MBTI، DISC، Holland و...)
- راهنمایی انتخاب رشته و شغل
- برنامه‌ریزی مسیر شغلی (Career Planning)
- توسعه مهارت‌های نرم و سخت
- شناسایی نقاط قوت و ضعف
- انگیزش و هدف‌گذاری شغلی
قوانین مهم:
1. همیشه بر اساس آخرین نظریه‌های روانشناسی شغلی و تست‌های معتبر پاسخ بده
2. از تست‌های استاندارد و معتبر استفاده کن (نه تست‌های غیرعلمی)
3. هر فرد را منحصر به فرد در نظر بگیر و از کلی‌گویی پرهیز کن
4. برای ارزیابی دقیق‌تر، به مراکز مشاوره شغلی معتبر ارجاع بده
5. از جستجوی وب برای آخرین تحقیقات و ابزارهای ارزیابی استفاده کن
6. همیشه نقاط قوت را تقویت کن و راه‌های بهبود را پیشنهاد بده
7. در مورد تغییر شغل یا رشته، تمام جوانب را بررسی کن
زبان پاسخ: فارسی، با اصطلاحات تخصصی روانشناسی شغلی."""
}
def _get_expert_system_prompt(domain: Optional[str]) -> Optional[str]:
    """برمی‌گرداند system prompt برای domain تخصصی"""
    if not domain:
        return None
    return EXPERT_SYSTEM_PROMPTS.get(domain)
async def _run_chat_stream_core(
    req: Request,
    body: ChatRequest,
    current_user: User,
    incoming_messages: List[Message],
    image_payload: Optional[Tuple[bytes, str]],
) -> StreamingResponse:
    session_id = body.session_id

    # دیگر نیازی به file_urls بعد از ingest نداریم
    body.file_urls = None

    # build history + current messages
    combined_messages = await _combined_session_messages(session_id, incoming_messages)
    combined_messages = _apply_request_context_budget(combined_messages)

    # expert domain system prompt
    expert_prompt = _get_expert_system_prompt(body.expert_domain)
    if expert_prompt:
        combined_messages = _limit_messages_for_expert(combined_messages)
        combined_messages = [msg for msg in combined_messages if msg.role != "system"]

        guardrail = _expert_guardrail(body.expert_domain or "domain")
        combined_messages.insert(0, Message(role="system", content=guardrail))
        combined_messages.insert(0, Message(role="system", content=expert_prompt))

        # برای expert domains همیشه web_search فعال کن
        body.web_search = True

    messages_for_stream, search_sources, provider_web_search = await _prepare_messages_with_search(
        combined_messages,
        body.web_search,
    )

    async def event_gen():
        assistant_chunks: List[str] = []
        agen = _fallback_stream(
            messages_for_stream,
            req,
            provider_web_search,
            search_sources,
            image_payload,
        )

        stream_active = True

        # می‌توانی در شروع، یک meta کوچیک بفرستی که کلاینت بداند استریم شروع شده:
        # yield _sse_event("meta", json.dumps({"status": "stream_started"}))

        try:
            while stream_active:
                try:
                    # اگر برای 120 ثانیه هیچ event دریافت نشود، timeout کن
                    chunk = await asyncio.wait_for(
                        agen.__anext__(),
                        timeout=120.0,
                    )
                except asyncio.TimeoutError:
                    log.error("Stream event timeout - no data for 120 seconds")
                    yield _sse_event(
                        "error",
                        json.dumps(
                            {
                                "message": "stream timeout",
                                "detail": "سرور برای دریافت پاسخ بیش از حد زمان لازم داشت",
                            }
                        ),
                    )
                    yield _sse_event("done", json.dumps({"reason": "stream_timeout"}))
                    stream_active = False
                    break
                except StopAsyncIteration:
                    # استریم از سمت fallback به شکل طبیعی تمام شد
                    break

                # سعی کن text رو از chunk برای ذخیره‌ی تاریخچه جمع کنی
                try:
                    decoded = chunk.decode("utf-8", errors="ignore")
                    for line in decoded.split("\n"):
                        if not line.startswith("data:"):
                            continue
                        payload_str = line.split("data:", 1)[1].strip()
                        if not payload_str:
                            continue
                        data = json.loads(payload_str)

                        # بسته به ساختار SSE خودت، این‌ها را تنظیم کن
                        if isinstance(data, dict):
                            # اگر partial token داری (delta) یا متن کامل (text)
                            text_piece = data.get("delta") or data.get("text")
                            if isinstance(text_piece, str):
                                assistant_chunks.append(text_piece)
                except Exception:
                    # parse متن برای history نباید استریم را بشکند
                    pass

                # تشخیص event پایان
                if chunk.startswith(b"event: done"):
                    stream_active = False

                # chunk را به کلاینت پاس بده
                yield chunk

        except Exception as e:
            log.error("Error in event_gen: %s", e)
            yield _sse_event(
                "error",
                json.dumps(
                    {
                        "message": "internal error",
                        "detail": str(e)[:200],
                    }
                ),
            )
            yield _sse_event("done", json.dumps({"reason": "internal"}))
        finally:
            # سعی کن generator را ببندی
            try:
                await agen.aclose()
            except Exception:
                pass

            # متن نهایی assistant برای ذخیره‌ی session
            assistant_text: Optional[str] = None
            if assistant_chunks:
                assistant_text = "".join(assistant_chunks)

            try:
                await _store_session_messages(session_id, incoming_messages, assistant_text)
            except Exception as e:
                log.error("Failed to store session messages: %s", e)

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
@app.post("/chat/stream")
async def chat_stream(req: Request, body: ChatRequest, current_user: User = Depends(get_current_user)):
    session_id = body.session_id
    if body.reset and session_id:
        await _reset_session(session_id)
    incoming_messages = _clone_messages(body.messages)
    file_snippets: List[str] = []
    image_payload: Optional[Tuple[bytes, str]] = None
    if body.file_urls:
        for uri in body.file_urls:
            try:
                payload = await _ingest_file_uri(uri)
            except HTTPException:
                raise
            except Exception as exc:  # noqa: BLE001
                raise HTTPException(status_code=400, detail=f"خواندن فایل ناموفق بود: {exc}") from exc
            text_value = (payload.get("text") or "").strip()
            if text_value:
                if len(text_value) > MAX_FILE_TEXT_CHARS:
                    text_value = text_value[:MAX_FILE_TEXT_CHARS] + "\n... (truncated)"
                file_snippets.append(f"[File: {uri}]\n{text_value}")
            if payload.get("image") is not None and image_payload is None:
                image_payload = (payload["image"], payload.get("image_name") or "image")  # type: ignore[index, assignment]
    if file_snippets:
        incoming_messages.append(
            Message(
                role="user",
                content="محتوای فایل‌های ارسال‌شده:\n\n" + "\n\n".join(file_snippets),
            )
        )
    return await _run_chat_stream_core(req, body, current_user, incoming_messages, image_payload)
@app.post("/chat/stream/form")
async def chat_stream_form(
    req: Request,
    payload: str = Form(..., description="JSON string matching ChatRequest schema"),
    files: Optional[List[UploadFile]] = File(None),
    current_user: User = Depends(get_current_user),
):
    # payload را به ChatRequest تبدیل کن
    try:
        raw = json.loads(payload)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"payload باید JSON معتبر باشد: {exc}") from exc
    try:
        body = ChatRequest(**raw)
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=f"payload نامعتبر است: {exc.errors()}") from exc
    incoming_messages = _clone_messages(body.messages)
    file_snippets: List[str] = []
    image_payload: Optional[Tuple[bytes, str]] = None
    # فایل‌های URL
    if body.file_urls:
        for uri in body.file_urls:
            try:
                payload_file = await _ingest_file_uri(uri)
            except HTTPException:
                raise
            except Exception as exc:  # noqa: BLE001
                raise HTTPException(status_code=400, detail=f"خواندن فایل ناموفق بود: {exc}") from exc
            text_value = (payload_file.get("text") or "").strip()
            if text_value:
                if len(text_value) > MAX_FILE_TEXT_CHARS:
                    text_value = text_value[:MAX_FILE_TEXT_CHARS] + "\n... (truncated)"
                file_snippets.append(f"[File: {uri}]\n{text_value}")
            if payload_file.get("image") is not None and image_payload is None:
                image_payload = (
                    payload_file["image"],  # type: ignore[index]
                    payload_file.get("image_name") or "image",  # type: ignore[arg-type]
                )
    # فایل‌های آپلودی (multipart)
    if files:
        for upload in files:
            try:
                payload_upload = await _ingest_upload_file(upload)
            except HTTPException:
                raise
            except Exception as exc:  # noqa: BLE001
                raise HTTPException(status_code=400, detail=f"خواندن فایل '{upload.filename}' ناموفق بود: {exc}") from exc
            text_value = (payload_upload.get("text") or "").strip()
            if text_value:
                if len(text_value) > MAX_FILE_TEXT_CHARS:
                    text_value = text_value[:MAX_FILE_TEXT_CHARS] + "\n... (truncated)"
                file_snippets.append(f"[Uploaded: {upload.filename or 'file'}]\n{text_value}")
            if payload_upload.get("image") is not None and image_payload is None:
                image_payload = (
                    payload_upload["image"],  # type: ignore[index]
                    payload_upload.get("image_name") or (upload.filename or "image"),  # type: ignore[arg-type]
                )
    if file_snippets:
        incoming_messages.append(
            Message(
                role="user",
                content="محتوای فایل‌های ارسال‌شده:\n\n" + "\n\n".join(file_snippets),
            )
        )
    body.file_urls = None
    body.messages = incoming_messages
    return await _run_chat_stream_core(req, body, current_user, incoming_messages, image_payload)
def _ensure_idea_items(parsed: Any, fallback_text: str) -> List[Dict[str, Any]]:
    """
    تلاش برای استخراج لیست ایده‌ها از JSON.
    در صورت شکست، متن خام را هم به ایده تبدیل می‌کنیم تا خروجی خالی نباشد.
    """
    candidates: List[Dict[str, Any]] = []
    if isinstance(parsed, dict):
        for key in ("ideas", "niche_ideas", "items"):
            maybe_list = parsed.get(key)
            if isinstance(maybe_list, list):
                parsed = maybe_list
                break
    if isinstance(parsed, list):
        for item in parsed:
            if isinstance(item, dict):
                if item:
                    candidates.append(item)
            elif isinstance(item, str):
                candidates.append({"title": item})
    elif isinstance(parsed, dict):
        candidates.append(parsed)
    # اگر مدل JSON نداد، سعی کن بولت‌پوینت‌های متن خام را ایده‌مند کنی.
    if not candidates and fallback_text:
        lines = [
            re.sub(r"^[0-9]+\\s*[\\.\\-\\)]\\s*", "", line)
            .lstrip("•-–—")
            .strip()
            for line in fallback_text.splitlines()
        ]
        for line in lines:
            if not line:
                continue
            title, sep, rest = line.partition(":")
            if sep and rest.strip():
                candidates.append({"title": title.strip(), "description": rest.strip()})
            else:
                candidates.append({"title": line})
            if len(candidates) >= 5:
                break
    if not candidates:
        candidates.append({"title": "ایده نامشخص", "description": fallback_text.strip()})
    return candidates
def _ensure_calendar_entries(parsed: Any, fallback_text: str) -> List[ContentCalendarEntry]:
    items: List[ContentCalendarEntry] = []
    data = parsed
    if isinstance(data, dict):
        for key in ("entries", "schedule", "calendar"):
            maybe = data.get(key)
            if isinstance(maybe, list):
                data = maybe
                break
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                entry = ContentCalendarEntry(
                    day=str(item.get("day", "")) or str(item.get("date", "")) or "",
                    hook=item.get("hook", ""),
                    format=item.get("format", item.get("content_type", "")),
                    outline=item.get("outline", item.get("story", "")),
                    cta=item.get("cta", item.get("call_to_action", "")),
                    notes=item.get("notes"),
                )
                items.append(entry)
    if not items:
        items.append(ContentCalendarEntry(
            day="روز ۱",
            hook="هوک پیشنهادی از متن خام",
            format="mixed",
            outline=fallback_text.strip()[:280],
            cta="CTA پیشنهادی",
            notes="خروجی JSON پیدا نشد؛ متن خام استفاده شد.",
        ))
    return items
@app.post("/instagram/ideas", response_model=InstagramIdeaResponse)
async def create_instagram_ideas(body: InstagramIdeaRequest, current_user: User = Depends(get_current_user)):
    system_prompt = """
تو یک استراتژیست اینستاگرام هستی.
فقط و فقط یک JSON معتبر برگردان.
قوانین خیلی مهم:
- هیچ متن دیگری غیر از JSON ننویس (نه توضیح، نه سلام، نه توضیح اضافه).
- از هیچ بلوک کدی مثل ``` یا ```json استفاده نکن.
- خروجی باید دقیقا یک آبجکت JSON باشد که ساختارش این است:
{
    "ideas": [
    {
        "niche_name": "string",
        "angle": "string",
        "why_it_works": "string",
        "sample_content": "string",
        "monetization": "string"
    }
    ]
}
- همیشه همه‌ی کلیدها و مقدارها باید در دابل‌کوتیشن باشند.
- اگر ایده‌ای نداری، باز هم این ساختار را برگردان ولی با "ideas": [].
فقط همین JSON را چاپ کن و هیچ چیز دیگری ننویس.
"""
    user_prompt = (
        f"موضوع کلی پیج: {body.topic}\n"
        f"پرسونای مخاطب: {body.audience or 'نامشخص'}\n"
        f"اهداف کسب‌وکار یا KPI: {body.goals or 'نامشخص'}\n"
        f"زبان پاسخ: {body.language}\n"
        "لطفاً حداقل 5 ایدهٔ نیچ با تمرکز بر الگوریتم اینستاگرام و ترندهای روز بده."
    )
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
    try:
        raw_text = await _fallback_completion(messages, temperature=0.5)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    parsed = _try_json_loads(raw_text)
    ideas = _ensure_idea_items(parsed, raw_text)
    print(InstagramIdeaResponse(topic=body.topic, ideas=ideas, raw_text=raw_text))
    return InstagramIdeaResponse(topic=body.topic, ideas=ideas, raw_text=raw_text)
@app.post("/instagram/content-calendar", response_model=ContentCalendarResponse)
async def create_content_calendar(body: ContentCalendarRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک سازندهٔ تقویم محتوای اینستاگرام هستی. فقط JSON بده با ساختار "
        "{\"entries\": [{\"day\": str, \"hook\": str, \"format\": str, "
        "\"outline\": str, \"cta\": str, \"notes\": str}]}."
    )
    pillars_text = ", ".join(body.pillars) if body.pillars else "نامشخص"
    user_prompt = (
        f"ایدهٔ اصلی پیج: {body.idea}\n"
        f"مدت زمان (هفته): {body.duration_weeks}\n"
        f"تعداد پست در هفته: {body.posts_per_week}\n"
        f"ستون‌های محتوا: {pillars_text}\n"
        f"محتوای ویدئویی/ریل لازم است؟ {'بله' if body.include_reels else 'خیر'}\n"
        f"زبان پاسخ: {body.language}\n"
        "هر ورودی باید شامل هوک (Hook)، فرمت محتوا، ساختار (Outline)، CTA و نکتهٔ بهینه‌سازی الگوریتم باشد."
    )
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
    try:
        raw_text = await _fallback_completion(messages, temperature=0.55)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    parsed = _try_json_loads(raw_text)
    entries = _ensure_calendar_entries(parsed, raw_text)
    return ContentCalendarResponse(
        idea=body.idea,
        duration_weeks=body.duration_weeks,
        posts_per_week=body.posts_per_week,
        entries=entries,
        raw_text=raw_text,
    )
@app.post("/research/deep", response_model=DeepResearchResponse)
async def run_deep_research(body: DeepResearchRequest, current_user: User = Depends(get_current_user)):
    raw_text, google_sources = await _run_deep_research(body)
    parsed = _try_json_loads(raw_text)
    summary, sections, outline, ai_sources = _ensure_research_payload(parsed, raw_text)
    if not body.include_outline:
        outline = None
    merged_sources = _merge_sources(ai_sources, google_sources if body.include_sources else None)
    return DeepResearchResponse(
        query=body.query,
        depth=body.depth,
        summary=summary,
        sections=sections,
        outline=outline,
        sources=merged_sources,
        raw_text=raw_text,
    )
# ============================================================================
# Smart Assistant Endpoints (NLP reminders, phone actions, modes, notification intel)
# ============================================================================
def _to_json(obj: Any) -> str:
    try:
        return json.dumps(obj, ensure_ascii=False)
    except Exception:
        return str(obj)
def _intent_system_prompt() -> str:
    return (
        "تو یک Intent Router فارسی هستی که فقط JSON برمی‌گرداند. "
        "همیشه ساختار زیر را برگردان:\n"
        '{"action": "<one_of_allowed_actions>", "payload": {...}}\n'
        f"اقدام‌های مجاز: {', '.join(SMART_ACTIONS)}.\n"
        "- زمان را به صورت ISO 8601 با timezone اگر وجود دارد بده (مثلاً 2025-12-07T18:00:00+03:30).\n"
        "- اگر reminder است، کلیدهای title, datetime, details را پر کن.\n"
        "- اگر follow_up است، condition (no_reply/after_event), deadline, subject و task را بده.\n"
        "- اگر send_message یا call است، recipient و suggested_text یا note را بده و نوع کانال (sms/whatsapp/telegram) را پیشنهاد کن.\n"
        "- اگر calendar_event است، title, start, end, location را بده.\n"
        "- اگر web_search است، queries (لیست) را برگردان.\n"
        "- اگر mode_switch است، mode هدف و دلیلش را بده.\n"
        "- هیچ متن توضیحی، سلام، یا کد مارک‌داون ننویس. فقط JSON خالص.\n"
        "- اگر اطلاعات کافی نیست، action را 'suggestion' بگذار و سوال تکمیلی در payload.prompt بده."
    )
@app.post("/assistant/intent", response_model=SmartIntentResponse)
async def parse_smart_intent(body: SmartIntentRequest, current_user: User = Depends(get_current_user)):
    system_prompt = _intent_system_prompt()
    user_prompt = (
        f"متن کاربر: {body.text}\n"
        f"زمان فعلی (client): {body.now or 'نامشخص'}\n"
        f"تایم‌زون: {body.timezone or 'Asia/Tehran'}\n"
        f"مود فعلی: {body.mode or 'نامشخص'}\n"
        f"انرژی: {body.energy or 'نامشخص'}\n"
        f"کانتکست کمکی: {_to_json(body.context) if body.context else '{}'}\n"
        "خروجی را فقط JSON بده."
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.2)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="ساختار خروجی نامعتبر است.")
    action = str(parsed.get("action") or "unknown")
    payload = parsed.get("payload") or {k: v for k, v in parsed.items() if k != "action"}
    if not isinstance(payload, dict):
        payload = {"value": payload}
    return SmartIntentResponse(action=action, payload=payload, raw_text=raw_text)
@app.post("/assistant/daily-briefing", response_model=GenericAIResponse)
async def daily_briefing(body: DailyBriefingRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک منشی شخصی هستی. فقط JSON بده با کلیدهای "
        '{"briefing": str, "highlights": [], "next_actions": [], "reminders": [], "tone": "friendly"}. '
        "خلاصه را کوتاه و عملی بنویس. پیشنهاد اولویت را در next_actions بده."
    )
    user_prompt = (
        f"زمان: {body.now or 'نامشخص'} ({body.timezone or 'Asia/Tehran'})\n"
        f"تسک‌ها: {_to_json(body.tasks) if body.tasks else '[]'}\n"
        f"پیام‌های مهم: {_to_json(body.messages) if body.messages else '[]'}\n"
        f"انرژی: {body.energy or 'نامشخص'} | خواب: {body.sleep or 'نامشخص'}\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}\n"
        "یک daily briefing کوتاه بده."
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.3)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="خلاصه ساختار JSON ندارد.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)
@app.post("/assistant/next-action", response_model=GenericAIResponse)
async def next_action(body: NextActionRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک موتور پیشنهاد کار بعدی هستی. JSON بده با کلیدهای "
        '{"suggested": {"title": str, "reason": str, "duration_estimate_min": int}, "alternatives": []}. '
        "بهینه کن بر اساس زمان باقی‌مانده و انرژی کاربر."
    )
    user_prompt = (
        f"زمان در دسترس (دقیقه): {body.available_minutes or 'نامشخص'}\n"
        f"انرژی: {body.energy or 'نامشخص'} | مود: {body.mode or 'نامشخص'}\n"
        f"تسک‌ها: {_to_json(body.tasks) if body.tasks else '[]'}\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}"
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.25)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="خروجی JSON نیست.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)
@app.post("/assistant/modes/decide", response_model=GenericAIResponse)
async def decide_mode(body: SmartIntentRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک Mode Selector هستی. فقط JSON بده با کلیدهای "
        '{"mode": "<work|home|focus|sleep|travel|default>", "reason": str, "triggers": []}. '
        "اگر داده کافی نیست، mode را default بگذار."
    )
    user_prompt = (
        f"متن کاربر: {body.text}\n"
        f"زمان: {body.now or 'نامشخص'} ({body.timezone or 'Asia/Tehran'})\n"
        f"مود فعلی: {body.mode or 'نامشخص'} | انرژی: {body.energy or 'نامشخص'}\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}"
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.25)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="خروجی JSON نیست.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)



@app.post(
    "/notifications/summarize",
    response_model=NotificationSummary,
    summary="Generate AI summary of notifications and messages",
)
async def summarize_notifications(req: SummarizeRequest) -> NotificationSummary:
    """
    این همون اندپوینتیه که Flutter می‌زنه:
    apiClient.postJson('/user/notifications/summarize', body: {...})
    و انتظارش اینه که خود NotificationSummary رو در ریشه‌ی JSON بگیره.
    """

    system_prompt = """
    You are an AI assistant that summarizes a user's notifications and messages.
    You MUST return STRICT JSON that matches exactly this schema, with these keys:

    {
      "summary_id": "string",
      "total_notifications": int,
      "read_count": int,
      "unread_count": int,
      "important_messages": [
        {
          "message_id": "string",
          "sender": "string",
          "subject": "string",
          "preview": "string",
          "importance": "critical|high|medium|low",
          "keywords": ["string", ...],
          "received_at": "ISO 8601 datetime string"
        }
      ],
      "critical_alerts": [
        {
          "alert_id": "string",
          "title": "string",
          "description": "string",
          "severity": "critical|high|medium",
          "action": "string or null",
          "created_at": "ISO 8601 datetime string"
        }
      ],
      "action_items": [
        {
          "item_id": "string",
          "title": "string",
          "description": "string",
          "due_date": "YYYY-MM-DD or null",
          "assignee": "string or null",
          "priority": "high|medium|low",
          "source": "string",
          "completed": true or false
        }
      ],
      "ai_generated_summary": "string or null",
      "sentiment_score": float,
      "dominant_topic": "string",
      "key_people": ["string", ...],
      "generated_at": "ISO 8601 datetime string"
    }

    Do NOT include any other top-level keys or text.
    """

    user_payload = {
        "notifications": req.notifications,
        "messages": req.messages,
        "focus_area": req.focus_area,
        "hours_back": req.hours_back,
    }
    user_prompt = json.dumps(user_payload, ensure_ascii=False)

    parsed, raw_text = await _run_structured_completion(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        temperature=0.35,
    )

    try:
        summary = NotificationSummary(**parsed)
    except ValidationError as e:
        # مدل JSON معیوب داده
        raise HTTPException(status_code=502, detail=f"ساختار خلاصه نامعتبر است: {e}")

    # TODO: اینجا می‌تونی summary رو تو DB ذخیره کنی

    return summary


# =========================
# 2) GET /user/notifications/summary/today
# =========================

@app.get(
    "/user/notifications/summary/today",
    response_model=TodaySummaryResponse,
    summary="Get today's notification summary",
)
async def get_today_summary() -> TodaySummaryResponse:
    """
    Flutter انتظار داره:
    response['summary'] رو به NotificationSummary تبدیل کنه.
    """

    today = datetime.utcnow().date()

    # TODO: از DB آخرین summary همین روز رو دربیار
    # fake مثال:
    stored_summary: Optional[NotificationSummary] = None

    if stored_summary is None:
        return TodaySummaryResponse(summary=None)

    return TodaySummaryResponse(summary=stored_summary)


# =========================
# 3) GET /user/messages/important
# =========================

@app.get(
    "/messages/important",
    response_model=ImportantMessagesResponse,
    summary="Get AI-filtered important messages",
)
async def get_important_messages(limit: int = Query(20, ge=1, le=100)) -> ImportantMessagesResponse:
    """
    Flutter:
    GET /user/messages/important?limit=20
    بعد response['messages'] رو parse می‌کنه.
    """

    # TODO: از DB ایمیل/پیام‌ها رو بیار، با سیگنال‌ها/AI رتبه‌بندی کن
    # فعلاً یه لیست ساختگی:
    now = datetime.utcnow()
    messages: List[ImportantMessage] = [
        ImportantMessage(
            message_id="msg_1",
            sender="boss@example.com",
            subject="Quarterly report",
            preview="Please send me the quarterly report...",
            importance="high",
            keywords=["report", "deadline"],
            received_at=now - timedelta(hours=2),
        )
    ][:limit]

    return ImportantMessagesResponse(messages=messages)


# =========================
# 4) GET /user/notifications/critical
# =========================

@app.get(
    "/user/notifications/critical",
    response_model=CriticalAlertsResponse,
    summary="Get critical alerts",
)
async def get_critical_alerts(limit: int = Query(10, ge=1, le=100)) -> CriticalAlertsResponse:
    # TODO: از DB نوتیف‌های بحرانی رو بیار
    now = datetime.utcnow()
    alerts: List[CriticalAlert] = [
        CriticalAlert(
            alert_id="alert_1",
            title="Low account balance",
            description="Your balance is under 10€.",
            severity="critical",
            action="open_banking_app",
            created_at=now - timedelta(minutes=30),
        )
    ][:limit]

    return CriticalAlertsResponse(alerts=alerts)


# =========================
# 5) GET /user/messages/insights
# =========================

@app.get(
    "/messages/insights",
    response_model=InsightsResponse,
    summary="Get personalized insights from messages",
)
async def get_message_insights() -> InsightsResponse:
    """
    اینجا می‌تونی واقعاً از LLM استفاده کنی، با همون helper.
    برای سادگی فعلاً fake برمی‌گردونم.
    """

    # TODO: پیام‌های کاربر رو از DB بگیر و به LLM بده
    most_contacted = [{"name": "Ali", "email": "ali@example.com", "count": 25}]
    conversation_topics = [
        {"topic": "work", "score": 0.7},
        {"topic": "personal", "score": 0.3},
    ]
    sentiment_trend = [
        {"date": "2025-01-01", "score": 0.1},
        {"date": "2025-01-02", "score": 0.3},
    ]
    pending_actions = [{"message_id": "m1", "title": "Reply to manager"}]
    follow_ups_needed = [{"message_id": "m2", "title": "Send report"}]

    return InsightsResponse(
        most_contacted=most_contacted,
        conversation_topics=conversation_topics,
        sentiment_trend=sentiment_trend,
        pending_actions=pending_actions,
        follow_ups_needed=follow_ups_needed,
    )


# =========================
# 6) POST /user/notifications/categorize
# =========================

@app.post(
    "/notifications/categorize",
    response_model=NotificationCategory,
    summary="Categorize a single notification using AI",
)
async def categorize_notification(req: CategorizeRequest) -> NotificationCategory:
    """
    این اندپوینت مستقیم با LLM و _run_structured_completion کار می‌کنه.
    """

    system_prompt = """
    You classify a single notification based on title and body.
    Return STRICT JSON with this exact schema:

    {
      "category": "work|personal|social|system|other",
      "urgency": "critical|high|medium|low",
      "confidence": float,
      "suggested_action": "string or null"
    }

    Do NOT include anything other than this JSON.
    """
    user_prompt = json.dumps(
        {"title": req.title, "body": req.body},
        ensure_ascii=False,
    )

    parsed, raw_text = await _run_structured_completion(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        temperature=0.2,
    )

    try:
        cat = NotificationCategory(**parsed)
    except ValidationError as e:
        raise HTTPException(status_code=502, detail=f"پاسخ دسته‌بندی نامعتبر است: {e}")

    return cat


# =========================
# 7) GET /user/messages/action-items
# =========================

@app.get(
    "/messages/action-items",
    response_model=ActionItemsResponse,
    summary="Extract action items from messages",
)
async def extract_action_items() -> ActionItemsResponse:
    """
    Flutter: GET /user/messages/action-items
    بعد response['action_items'] رو parse می‌کنه.
    """

    # TODO: پیام‌های خام رو از DB بگیر و بده به LLM برای استخراج action item.
    # فعلاً fake:
    items: List[ActionItem] = [
        ActionItem(
            item_id="act_1",
            title="Prepare quarterly report",
            description="Prepare and send the Q1 report to finance.",
            due_date="2025-01-10",
            assignee="me",
            priority="high",
            source="msg_1",
            completed=False,
        )
    ]

    return ActionItemsResponse(action_items=items)


# =========================
# 8) POST /user/notifications/{notification_id}/processed
# =========================

@app.post(
    "/notifications/{notification_id}/processed",
    summary="Mark notification as processed by AI",
)
async def mark_notification_processed(notification_id: str) -> Dict[str, bool]:
    # TODO: توی DB فلگ notification رو به processed تغییر بده
    # اگر notification پیدا نشد:
    # raise HTTPException(status_code=404, detail="Notification not found")

    return {"ok": True}


# =========================
# 9) GET /user/notifications/trends
# =========================

@app.get(
    "/user/notifications/trends",
    response_model=NotificationTrendsResponse,
    summary="Get notification trends",
)
async def get_notification_trends(days: int = Query(7, ge=1, le=90)) -> NotificationTrendsResponse:
    """
    Flutter: GET /user/notifications/trends?days=7
    """

    # TODO: از DB آمار روزانه رو حساب کن، اگر خواستی قسمتی ازش رو با LLM enrich کن.
    trends = NotificationTrends(
        total_notifications=120,
        average_per_day=120 // days,
        top_senders=["Telegram", "Gmail", "Slack"],
        category_breakdown={"work": 40, "personal": 30, "social": 25, "system": 25},
        average_sentiment=0.15,
        emerging_topics=["travel", "billing"],
    )

    return NotificationTrendsResponse(**trends.dict())


# =========================
# 10) POST /user/notifications/snooze
# =========================

@app.post(
    "/notifications/snooze",
    summary="Snooze notifications for a period",
)
async def snooze_notifications(req: SnoozeRequest) -> Dict[str, bool]:
    """
    Flutter:
    apiClient.postJson('/user/notifications/snooze', body: {
        'snooze_minutes': snoozeDuration.inMinutes,
        'category': category,
    });
    """

    # TODO: تنظیمات snooze را در DB/سیستم نوتیف کاربر ذخیره کن
    return {"ok": True}
@app.post("/assistant/notifications/classify", response_model=GenericAIResponse)
async def notification_intel(body: NotificationIntelRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک Notification Intelligence هستی. JSON بده با کلیدهای "
        '{"classified": [{"title": str, "category": "critical|important|normal|spam", "suggested_action": str}]} '
        "و یک summary کوتاه در summary."
    )
    user_prompt = (
        f"مود: {body.mode or 'نامشخص'} | تایم‌زون: {body.timezone or 'Asia/Tehran'}\n"
        f"نوتیف‌ها: {_to_json(body.notifications)}\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}"
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.2)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="JSON نامعتبر.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)
@app.post("/assistant/inbox/intel", response_model=GenericAIResponse)
async def inbox_intel(body: InboxIntelRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو پیام‌ها را خلاصه و کار پیشنهادی می‌دهی. JSON برگردان با کلیدهای "
        '{"summary": str, "actions": [{"type": "reply|reminder|note", "suggested_text": str, "when": str}]} '
        "اگر متن مبهم است، actions را خالی بگذار و در summary بگو نیاز به توضیح بیشتر است."
    )
    user_prompt = (
        f"کانال: {body.channel or 'نامشخص'}\n"
        f"پیام: {body.message}\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}"
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.25)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="JSON نامعتبر.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)
@app.post("/assistant/scheduler/weekly", response_model=GenericAIResponse)
async def smart_scheduler(body: WeeklySchedulerRequest, current_user: User = Depends(get_current_user)):
    system_prompt = (
        "تو یک برنامه‌ریز هفتگی هستی. JSON بده با کلیدهای "
        '{"plan": [{"title": str, "day": str, "start": str, "end": str, "reason": str}], "conflicts": [], "notes": str}. '
        "از hard_events برای جلوگیری از تداخل استفاده کن. زمان‌ها را ISO بده."
    )
    user_prompt = (
        f"اهداف هفته: {_to_json(body.goals)}\n"
        f"رویدادهای غیرقابل‌تغییر: {_to_json(body.hard_events) if body.hard_events else '[]'}\n"
        f"زمان: {body.now or 'نامشخص'} ({body.timezone or 'Asia/Tehran'})\n"
        f"کانتکست: {_to_json(body.context) if body.context else '{}'}"
    )
    parsed, raw_text = await _run_structured_completion(system_prompt, user_prompt, temperature=0.3)
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=502, detail="JSON نامعتبر.")
    return GenericAIResponse(payload=parsed, raw_text=raw_text)
@app.post("/assistant/memory/upsert")
async def memory_upsert(body: MemoryUpsertRequest, current_user: User = Depends(get_current_user)):
    saved = await _store_memories(current_user.id, body.facts, body.key)
    return {"saved": saved}
@app.post("/assistant/memory/search", response_model=MemorySearchResponse)
async def memory_search(body: MemorySearchRequest, current_user: User = Depends(get_current_user)):
    records = await _search_memories(current_user.id, body.query, body.limit)
    items = [
        {
            "id": rec.id,
            "key": rec.key,
            "content": rec.content,
            "created_at": rec.created_at.isoformat(),
        }
        for rec in records
    ]
    return MemorySearchResponse(items=items)
@app.on_event("startup")
async def _startup():
    global _APP_LOOP
    _APP_LOOP = asyncio.get_event_loop()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await _reset_stale_agent_tasks()
    AGENT_SCHEDULER_STOP.clear()
    global AGENT_SCHEDULER_TASK
    if AGENT_SCHEDULER_TASK is None or AGENT_SCHEDULER_TASK.done():
        AGENT_SCHEDULER_TASK = asyncio.create_task(_agent_task_worker())
        log.info("Agent task scheduler started.")
    _start_telegram_bot()
# ═══════════════════════════════════════════════════════════════════
# PERSONALIZATION API - Phase 1 Endpoints
# ═══════════════════════════════════════════════════════════════════
@app.post("/user/profile/setup", response_model=UserProfileResponse)
async def setup_user_profile(
    body: UserProfileSetupRequest,
    current_user: User = Depends(get_current_user),
):
    """Setup user profile during onboarding"""
    async with async_session() as session:
        # Check if profile already exists
        stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        existing = await session.execute(stmt)
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="پروفایل قبلاً ایجاد شده است")
        
        # Create new profile
        profile = UserProfile(
            user_id=current_user.id,
            name=body.name,
            role=body.role,
            timezone=body.timezone,
            interests=json.dumps(body.interests),
            wake_up_time=body.wake_up_time,
            sleep_time=body.sleep_time,
            focus_hours=body.focus_hours,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(profile)
        await session.commit()
        
        return UserProfileResponse(
            user_id=current_user.id,
            name=profile.name,
            role=profile.role,
            timezone=profile.timezone,
            interests=json.loads(profile.interests) if profile.interests else [],
            wake_up_time=profile.wake_up_time,
            sleep_time=profile.sleep_time,
            focus_hours=profile.focus_hours,
            active_goal_ids=[],
            preferred_break_duration=profile.preferred_break_duration,
            enable_motivation=profile.enable_motivation,
            communication_style=profile.communication_style,
            track_habits=profile.track_habits,
            created_at=profile.created_at,
        )
@app.get("/user/profile", response_model=UserProfileResponse)
async def get_user_profile(current_user: User = Depends(get_current_user)):
    """Get user profile"""
    async with async_session() as session:
        stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        profile = await session.execute(stmt)
        profile_obj = profile.scalar_one_or_none()
        
        if not profile_obj:
            raise HTTPException(status_code=404, detail="پروفایل یافت نشد")
        
        return UserProfileResponse(
            user_id=current_user.id,
            name=profile_obj.name,
            role=profile_obj.role,
            timezone=profile_obj.timezone,
            interests=json.loads(profile_obj.interests) if profile_obj.interests else [],
            wake_up_time=profile_obj.wake_up_time,
            sleep_time=profile_obj.sleep_time,
            focus_hours=profile_obj.focus_hours,
            avg_energy=profile_obj.avg_energy,
            avg_mood=profile_obj.avg_mood,
            active_goal_ids=json.loads(profile_obj.active_goal_ids) if profile_obj.active_goal_ids else [],
            preferred_break_duration=profile_obj.preferred_break_duration,
            enable_motivation=profile_obj.enable_motivation,
            communication_style=profile_obj.communication_style,
            track_habits=profile_obj.track_habits,
            created_at=profile_obj.created_at,
        )
@app.put("/user/profile/update", response_model=UserProfileResponse)
async def update_user_profile(
    body: UserProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
):
    """Update user profile"""
    async with async_session() as session:
        stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        profile_obj = await session.execute(stmt)
        profile_obj = profile_obj.scalar_one_or_none()
        
        if not profile_obj:
            raise HTTPException(status_code=404, detail="پروفایل یافت نشد")
        
        # Update fields
        if body.name is not None:
            profile_obj.name = body.name
        if body.timezone is not None:
            profile_obj.timezone = body.timezone
        if body.interests is not None:
            profile_obj.interests = json.dumps(body.interests)
        if body.preferred_break_duration is not None:
            profile_obj.preferred_break_duration = body.preferred_break_duration
        if body.enable_motivation is not None:
            profile_obj.enable_motivation = body.enable_motivation
        if body.communication_style is not None:
            profile_obj.communication_style = body.communication_style
        
        profile_obj.updated_at = datetime.utcnow()
        await session.commit()
        
        return UserProfileResponse(
            user_id=current_user.id,
            name=profile_obj.name,
            role=profile_obj.role,
            timezone=profile_obj.timezone,
            interests=json.loads(profile_obj.interests) if profile_obj.interests else [],
            wake_up_time=profile_obj.wake_up_time,
            sleep_time=profile_obj.sleep_time,
            focus_hours=profile_obj.focus_hours,
            avg_energy=profile_obj.avg_energy,
            avg_mood=profile_obj.avg_mood,
            active_goal_ids=json.loads(profile_obj.active_goal_ids) if profile_obj.active_goal_ids else [],
            preferred_break_duration=profile_obj.preferred_break_duration,
            enable_motivation=profile_obj.enable_motivation,
            communication_style=profile_obj.communication_style,
            track_habits=profile_obj.track_habits,
            created_at=profile_obj.created_at,
        )
@app.post("/user/goals", response_model=UserGoalResponse)
async def create_goal(
    body: UserGoalCreateRequest,
    current_user: User = Depends(get_current_user),
):
    """Create a new goal"""
    goal_id = str(uuid.uuid4())
    
    async with async_session() as session:
        goal = UserGoal(
            user_id=current_user.id,
            goal_id=goal_id,
            title=body.title,
            category=body.category,
            description=body.description,
            deadline=datetime.fromisoformat(body.deadline.replace('Z', '+00:00')) if isinstance(body.deadline, str) else body.deadline,
            priority=body.priority,
            milestones=json.dumps(body.milestones) if body.milestones else None,
            status="active",
            linked_task_ids=body.linked_task_ids or [],
            linked_habit_ids=body.linked_habit_ids or [],
            auto_progress_enabled=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(goal)
        await session.flush()
        
        # Create milestones if provided
        if body.milestones:
            for idx, milestone in enumerate(body.milestones):
                ms = GoalMilestone(
                    goal_id=goal.id,
                    user_id=current_user.id,
                    milestone_id=str(uuid.uuid4()),
                    title=milestone.title,
                    description=milestone.description,
                    target_date=datetime.fromisoformat(milestone.target_date) if milestone.target_date else None,
                    order=idx,
                    progress_contribution=milestone.progress_contribution,
                )
                session.add(ms)
        
        await session.commit()
        await session.refresh(goal)
        
        return UserGoalResponse(
            goal_id=goal_id,
            user_id=current_user.id,
            title=goal.title,
            category=goal.category,
            description=goal.description,
            deadline=goal.deadline.isoformat(),
            priority=goal.priority,
            progress_percentage=goal.progress_percentage,
            status=goal.status,
            created_at=goal.created_at.isoformat(),
        )
@app.get("/user/goals")
async def get_user_goals(current_user: User = Depends(get_current_user)):
    """Get all user goals with auto-tracking"""
    async with async_session() as session:
        stmt = select(UserGoal).where(UserGoal.user_id == current_user.id)
        result = await session.execute(stmt)
        goals = result.scalars().all()
        
        active_count = sum(1 for g in goals if g.status == "active")
        completed_count = sum(1 for g in goals if g.status == "completed")
        
        goal_responses = []
        for goal in goals:
            # Auto-update progress if enabled
            if goal.auto_progress_enabled:
                await _update_goal_progress_auto(current_user.id, goal.id)
                await session.refresh(goal)
            
            trend = await _get_goal_progress_trend(goal.id)
            on_track = await _is_goal_on_track(goal)
            days_remaining = (goal.deadline - datetime.utcnow()).days if goal.deadline else None
            
            # Get milestones
            milestone_stmt = select(GoalMilestone).where(
                GoalMilestone.goal_id == goal.id
            ).order_by(GoalMilestone.order)
            milestone_result = await session.execute(milestone_stmt)
            milestones_db = milestone_result.scalars().all()
            
            milestones = [
                MilestoneResponse(
                    milestone_id=m.milestone_id,
                    title=m.title,
                    description=m.description,
                    target_date=m.target_date,
                    status=m.status,
                    progress_contribution=m.progress_contribution,
                    completed_at=m.completed_at
                )
                for m in milestones_db
            ]
            
            goal_responses.append(GoalResponse(
                goal_id=goal.goal_id,
                title=goal.title,
                description=goal.description,
                category=goal.category,
                deadline=goal.deadline,
                priority=goal.priority,
                status=goal.status,
                progress_percentage=goal.progress_percentage,
                milestones=milestones,
                linked_task_count=len(goal.linked_task_ids or []),
                linked_habit_count=len(goal.linked_habit_ids or []),
                auto_progress_enabled=goal.auto_progress_enabled,
                motivation_message=goal.motivation_message,
                created_at=goal.created_at,
                completed_at=goal.completed_at,
                progress_trend=GoalProgressResponse(
                    progress_percentage=goal.progress_percentage,
                    last_updated=goal.last_auto_update or goal.updated_at,
                    days_remaining=days_remaining,
                    on_track=on_track,
                    trend=trend
                )
            ))
        
        return GoalListResponse(
            total=len(goals),
            active_count=active_count,
            completed_count=completed_count,
            goals=goal_responses
        )
@app.put("/user/goals/{goal_id}", response_model=UserGoalResponse)
async def update_goal(
    goal_id: str,
    body: UserGoalUpdateRequest,
    current_user: User = Depends(get_current_user),
):
    """Update goal progress with auto-tracking"""
    async with async_session() as session:
        stmt = select(UserGoal).where(
            (UserGoal.user_id == current_user.id) & (UserGoal.goal_id == goal_id)
        )
        result = await session.execute(stmt)
        goal = result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="goal یافت نشد")
        
        old_progress = goal.progress_percentage
        
        # Trigger auto-update if enabled
        if goal.auto_progress_enabled:
            await _update_goal_progress_auto(current_user.id, goal.id)
            await session.refresh(goal)
            
            # Log progress change if it changed
            if goal.progress_percentage != old_progress:
                log_entry = GoalProgressLog(
                    goal_id=goal.id,
                    old_progress=old_progress,
                    new_progress=goal.progress_percentage,
                    reason="auto_update",
                    logged_at=datetime.utcnow()
                )
                session.add(log_entry)
        
        # Manual progress update if provided
        if body.progress_percentage is not None:
            goal.progress_percentage = min(100, max(0, body.progress_percentage))
            # Log manual progress change
            if goal.progress_percentage != old_progress:
                log_entry = GoalProgressLog(
                    goal_id=goal.id,
                    old_progress=old_progress,
                    new_progress=goal.progress_percentage,
                    reason="manual_update",
                    logged_at=datetime.utcnow()
                )
                session.add(log_entry)
        
        if body.status is not None:
            goal.status = body.status
            if body.status == "completed":
                goal.completed_at = datetime.utcnow()
        
        if body.milestones is not None:
            goal.milestones = json.dumps(body.milestones)
        
        goal.updated_at = datetime.utcnow()
        await session.commit()
        
        return UserGoalResponse(
            goal_id=goal.goal_id,
            user_id=goal.user_id,
            title=goal.title,
            category=goal.category,
            description=goal.description,
            deadline=goal.deadline.isoformat(),
            priority=goal.priority,
            progress_percentage=goal.progress_percentage,
            status=goal.status,
            created_at=goal.created_at.isoformat(),
        )
@app.post("/user/mood/snapshot", response_model=MoodSnapshotResponse)
async def record_mood(
    body: MoodSnapshotRequest,
    current_user: User = Depends(get_current_user),
):
    """Record mood snapshot"""
    snapshot_id = str(uuid.uuid4())
    
    async with async_session() as session:
        snapshot = MoodSnapshot(
            user_id=current_user.id,
            snapshot_id=snapshot_id,
            timestamp=datetime.utcnow(),
            energy=body.energy,
            mood=body.mood,
            context=body.context,
            activity=body.activity,
            notes=body.notes,
            created_at=datetime.utcnow(),
        )
        session.add(snapshot)
        
        # Update profile average
        stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        profile = await session.execute(stmt)
        profile_obj = profile.scalar_one_or_none()
        
        if profile_obj:
            profile_obj.avg_energy = body.energy
            profile_obj.avg_mood = body.mood
            profile_obj.last_mood_update = datetime.utcnow()
            profile_obj.updated_at = datetime.utcnow()
        
        await session.commit()
        
        return MoodSnapshotResponse(
            snapshot_id=snapshot_id,
            user_id=current_user.id,
            timestamp=snapshot.timestamp.isoformat(),
            energy=snapshot.energy,
            mood=snapshot.mood,
            context=snapshot.context,
            activity=snapshot.activity,
        )
@app.get("/user/mood/history")
async def get_mood_history(
    last: int = 30,
    current_user: User = Depends(get_current_user),
):
    """Get mood history"""
    async with async_session() as session:
        stmt = (
            select(MoodSnapshot)
            .where(MoodSnapshot.user_id == current_user.id)
            .order_by(MoodSnapshot.timestamp.desc())
            .limit(last)
        )
        result = await session.execute(stmt)
        snapshots = result.scalars().all()
        
        if not snapshots:
            return MoodHistoryResponse(
                snapshots=[],
                avg_energy=5.0,
                avg_mood=5.0,
                trend="stable",
            )
        
        avg_energy = sum(s.energy for s in snapshots) / len(snapshots)
        avg_mood = sum(s.mood for s in snapshots) / len(snapshots)
        
        # Determine trend (simplified)
        if len(snapshots) >= 2:
            recent_avg = sum(s.energy for s in snapshots[:5]) / min(5, len(snapshots))
            older_avg = sum(s.energy for s in snapshots[-5:]) / min(5, len(snapshots))
            trend = "improving" if recent_avg > older_avg else ("declining" if recent_avg < older_avg else "stable")
        else:
            trend = "stable"
        
        return MoodHistoryResponse(
            snapshots=[
                MoodSnapshotResponse(
                    snapshot_id=s.snapshot_id,
                    user_id=s.user_id,
                    timestamp=s.timestamp.isoformat(),
                    energy=s.energy,
                    mood=s.mood,
                    context=s.context,
                    activity=s.activity,
                )
                for s in snapshots
            ],
            avg_energy=avg_energy,
            avg_mood=avg_mood,
            trend=trend,
        )
@app.post("/user/goals/{goal_id}/complete")
async def complete_goal(
    goal_id: str,
    current_user: User = Depends(get_current_user),
):
    """Mark goal as completed"""
    async with async_session() as session:
        stmt = select(UserGoal).where(
            (UserGoal.user_id == current_user.id) & (UserGoal.goal_id == goal_id)
        )
        result = await session.execute(stmt)
        goal = result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="goal یافت نشد")
        
        goal.status = "completed"
        goal.completed_at = datetime.utcnow()
        goal.progress_percentage = 100
        goal.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "completed", "goal_id": goal_id}
@app.delete("/user/goals/{goal_id}")
async def delete_goal(
    goal_id: str,
    current_user: User = Depends(get_current_user),
):
    """Delete (archive) goal"""
    async with async_session() as session:
        stmt = select(UserGoal).where(
            (UserGoal.user_id == current_user.id) & (UserGoal.goal_id == goal_id)
        )
        result = await session.execute(stmt)
        goal = result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="goal یافت نشد")
        
        goal.status = "archived"
        goal.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "archived", "goal_id": goal_id}


@app.post("/user/goals/{goal_id}/link-task")
async def link_task_to_goal(
    goal_id: str,
    body: dict,
    current_user: User = Depends(get_current_user)
):
    """Link an existing task to a goal"""
    task_id = body.get("task_id")
    if not task_id:
        raise HTTPException(status_code=400, detail="task_id required")
    
    async with async_session() as session:
        # Verify goal exists and belongs to user
        goal_stmt = select(UserGoal).where(
            (UserGoal.goal_id == goal_id) & (UserGoal.user_id == current_user.id)
        )
        goal_result = await session.execute(goal_stmt)
        goal = goal_result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="Goal not found")
        
        # Verify task exists and belongs to user
        task_stmt = select(UserTask).where(
            (UserTask.task_id == task_id) & (UserTask.user_id == current_user.id)
        )
        task_result = await session.execute(task_stmt)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # Add task to goal's linked tasks
        linked_ids = goal.linked_task_ids or []
        if task_id not in linked_ids:
            linked_ids.append(task_id)
            goal.linked_task_ids = linked_ids
            goal.updated_at = datetime.utcnow()
        
        # Trigger auto-progress
        await _update_goal_progress_auto(current_user.id, goal.id)
        await session.commit()
        await session.refresh(goal)
        
        return {
            "status": "linked",
            "goal_id": goal_id,
            "task_id": task_id,
            "total_linked_tasks": len(goal.linked_task_ids or []),
            "new_progress": goal.progress_percentage
        }


@app.post("/user/goals/{goal_id}/unlink-task")
async def unlink_task_from_goal(
    goal_id: str,
    body: dict,
    current_user: User = Depends(get_current_user)
):
    """Unlink a task from a goal"""
    task_id = body.get("task_id")
    if not task_id:
        raise HTTPException(status_code=400, detail="task_id required")
    
    async with async_session() as session:
        # Verify goal exists
        goal_stmt = select(UserGoal).where(
            (UserGoal.goal_id == goal_id) & (UserGoal.user_id == current_user.id)
        )
        goal_result = await session.execute(goal_stmt)
        goal = goal_result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="Goal not found")
        
        # Remove task from linked tasks
        linked_ids = goal.linked_task_ids or []
        if task_id in linked_ids:
            linked_ids.remove(task_id)
            goal.linked_task_ids = linked_ids
            goal.updated_at = datetime.utcnow()
        
        # Trigger auto-progress
        await _update_goal_progress_auto(current_user.id, goal.id)
        await session.commit()
        await session.refresh(goal)
        
        return {
            "status": "unlinked",
            "goal_id": goal_id,
            "task_id": task_id,
            "total_linked_tasks": len(goal.linked_task_ids or []),
            "new_progress": goal.progress_percentage
        }


@app.post("/user/goals/{goal_id}/milestones")
async def add_milestone(
    goal_id: str,
    body: MilestoneCreateRequest,
    current_user: User = Depends(get_current_user)
):
    """Add a milestone to an active goal"""
    async with async_session() as session:
        # Verify goal exists
        goal_stmt = select(UserGoal).where(
            (UserGoal.goal_id == goal_id) & (UserGoal.user_id == current_user.id)
        )
        goal_result = await session.execute(goal_stmt)
        goal = goal_result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="Goal not found")
        
        if goal.status != "active":
            raise HTTPException(status_code=400, detail="Goal must be active to add milestones")
        
        # Get count of existing milestones for order
        count_stmt = select(func.count(GoalMilestone.id)).where(
            GoalMilestone.goal_id == goal.id
        )
        count_result = await session.execute(count_stmt)
        milestone_count = count_result.scalar() or 0
        
        # Create milestone
        milestone = GoalMilestone(
            goal_id=goal.id,
            title=body.title,
            description=body.description or "",
            target_date=body.target_date,
            status="pending",
            progress_contribution=body.progress_contribution or (100 // (milestone_count + 1)),
            order=milestone_count
        )
        session.add(milestone)
        goal.updated_at = datetime.utcnow()
        await session.commit()
        await session.refresh(milestone)
        
        return MilestoneResponse(
            milestone_id=milestone.milestone_id,
            title=milestone.title,
            description=milestone.description,
            target_date=milestone.target_date,
            status=milestone.status,
            progress_contribution=milestone.progress_contribution,
            completed_at=milestone.completed_at
        )


@app.put("/user/goals/{goal_id}/milestones/{milestone_id}")
async def update_milestone(
    goal_id: str,
    milestone_id: str,
    body: dict,
    current_user: User = Depends(get_current_user)
):
    """Update milestone status and details"""
    async with async_session() as session:
        # Verify goal exists
        goal_stmt = select(UserGoal).where(
            (UserGoal.goal_id == goal_id) & (UserGoal.user_id == current_user.id)
        )
        goal_result = await session.execute(goal_stmt)
        goal = goal_result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="Goal not found")
        
        # Get milestone
        milestone_stmt = select(GoalMilestone).where(
            (GoalMilestone.milestone_id == milestone_id) & (GoalMilestone.goal_id == goal.id)
        )
        milestone_result = await session.execute(milestone_stmt)
        milestone = milestone_result.scalar_one_or_none()
        
        if not milestone:
            raise HTTPException(status_code=404, detail="Milestone not found")
        
        # Update fields
        if "title" in body:
            milestone.title = body["title"]
        if "description" in body:
            milestone.description = body["description"]
        if "target_date" in body:
            milestone.target_date = body["target_date"]
        if "status" in body:
            milestone.status = body["status"]
            if body["status"] == "completed":
                milestone.completed_at = datetime.utcnow()
                # Trigger goal progress update
                await _update_goal_progress_auto(current_user.id, goal.id)
                await session.refresh(goal)
        if "progress_contribution" in body:
            milestone.progress_contribution = body["progress_contribution"]
        
        goal.updated_at = datetime.utcnow()
        await session.commit()
        await session.refresh(milestone)
        
        return MilestoneResponse(
            milestone_id=milestone.milestone_id,
            title=milestone.title,
            description=milestone.description,
            target_date=milestone.target_date,
            status=milestone.status,
            progress_contribution=milestone.progress_contribution,
            completed_at=milestone.completed_at
        )

@app.get("/user/goals/{goal_id}/progress-history")
async def get_goal_progress_history(
    goal_id: str,
    limit: int = 50,
    current_user: User = Depends(get_current_user)
):
    """Get goal progress change history"""
    async with async_session() as session:
        # Verify goal exists
        goal_stmt = select(UserGoal).where(
            (UserGoal.goal_id == goal_id) & (UserGoal.user_id == current_user.id)
        )
        goal_result = await session.execute(goal_stmt)
        goal = goal_result.scalar_one_or_none()
        
        if not goal:
            raise HTTPException(status_code=404, detail="Goal not found")
        
        # Get progress history
        history_stmt = select(GoalProgressLog).where(
            GoalProgressLog.goal_id == goal.id
        ).order_by(GoalProgressLog.logged_at.desc()).limit(limit)
        
        history_result = await session.execute(history_stmt)
        logs = history_result.scalars().all()
        
        return {
            "goal_id": goal_id,
            "history": [
                {
                    "old_progress": log.old_progress,
                    "new_progress": log.new_progress,
                    "reason": log.reason,
                    "logged_at": log.logged_at.isoformat(),
                    "change": log.new_progress - log.old_progress
                }
                for log in logs
            ]
        }

async def create_habit(
    body: HabitCreateRequest,
    current_user: User = Depends(get_current_user),
):
    """Create a new habit"""
    habit_id = str(uuid.uuid4())
    
    async with async_session() as session:
        habit = Habit(
            user_id=current_user.id,
            habit_id=habit_id,
            name=body.name,
            category=body.category,
            description=body.description,
            frequency=body.frequency,
            target_count=body.target_count,
            current_streak=0,
            longest_streak=0,
            total_completions=0,
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(habit)
        await session.commit()
        
        return HabitResponse(
            habit_id=habit_id,
            user_id=current_user.id,
            name=habit.name,
            category=habit.category,
            description=habit.description,
            frequency=habit.frequency,
            target_count=habit.target_count,
            current_streak=habit.current_streak,
            longest_streak=habit.longest_streak,
            total_completions=habit.total_completions,
            is_active=habit.is_active,
            created_at=habit.created_at.isoformat(),
        )
@app.get("/habits")
async def get_habits(current_user: User = Depends(get_current_user)):
    """Get all habits for user"""
    async with async_session() as session:
        stmt = select(Habit).where(Habit.user_id == current_user.id).order_by(Habit.updated_at.desc())
        result = await session.execute(stmt)
        habits = result.scalars().all()
        
        return {
            "habits": [
                HabitResponse(
                    habit_id=h.habit_id,
                    user_id=h.user_id,
                    name=h.name,
                    category=h.category,
                    description=h.description,
                    frequency=h.frequency,
                    target_count=h.target_count,
                    current_streak=h.current_streak,
                    longest_streak=h.longest_streak,
                    total_completions=h.total_completions,
                    is_active=h.is_active,
                    created_at=h.created_at.isoformat(),
                )
                for h in habits
            ]
        }
@app.get("/habits/{habit_id}", response_model=HabitResponse)
async def get_habit(
    habit_id: str,
    current_user: User = Depends(get_current_user),
):
    """Get specific habit"""
    async with async_session() as session:
        stmt = select(Habit).where(
            (Habit.user_id == current_user.id) & (Habit.habit_id == habit_id)
        )
        result = await session.execute(stmt)
        habit = result.scalar_one_or_none()
        
        if not habit:
            raise HTTPException(status_code=404, detail="عادت یافت نشد")
        
        return HabitResponse(
            habit_id=habit.habit_id,
            user_id=habit.user_id,
            name=habit.name,
            category=habit.category,
            description=habit.description,
            frequency=habit.frequency,
            target_count=habit.target_count,
            current_streak=habit.current_streak,
            longest_streak=habit.longest_streak,
            total_completions=habit.total_completions,
            is_active=habit.is_active,
            created_at=habit.created_at.isoformat(),
        )
@app.post("/habits/{habit_id}/log")
async def log_habit_completion(
    habit_id: str,
    body: HabitLogRequest,
    current_user: User = Depends(get_current_user),
):
    """Log habit completion"""
    log_id = str(uuid.uuid4())
    
    async with async_session() as session:
        # Verify habit exists
        stmt = select(Habit).where(
            (Habit.user_id == current_user.id) & (Habit.habit_id == habit_id)
        )
        result = await session.execute(stmt)
        habit = result.scalar_one_or_none()
        
        if not habit:
            raise HTTPException(status_code=404, detail="عادت یافت نشد")
        
        # Create log entry
        log_entry = HabitLog(
            user_id=current_user.id,
            log_id=log_id,
            habit_id=habit_id,
            date=datetime.fromisoformat(body.date.replace('Z', '+00:00')),
            completed=body.completed,
            notes=body.notes,
            created_at=datetime.utcnow(),
        )
        session.add(log_entry)
        
        # Update habit stats
        if body.completed:
            habit.total_completions += 1
            habit.current_streak += 1
            if habit.current_streak > habit.longest_streak:
                habit.longest_streak = habit.current_streak
        else:
            habit.current_streak = 0
        
        habit.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"log_id": log_id, "habit_id": habit_id, "completed": body.completed}
@app.put("/habits/{habit_id}")
async def update_habit(
    habit_id: str,
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """Update habit details"""
    async with async_session() as session:
        stmt = select(Habit).where(
            (Habit.user_id == current_user.id) & (Habit.habit_id == habit_id)
        )
        result = await session.execute(stmt)
        habit = result.scalar_one_or_none()
        
        if not habit:
            raise HTTPException(status_code=404, detail="عادت یافت نشد")
        
        # Update fields if provided
        if "name" in body:
            habit.name = body["name"]
        if "description" in body:
            habit.description = body["description"]
        if "is_active" in body:
            habit.is_active = body["is_active"]
        
        habit.updated_at = datetime.utcnow()
        await session.commit()
        
        return HabitResponse(
            habit_id=habit.habit_id,
            user_id=habit.user_id,
            name=habit.name,
            category=habit.category,
            description=habit.description,
            frequency=habit.frequency,
            target_count=habit.target_count,
            current_streak=habit.current_streak,
            longest_streak=habit.longest_streak,
            total_completions=habit.total_completions,
            is_active=habit.is_active,
            created_at=habit.created_at.isoformat(),
        )
@app.delete("/habits/{habit_id}")
async def delete_habit(
    habit_id: str,
    current_user: User = Depends(get_current_user),
):
    """Delete/archive habit"""
    async with async_session() as session:
        stmt = select(Habit).where(
            (Habit.user_id == current_user.id) & (Habit.habit_id == habit_id)
        )
        result = await session.execute(stmt)
        habit = result.scalar_one_or_none()
        
        if not habit:
            raise HTTPException(status_code=404, detail="عادت یافت نشد")
        
        habit.is_active = False
        habit.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "archived", "habit_id": habit_id}
# ═══════════════════════════════════════════════════════════════════
# AUTH ENDPOINTS
# ═══════════════════════════════════════════════════════════════════
@app.post("/auth/request-otp")
async def request_otp(body: OTPRequestBody):
    """Request OTP code to be sent via SMS"""
    phone = _normalize_phone(body.phone)
    now = datetime.utcnow()
    async with async_session() as session:
        stmt = (
            select(OTPRequestModel)
            .where(OTPRequestModel.phone == phone)
            .order_by(OTPRequestModel.id.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        last_entry = result.scalar_one_or_none()
        if (
            last_entry
            and not last_entry.verified
            and (now - last_entry.sent_at).total_seconds() < OTP_RESEND_COOLDOWN
        ):
            raise HTTPException(status_code=429, detail="لطفاً کمی صبر کنید و دوباره تلاش کنید.")
        code = _generate_otp_code()
        entry = OTPRequestModel(
            phone=phone,
            code_hash=_hash_code(code),
            sent_at=now,
            expires_at=now + timedelta(seconds=OTP_EXPIRES_SECONDS),
            attempts=0,
            verified=False,
        )
        session.add(entry)
        await session.flush()
        try:
            await _send_otp_sms(phone, code)
        except Exception:
            await session.rollback()
            raise
        else:
            await session.commit()
    otp_token = _issue_otp_token(entry.id, phone)
    return {"detail": "کد تایید ارسال شد.", "otp_token": otp_token}
@app.post("/auth/verify-otp", response_model=OTPVerifyResponse)
async def verify_otp(
    body: OTPVerifyBody,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن OTP ارسال نشده است.")
    otp_id, token_phone = _decode_otp_token(credentials.credentials)
    phone = _normalize_phone(body.phone)
    if token_phone != phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="شماره با توکن OTP مطابقت ندارد.")
    now = datetime.utcnow()
    async with async_session() as session:
        stmt = (
            select(OTPRequestModel)
            .where(
                OTPRequestModel.id == otp_id,
                OTPRequestModel.phone == phone,
                OTPRequestModel.expires_at >= now,
                OTPRequestModel.verified.is_(False),
            )
            .order_by(OTPRequestModel.id.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        otp_entry = result.scalar_one_or_none()
        if otp_entry is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="کد تایید یافت نشد یا منقضی شده است.")
        if otp_entry.code_hash != _hash_code(body.code):
            otp_entry.attempts += 1
            if otp_entry.attempts >= OTP_MAX_ATTEMPTS:
                otp_entry.expires_at = now
            await session.commit()
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="کد تایید نادرست است.")
        otp_entry.verified = True
        user_result = await session.execute(select(User).where(User.phone == phone))
        user = user_result.scalar_one_or_none()
        if user is None:
            user = User(phone=phone, created_at=now, last_login=now)
            session.add(user)
            await session.flush()
        else:
            user.last_login = now
        token = _issue_jwt(user.id, phone)
        await _register_device_token(user.id, body.device_token, body.device_platform, session)
        await session.commit()
    return OTPVerifyResponse(token=token, user_id=user.id, phone=phone)
@app.post("/agents/tasks", response_model=AgentTaskResponse)
async def create_agent_task_endpoint(body: AgentTaskCreate, current_user: User = Depends(get_current_user)):
    now = datetime.utcnow()
    async with async_session() as session:
        task = AgentTask(
            user_id=current_user.id,
            title=body.title,
            brief=body.brief,
            tone=body.tone,
            audience=body.audience,
            language=body.language,
            outline=_outline_to_text(body.outline),
            word_count=body.word_count,
            status="queued",
            created_at=now,
            updated_at=now,
        )
        session.add(task)
        await session.flush()
        await session.commit()
        await session.refresh(task)
    return _serialize_agent_task(task)
@app.get("/agents/tasks", response_model=List[AgentTaskResponse])
async def list_agent_tasks(current_user: User = Depends(get_current_user)):
    async with async_session() as session:
        stmt = select(AgentTask).where(AgentTask.user_id == current_user.id).order_by(AgentTask.created_at.desc())
        result = await session.execute(stmt)
        tasks = result.scalars().all()
    return [_serialize_agent_task(task) for task in tasks]
@app.get("/agents/tasks/{task_id}", response_model=AgentTaskResponse)
async def get_agent_task(task_id: int, current_user: User = Depends(get_current_user)):
    async with async_session() as session:
        task = await session.get(AgentTask, task_id)
        if task is None or task.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="تسک یافت نشد.")
    return _serialize_agent_task(task)
@app.get("/auth/me", response_model=MeResponse)
async def get_me(current_user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(
        user_id=current_user.id,
        phone=current_user.phone,
        created_at=current_user.created_at,
        last_login=current_user.last_login,
    )
# ═══════════════════════════════════════════════════════════════════
# PHASE 2: DAILY PROGRAM & SMART SCHEDULING ENDPOINTS
# ═══════════════════════════════════════════════════════════════════
@app.post("/user/program/generate", response_model=DailyProgramResponse)
async def generate_daily_program(
    body: DailyProgramGenerateRequest,
    current_user: User = Depends(get_current_user),
):
    """Generate daily program based on profile and current state"""
    async with async_session() as session:
        # Get user profile
        stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        profile = await session.execute(stmt)
        profile_obj = profile.scalar_one_or_none()
        
        if not profile_obj:
            raise HTTPException(status_code=404, detail="پروفایل یافت نشد")
        
        # Get goals, habits, mood
        goals_stmt = select(UserGoal).where(UserGoal.user_id == current_user.id)
        goals_result = await session.execute(goals_stmt)
        goals = goals_result.scalars().all()
        
        habits_stmt = select(Habit).where(Habit.user_id == current_user.id)
        habits_result = await session.execute(habits_stmt)
        habits = habits_result.scalars().all()
        
        # Create program
        from uuid import uuid4
        program_id = str(uuid4())
        
        program = DailyProgram(
            user_id=current_user.id,
            program_id=program_id,
            date=datetime.fromisoformat(body.date.replace('Z', '+00:00')).date() if body.date else datetime.utcnow().date(),
            activities=json.dumps([]),  # Activities will be calculated
            expected_productivity=65.0,
            expected_mood=body.current_mood,
            focus_theme="balanced",
            created_at=datetime.utcnow(),
            generated_at=datetime.utcnow(),
        )
        
        session.add(program)
        await session.commit()
        
        return DailyProgramResponse(
            program_id=program.program_id,
            user_id=current_user.id,
            date=program.date.isoformat(),
            activities=[],
            expected_productivity=program.expected_productivity,
            expected_mood=program.expected_mood,
            focus_theme=program.focus_theme,
            created_at=program.created_at.isoformat(),
        )
@app.get("/user/program/{date}")
async def get_program_for_date(
    date: str,
    current_user: User = Depends(get_current_user),
):
    """Get daily program for specific date"""
    async with async_session() as session:
        try:
            target_date = datetime.fromisoformat(date).date()
        except:
            raise HTTPException(status_code=400, detail="تاریخ نامعتبر است")
        
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == target_date)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه برای این تاریخ یافت نشد")
        
        return DailyProgramResponse(
            program_id=program.program_id,
            user_id=program.user_id,
            date=program.date.isoformat(),
            activities=json.loads(program.activities) if program.activities else [],
            expected_productivity=program.expected_productivity,
            expected_mood=program.expected_mood,
            focus_theme=program.focus_theme,
            is_completed=program.is_completed,
            created_at=program.created_at.isoformat(),
        )
@app.get("/user/program/today")
async def get_today_program(current_user: User = Depends(get_current_user)):
    """Get today's program"""
    async with async_session() as session:
        today = datetime.utcnow().date()
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == today)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه برای امروز یافت نشد")
        
        return DailyProgramResponse(
            program_id=program.program_id,
            user_id=program.user_id,
            date=program.date.isoformat(),
            activities=json.loads(program.activities) if program.activities else [],
            expected_productivity=program.expected_productivity,
            expected_mood=program.expected_mood,
            focus_theme=program.focus_theme,
            is_completed=program.is_completed,
            created_at=program.created_at.isoformat(),
        )
@app.post("/user/program/activity/{activity_id}/complete")
async def complete_activity(
    activity_id: str,
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """Log activity completion"""
    async with async_session() as session:
        # Find program for today
        today = datetime.utcnow().date()
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == today)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه یافت نشد")
        
        # Update program
        program.is_completed = body.get("completed", False)
        program.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "completed", "activity_id": activity_id}
@app.put("/user/program/activity/{activity_id}/reschedule")
async def reschedule_activity(
    activity_id: str,
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """Reschedule activity to different time"""
    async with async_session() as session:
        # Find and update program
        today = datetime.utcnow().date()
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == today)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه یافت نشد")
        
        program.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "rescheduled", "activity_id": activity_id}
@app.post("/user/program/activity/add")
async def add_custom_activity(
    body: ProgramActivityRequest,
    current_user: User = Depends(get_current_user),
):
    """Add custom activity to program"""
    async with async_session() as session:
        today = datetime.utcnow().date()
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == today)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه یافت نشد")
        
        program.updated_at = datetime.utcnow()
        await session.commit()
        
        return {
            "status": "added",
            "activity": {
                "id": str(datetime.utcnow().timestamp()),
                "title": body.title,
                "category": body.category,
            }
        }
@app.delete("/user/program/activity/{activity_id}")
async def delete_activity(
    activity_id: str,
    current_user: User = Depends(get_current_user),
):
    """Remove activity from program"""
    async with async_session() as session:
        today = datetime.utcnow().date()
        stmt = select(DailyProgram).where(
            (DailyProgram.user_id == current_user.id) & 
            (DailyProgram.date == today)
        )
        result = await session.execute(stmt)
        program = result.scalar_one_or_none()
        
        if not program:
            raise HTTPException(status_code=404, detail="برنامه یافت نشد")
        
        program.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"status": "deleted", "activity_id": activity_id}
@app.post("/user/scheduling/analyze", response_model=SchedulingAnalysisResponse)
async def analyze_scheduling(
    body: SchedulingRecommendationRequest,
    current_user: User = Depends(get_current_user),
):
    """Analyze schedule and get recommendations"""
    async with async_session() as session:
        # Get user data
        profile_stmt = select(UserProfile).where(UserProfile.user_id == current_user.id)
        profile = await session.execute(profile_stmt)
        profile_obj = profile.scalar_one_or_none()
        
        if not profile_obj:
            raise HTTPException(status_code=404, detail="پروفایل یافت نشد")
        
        # Create analysis
        from uuid import uuid4
        analysis_id = str(uuid4())
        
        analysis = SchedulingAnalysis(
            user_id=current_user.id,
            analysis_id=analysis_id,
            recommendations=json.dumps([]),
            overall_productivity_score=75.0,
            schedule_health_status="خوب",
            improvements=json.dumps([]),
            created_at=datetime.utcnow(),
        )
        
        session.add(analysis)
        await session.commit()
        
        return SchedulingAnalysisResponse(
            recommendations=[],
            overall_productivity_score=75.0,
            schedule_health_status="خوب",
            improvements=[
                "⚠️ وقت تمرکز کافی نیست",
                "✏️ بیشتر استراحت کنید",
            ],
            generated_at=analysis.created_at.isoformat(),
        )
@app.get("/user/scheduling/recommendations")
async def get_scheduling_recommendations(current_user: User = Depends(get_current_user)):
    """Get latest scheduling recommendations"""
    async with async_session() as session:
        stmt = select(SchedulingAnalysis).where(
            SchedulingAnalysis.user_id == current_user.id
        ).order_by(SchedulingAnalysis.created_at.desc()).limit(1)
        
        result = await session.execute(stmt)
        analysis = result.scalar_one_or_none()
        
        if not analysis:
            raise HTTPException(status_code=404, detail="توصیه‌ای یافت نشد")
        
        return SchedulingAnalysisResponse(
            recommendations=[],
            overall_productivity_score=analysis.overall_productivity_score,
            schedule_health_status=analysis.schedule_health_status,
            improvements=json.loads(analysis.improvements) if analysis.improvements else [],
            generated_at=analysis.created_at.isoformat(),
        )

# ═══════════════════════════════════════════════════════════════════
# TASK MANAGEMENT ENDPOINTS
# ═══════════════════════════════════════════════════════════════════
@app.post("/tasks", response_model=TaskResponse)
async def create_task(body: TaskCreateRequest, current_user: User = Depends(get_current_user)):
    """Create a new task"""
    task_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    async with async_session() as session:
        task = UserTask(
            user_id=current_user.id,
            task_id=task_id,
            title=body.title,
            description=body.description,
            category=body.category,
            priority=body.priority,
            due_date=datetime.fromisoformat(body.due_date) if body.due_date else None,
            estimated_duration_minutes=body.estimated_duration_minutes,
            linked_goal_id=body.linked_goal_id,
            location=body.location,
            subtasks=json.dumps([s.dict() for s in body.subtasks]) if body.subtasks else json.dumps([]),
            tags=json.dumps(body.tags) if body.tags else json.dumps([]),
            created_at=now,
            status="pending"
        )
        session.add(task)
        await session.commit()
        await session.refresh(task)
    
    return TaskResponse(
        task_id=task.task_id,
        title=task.title,
        description=task.description,
        category=task.category,
        status=task.status,
        priority=task.priority,
        due_date=task.due_date,
        scheduled_time=task.scheduled_time,
        estimated_duration_minutes=task.estimated_duration_minutes,
        linked_goal_id=task.linked_goal_id,
        subtasks=json.loads(task.subtasks) if task.subtasks else [],
        location=task.location,
        tags=json.loads(task.tags) if task.tags else [],
        created_at=task.created_at,
        completed_at=task.completed_at,
        reminder_sent=task.reminder_sent
    )

@app.get("/tasks", response_model=TaskListResponse)
async def list_tasks(
    status: Optional[str] = None,
    category: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    """List tasks with filters"""
    async with async_session() as session:
        stmt = select(UserTask).where(UserTask.user_id == current_user.id)
        
        if status:
            stmt = stmt.where(UserTask.status == status)
        if category:
            stmt = stmt.where(UserTask.category == category)
        
        result = await session.execute(
            stmt.order_by(UserTask.due_date.asc(), UserTask.priority.desc())
        )
        tasks = result.scalars().all()
        
        now = datetime.utcnow()
        overdue = sum(1 for t in tasks if t.due_date and t.due_date < now and t.status != "completed")
        today = sum(1 for t in tasks if t.due_date and t.due_date.date() == now.date() and t.status != "completed")
        
        return TaskListResponse(
            total=len(tasks),
            tasks=[
                TaskResponse(
                    task_id=t.task_id,
                    title=t.title,
                    description=t.description,
                    category=t.category,
                    status=t.status,
                    priority=t.priority,
                    due_date=t.due_date,
                    scheduled_time=t.scheduled_time,
                    estimated_duration_minutes=t.estimated_duration_minutes,
                    linked_goal_id=t.linked_goal_id,
                    subtasks=json.loads(t.subtasks) if t.subtasks else [],
                    location=t.location,
                    tags=json.loads(t.tags) if t.tags else [],
                    created_at=t.created_at,
                    completed_at=t.completed_at,
                    reminder_sent=t.reminder_sent
                ) for t in tasks
            ],
            overdue_count=overdue,
            today_count=today
        )

@app.get("/tasks/{task_id}", response_model=TaskResponse)
async def get_task(task_id: str, current_user: User = Depends(get_current_user)):
    """Get specific task details"""
    async with async_session() as session:
        stmt = select(UserTask).where(
            UserTask.task_id == task_id,
            UserTask.user_id == current_user.id
        )
        result = await session.execute(stmt)
        task = result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="تسک یافت نشد")
        
        return TaskResponse(
            task_id=task.task_id,
            title=task.title,
            description=task.description,
            category=task.category,
            status=task.status,
            priority=task.priority,
            due_date=task.due_date,
            scheduled_time=task.scheduled_time,
            estimated_duration_minutes=task.estimated_duration_minutes,
            linked_goal_id=task.linked_goal_id,
            subtasks=json.loads(task.subtasks) if task.subtasks else [],
            location=task.location,
            tags=json.loads(task.tags) if task.tags else [],
            created_at=task.created_at,
            completed_at=task.completed_at,
            reminder_sent=task.reminder_sent
        )

@app.put("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    body: TaskUpdateRequest,
    current_user: User = Depends(get_current_user)
):
    """Update task details"""
    async with async_session() as session:
        stmt = select(UserTask).where(
            UserTask.task_id == task_id,
            UserTask.user_id == current_user.id
        )
        result = await session.execute(stmt)
        task = result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="تسک یافت نشد")
        
        if body.title is not None:
            task.title = body.title
        if body.description is not None:
            task.description = body.description
        if body.status is not None:
            task.status = body.status
            if body.status == "completed":
                task.completed_at = datetime.utcnow()
        if body.priority is not None:
            task.priority = body.priority
        if body.due_date is not None:
            task.due_date = datetime.fromisoformat(body.due_date)
        if body.subtasks is not None:
            task.subtasks = json.dumps([s.dict() for s in body.subtasks])
        if body.notes is not None:
            task.notes = body.notes
        
        task.updated_at = datetime.utcnow()
        await session.commit()
        await session.refresh(task)
        
        return TaskResponse(
            task_id=task.task_id,
            title=task.title,
            description=task.description,
            category=task.category,
            status=task.status,
            priority=task.priority,
            due_date=task.due_date,
            scheduled_time=task.scheduled_time,
            estimated_duration_minutes=task.estimated_duration_minutes,
            linked_goal_id=task.linked_goal_id,
            subtasks=json.loads(task.subtasks) if task.subtasks else [],
            location=task.location,
            tags=json.loads(task.tags) if task.tags else [],
            created_at=task.created_at,
            completed_at=task.completed_at,
            reminder_sent=task.reminder_sent
        )

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: str, current_user: User = Depends(get_current_user)):
    """Delete a task"""
    async with async_session() as session:
        stmt = select(UserTask).where(
            UserTask.task_id == task_id,
            UserTask.user_id == current_user.id
        )
        result = await session.execute(stmt)
        task = result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="تسک یافت نشد")
        
        await session.delete(task)
        await session.commit()
        
        return {"message": "تسک حذف شد"}

@app.post("/tasks/{task_id}/complete")
async def complete_task(task_id: str, current_user: User = Depends(get_current_user)):
    """Mark task as completed"""
    async with async_session() as session:
        stmt = select(UserTask).where(
            UserTask.task_id == task_id,
            UserTask.user_id == current_user.id
        )
        result = await session.execute(stmt)
        task = result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(status_code=404, detail="تسک یافت نشد")
        
        task.status = "completed"
        task.completed_at = datetime.utcnow()
        task.updated_at = datetime.utcnow()
        await session.commit()
        
        return {"message": "تسک تکمیل شد", "completed_at": task.completed_at}

@app.post("/tasks/recurring", response_model=TaskResponse)
async def create_recurring_task(
    body: RecurringTaskRequest,
    current_user: User = Depends(get_current_user)
):
    """Create a recurring task"""
    task_id = str(uuid.uuid4())
    now = datetime.utcnow()
    
    async with async_session() as session:
        # Create main task
        task = UserTask(
            user_id=current_user.id,
            task_id=task_id,
            title=body.title,
            description=body.description,
            category=body.category,
            priority=body.priority,
            estimated_duration_minutes=body.estimated_duration_minutes,
            tags=json.dumps(body.tags) if body.tags else json.dumps([]),
            created_at=now,
            status="pending"
        )
        session.add(task)
        await session.flush()
        
        # Create recurrence pattern
        recurrence = TaskRecurrence(
            task_id=task.id,
            user_id=current_user.id,
            pattern=body.recurrence.pattern,
            frequency=body.recurrence.frequency,
            days_of_week=json.dumps(body.recurrence.days_of_week) if body.recurrence.days_of_week else None,
            end_date=datetime.fromisoformat(body.recurrence.end_date) if body.recurrence.end_date else None,
        )
        session.add(recurrence)
        await session.commit()
        await session.refresh(task)
        
        return TaskResponse(
            task_id=task.task_id,
            title=task.title,
            description=task.description,
            category=task.category,
            status=task.status,
            priority=task.priority,
            due_date=task.due_date,
            scheduled_time=task.scheduled_time,
            estimated_duration_minutes=task.estimated_duration_minutes,
            linked_goal_id=task.linked_goal_id,
            subtasks=[],
            location=task.location,
            tags=json.loads(task.tags) if task.tags else [],
            created_at=task.created_at,
            completed_at=task.completed_at,
            reminder_sent=task.reminder_sent
        )

# ============================================================================
# Suggested Prompts Endpoint
# ============================================================================
SUGGESTED_PROMPTS = {
    "general": [
        "یک برنامه روزانه برای افزایش بهره‌وری بنویس",
        "راه‌های کاهش استرس را توضیح بده",
        "بهترین روش‌های یادگیری برنامه‌نویسی چیست؟",
        "یک دستور پخت ساده پیشنهاد بده",
        "راهنمای شروع کسب‌وکار آنلاین",
    ],
    "coding": [
        "چگونه یک REST API با Python بسازم؟",
        "بهترین practices برای Git چیست؟",
        "تفاوت بین async و sync در JavaScript چیست؟",
        "چگونه یک database schema طراحی کنم؟",
        "بهترین framework برای Flutter چیست؟",
    ],
    "writing": [
        "چگونه یک مقاله جذاب بنویسم؟",
        "ساختار یک داستان کوتاه چیست؟",
        "چگونه محتوای SEO-friendly بنویسم؟",
        "نکات مهم برای نوشتن ایمیل حرفه‌ای",
        "چگونه یک pitch deck بنویسم؟",
    ],
    "research": [
        "تحقیق درباره هوش مصنوعی و آینده آن",
        "تأثیر شبکه‌های اجتماعی بر سلامت روان",
        "راه‌های کاهش آلودگی محیط زیست",
        "تاریخچه و آینده انرژی‌های تجدیدپذیر",
        "تأثیر فناوری بر اقتصاد جهانی",
    ],
}
@app.post("/messages/analyze")
async def analyze_message(body: Dict[str, Any], current_user: User = Depends(get_current_user)):
    """
    تحلیل متن پیام با استخراج نکات مهم، احساسات و الویت
    """
    message_text = body.get("text", "")
    if not message_text:
        raise HTTPException(status_code=400, detail="Text required")
    
    try:
        async with AsyncClient() as client:
            response = await client.create_completion(
                model="gpt-4-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": """شما یک تحلیل‌گر متخصص پیام‌ها هستید.
برای پیام داده شده موارد زیر را استخراج کنید:
1. key_points: نکات اصلی پیام
2. priority: اولویت (high/medium/low)
3. emotions: احساسات درون متن
4. personal_info: اطلاعات شخصی (نام‌ها، تاریخ‌ها، مکان‌ها)
5. action_required: آیا اقدام لازم است؟
پاسخ را به صورت JSON برگردانید.""",
                    },
                    {
                        "role": "user",
                        "content": f"پیام: {message_text}"
                    }
                ],
            )
            
            result_text = response.choices[0].message.content
            # Parse JSON from response
            try:
                result = json.loads(result_text)
            except:
                result = {
                    "key_points": [result_text],
                    "priority": "medium",
                    "emotions": [],
                    "personal_info": {},
                    "action_required": False
                }
            
            return {
                "success": True,
                "analysis": result
            }
    except Exception as e:
        log.error(f"Error analyzing message: {e}")
        return {
            "success": False,
            "error": str(e),
            "analysis": {}
        }
class NotificationTriageRequest(BaseModel):
    notifications: List[Dict[str, Any]]
    mode: str = "default"
    timezone: str = "Asia/Tehran"
@app.post("/notifications/classify")
async def classify_notifications(body: NotificationTriageRequest, current_user: User = Depends(get_current_user)):
    """
    دسته‌بندی اعلان‌ها به مهم/فوری/عادی و ایجاد خلاصه
    """
    try:
        notifications_text = json.dumps(body.notifications, ensure_ascii=False)
        
        async with AsyncClient() as client:
            response = await client.create_completion(
                model="gpt-4-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": """شما یک دستگاه تحلیل اعلان‌های هوشمند هستید.
برای هر اعلان موارد زیر را انجام دهید:
1. Category: critical/important/normal
2. Title: عنوان کوتاه
3. Summary: خلاصه ۲-۳ جمله‌ای
4. Action: اقدام پیشنهادی (اگر لازم است)
همچنین یک خلاصه کلی از اعلان‌های مهم بنویسید.
پاسخ را به صورت JSON برگردانید:
{
    "classified": [
        {"title": "...", "category": "...", "summary": "...", "action": "..."}
    ],
    "summary": "خلاصه کلی"
}""",
                    },
                    {
                        "role": "user",
                        "content": f"اعلان‌ها: {notifications_text}"
                    }
                ],
            )
            
            result_text = response.choices[0].message.content
            try:
                result = json.loads(result_text)
            except:
                result = {
                    "classified": [],
                    "summary": result_text
                }
            
            # شمارش اعلان‌های مهم
            critical_count = sum(
                1 for item in result.get("classified", [])
                if item.get("category", "").lower() in ["critical", "important"]
            )
            
            return {
                "success": True,
                "total": len(body.notifications),
                "critical": critical_count,
                "classified": result.get("classified", []),
                "summary": result.get("summary", "")
            }
    except Exception as e:
        log.error(f"Error classifying notifications: {e}")
        return {
            "success": False,
            "error": str(e),
            "total": 0,
            "critical": 0,
            "classified": [],
            "summary": ""
        }
@app.get("/chat/suggested-prompts")
async def get_suggested_prompts(
    category: Optional[str] = None,
    language: str = "fa",
    limit: int = 5,
    current_user: User = Depends(get_current_user)
):
    """
    برمی‌گرداند لیستی از suggested prompts بر اساس category
    """
    prompts_list = []
    
    if category and category in SUGGESTED_PROMPTS:
        prompts_list = SUGGESTED_PROMPTS[category]
    else:
        # ترکیب همه categories
        for cat_prompts in SUGGESTED_PROMPTS.values():
            prompts_list.extend(cat_prompts)
    
    # محدود کردن به limit
    prompts_list = prompts_list[:limit]
    
    # تبدیل به format مورد نظر
    result = [
        {"text": prompt, "category": category or "general"}
        for prompt in prompts_list
    ]
    
    return {"prompts": result}

"""Request bodies shared by the API routers."""
import math
import time
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from .db import dumps
from .engine import uid

KINDS = Literal['activity', 'safe', 'contact', 'sos', 'away', 'home', 'rest',
                'need_help', 'unreachable', 'data_offline', 'data_online', 'missed_checkin']


class Login(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=200)


class Event(BaseModel):
    id: str = Field(default_factory=lambda: uid('IN'), min_length=1, max_length=100)
    elder_id: int = Field(ge=1)
    kind: KINDS
    observed_at: float | None = None
    source: str = Field(default='人工上报', max_length=80)
    payload: dict = Field(default_factory=dict)

    @field_validator('observed_at')
    @classmethod
    def timestamp_valid(cls, value):
        if value is not None and not 0 < value <= time.time() + 30:
            raise ValueError('时间戳必须有效，且不能晚于当前时间30秒')
        return value

    @field_validator('payload')
    @classmethod
    def bounded_payload(cls, value):
        if len(dumps(value)) > 4000:
            raise ValueError('上报内容过长')
        for key in ('count15', 'count60', 'gap'):
            if key in value and not _within(value[key], 100000):
                raise ValueError('活动数值必须为有限非负数')
        if 'original_timestamp' in value and not _within(value['original_timestamp'], time.time() + 30):
            raise ValueError('原始时间戳必须有效')
        if 'hours' in value and not _within(value['hours'], 24, strict=True):
            raise ValueError('状态确认有效期为0到24小时')
        return value


def _within(value, upper, strict=False):
    """Reject booleans, strings, NaN and infinities before they reach the engine."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        return False
    return 0 < value <= upper if strict else 0 <= value <= upper


class Confirmation(BaseModel):
    recommendation_id: str
    staff_id: int | None = None
    reason: str = Field(default='', max_length=1000)


class Action(BaseModel):
    action: Literal['accept', 'start', 'reject', 'feedback', 'followup', 'close']
    outcome: str = ''
    note: str = Field(default='', max_length=2000)


class WorkerUpdate(BaseModel):
    """Partial worker state: omitted fields keep their stored value."""
    available: bool | None = None
    on_duty: bool | None = None
    location: int | None = Field(default=None, ge=1, le=5)


class ElderProfile(BaseModel):
    name: str = Field(min_length=1, max_length=40)
    age: int = Field(ge=60, le=120)
    building: str = Field(min_length=1, max_length=80)
    contact: str = Field(min_length=1, max_length=80)
    routine: str = Field(default='07:00 起床，22:00 休息', max_length=300)
    checkin_hour: int = Field(default=9, ge=0, le=23)


class Scenario(BaseModel):
    scenario: Literal['story', 'offline', 'away', 'normal', 'cold_start', 'conflict']
    elder_id: int = Field(default=1, ge=1)


class ReplayWindow(BaseModel):
    elder_id: int = Field(ge=1)
    offset: int = Field(default=0, ge=0)


class AssistantMessage(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    session_id: str | None = Field(default=None, max_length=100)
    elder_id: int | None = Field(default=None, ge=1)
    task_id: str | None = Field(default=None, max_length=100)

    @field_validator('message')
    @classmethod
    def nonempty(cls, value):
        if not value.strip():
            raise ValueError('请输入查询内容')
        return value.strip()


class WorkflowSettings(BaseModel):
    auto_dispatch: bool


class McpTokenIn(BaseModel):
    label: str = Field(default='', max_length=60)
    expires_hours: int = Field(default=24, ge=0, le=8760)


class LlmSettingsIn(BaseModel):
    """Admin model settings. A null api_key keeps the stored secret unchanged."""
    enabled: bool = False
    base_url: str = Field(default='', max_length=300)
    model: str = Field(default='', max_length=120)
    api_key: str | None = Field(default=None, max_length=400)
    clear_api_key: bool = False


class LlmTestIn(BaseModel):
    """Optional overrides for the connection probe; null means the saved value."""
    base_url: str | None = Field(default=None, max_length=300)
    model: str | None = Field(default=None, max_length=120)
    api_key: str | None = Field(default=None, max_length=400)


class LlmModelsIn(BaseModel):
    """Optional overrides for listing provider models; null means the saved value."""
    base_url: str | None = Field(default=None, max_length=300)
    api_key: str | None = Field(default=None, max_length=400)

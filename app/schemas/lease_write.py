"""Request bodies for manual lease create / update (Properties UI)."""
from __future__ import annotations

from datetime import date
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class LeaseWriteBody(BaseModel):
    """Property + lease fields saved together (inline editor → Save)."""

    property_name: str = Field(..., min_length=1, description="Display name for the property / unit")
    tenant_name: Optional[str] = None
    tenant_phone: Optional[str] = None
    address_line1: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    lease_start: date
    lease_end: date
    monthly_rent: int = Field(..., ge=1)
    security_deposit: Optional[int] = Field(None, ge=0)
    lock_in_period: Optional[int] = Field(None, ge=0)
    due_day: int = Field(1, ge=1, le=31)


class LeaseDraftPatchBody(BaseModel):
    """Partial update for `user_lease_drafts` (merge with existing draft)."""

    model_config = ConfigDict(extra="ignore")

    property_name: Optional[str] = None
    tenant_name: Optional[str] = None
    tenant_phone: Optional[str] = None
    address_line1: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    lease_start: Optional[date] = None
    lease_end: Optional[date] = None
    monthly_rent: Optional[int] = Field(None, ge=1)
    security_deposit: Optional[int] = Field(None, ge=0)
    lock_in_period: Optional[int] = Field(None, ge=0)
    due_day: Optional[int] = Field(None, ge=1, le=31)

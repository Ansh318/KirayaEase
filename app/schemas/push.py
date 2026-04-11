"""FCM device registration for push notifications."""

from typing import Literal

from pydantic import BaseModel, Field


class FcmTokenBody(BaseModel):
    fcm_token: str = Field(..., min_length=10, description="FCM registration token from the client")
    platform: str = Field("ios", description="ios | android")

    def normalized_platform(self) -> str:
        p = (self.platform or "ios").strip().lower()
        return p if p in ("ios", "android") else "ios"


class LandlordPushPreviewBody(BaseModel):
    """Preview the same FCM shape as production landlord pushes (no DB idempotency)."""

    variant: Literal[
        "rent_due_soon",
        "rent_overdue",
        "payment_confirmed",
        "lease_expiring",
    ] = Field(..., description="Which landlord template to send")

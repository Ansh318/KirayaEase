"""FCM device registration for push notifications."""

from pydantic import BaseModel, Field


class FcmTokenBody(BaseModel):
    fcm_token: str = Field(..., min_length=10, description="FCM registration token from the client")
    platform: str = Field("ios", description="ios | android")

    def normalized_platform(self) -> str:
        p = (self.platform or "ios").strip().lower()
        return p if p in ("ios", "android") else "ios"

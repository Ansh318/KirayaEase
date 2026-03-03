# app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    RAZORPAY_TEST_KEY_ID: str
    RAZORPAY_KEY_SECRET: str

settings = Settings()
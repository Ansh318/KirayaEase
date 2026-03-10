from langchain_core.tools import tool

from langchain_core.messages import HumanMessage, AIMessage, ToolMessage
from dotenv import load_dotenv
from app.services.lease_extractor import extract_from_pdf
import json
import requests
from app.schemas.property_manager import PropertyManager
from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager



@tool
def invite_tenant(phone_number: str):
    "Send tenant an invite to onboard onto their apartment"
    url = "https://graph.facebook.com/v22.0/1038342679352534/messages"
    access_token = "EAFxBVnL8gzYBQ8uZA34o6FIni23cQTdI9ZCv0lrdSw6rLhqXZAZAKcEoZBucEjzlOZAZATBdgWHNpWYH8r0CiiqPO1s7M8L3OrZAUsVV5CtNPXAEFsu10B67d9E0hKYVq2K3gvzWZCZCgddgZAqZAXE7bRZA7bmbJMDX6vrPSZA434OkevGwV2pAVi8vkWDLD7ooStvvraLASLpfkaYNwVYQHfyVW24wnMA9zO9RevtXsrEKeTjCsGPWA1kzq5PXSIlPa0XQHoKroL1vSka5VMZCBiQI9qlnpeY"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "to": phone_number,
        "type": "template",
        "template": {
            "name": "hello_world",
            "language": {"code": "en_US"}
        }
    }
    response = requests.post(url, headers=headers, json=payload)
    return response.json()



from langchain_core.tools import tool

from langchain_core.messages import HumanMessage, AIMessage, ToolMessage
from dotenv import load_dotenv
from app.services.lease_extractor import extract_from_pdf
import json
import requests
from app.schemas.property_manager import PropertyManager
from app.core.state import AgentState
from app.core.modelConfig import ModelConfigManager
llm = ModelConfigManager('gpt-4o-mini', 0, 3).model()

@tool
def extract_lease_details(pdf_path: str) -> str:
    """Extracts lease details from a PDF file"""
    result = extract_from_pdf(pdf_path)
    return json.dumps(result, ensure_ascii=False, indent=2)

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


@tool
def create_property(
    owner_id: int,
    landlord_name: str,
    property_name: str,
    address_line1: str | None = None,
    city: str | None = None,
    state: str | None = None,
    postal_code: str | None = None,
) -> dict:
    """Create a property record in the database for the landlord"""
    created = PropertyManager().add_property(
        owner_id=owner_id,
        landlord_name=landlord_name,
        name=property_name,
        address_line1=address_line1,
        city=city,
        state=state,
        postal_code=postal_code,
    )

    return {
        "property_id": created.get("id"),
        "property": created,
        "status": "success",
    }
    
# Bind tools ONCE at module level

def onboarding_agent(state: AgentState) -> dict:
    """Run onboarding agent and return messages."""

    system_prompt = """
    You are an onboarding agent.

    Responsibilities:
    1. Extract lease details from uploaded documents.
    2. Invite tenants when required.
    3. Create and store property records.
    4. Always use tools when performing structured operations.
    5. Never fabricate database records.
    """

    messages = [
        {"role": "system", "content": system_prompt},
        *state["messages"]
    ]
    onboarding_llm = llm.bind_tools([
    extract_lease_details,
    invite_tenant,
    create_property
])


    response = onboarding_llm.invoke(messages)

    return {
        "messages": [response]
    }
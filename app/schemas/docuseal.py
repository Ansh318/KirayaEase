from typing import Optional

from pydantic import BaseModel, Field


class DocusealSigningRequest(BaseModel):
    """Start DocuSeal e-sign for a lease PDF already stored in `lease_files`."""

    tenant_email: str = Field(..., min_length=3, max_length=320)
    tenant_name: Optional[str] = None
    landlord_email: Optional[str] = Field(None, max_length=320)
    landlord_name: Optional[str] = None
    send_email: bool = True
    shared_link: bool = Field(
        True,
        description="Request shareable signing links (embed_src) for WhatsApp; see DOCUSEAL_SUBMISSION_SHARED_LINK env default.",
    )
    completed_redirect_url: Optional[str] = None

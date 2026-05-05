"""Send sample SMTP custom HTML emails for quick visual QA."""

from __future__ import annotations

import argparse

from dotenv import load_dotenv

from app.services.email_service import send_html_email
from app.utils.templates import (
    render_rent_due_email_html,
    render_tenant_welcome_email_html,
)


def main() -> int:
    load_dotenv()
    parser = argparse.ArgumentParser(description="Send test welcome/rent emails")
    parser.add_argument("--to", default="aragarwal@wisc.edu", help="Recipient email")
    args = parser.parse_args()

    to_email = args.to.strip()
    if not to_email:
        print("Missing recipient email")
        return 1

    welcome_html = render_tenant_welcome_email_html(
        tenant_name="Ansh",
        apt_name="Bina Tension Apartments",
        email=to_email,
    )
    rent_html = render_rent_due_email_html(
        tenant_name="Ansh",
        apt_name="Bina Tension Apartments",
        due_date="5 May 2026",
        amount="₹22,000",
        email=to_email,
    )

    r1 = send_html_email(
        to_email=to_email,
        subject="Welcome to Bina Tension Apartments",
        html_body=welcome_html,
    )
    r2 = send_html_email(
        to_email=to_email,
        subject="Rent reminder: Bina Tension Apartments",
        html_body=rent_html,
    )

    print({"welcome": r1, "rent_due": r2})
    return 0 if r1.get("ok") and r2.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())


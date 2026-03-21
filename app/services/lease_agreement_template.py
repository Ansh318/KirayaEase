"""Default residential lease agreement structure (LLM follows this unless the user overrides via reference_prompt)."""

DEFAULT_LEASE_AGREEMENT_TEMPLATE = """
RESIDENTIAL LEASE AGREEMENT

1. PARTIES
   - Lessor (Landlord) and Lessee (Tenant) — insert names and contact details from FACTS.

2. PROPERTY
   - Description of the demised premises, address, and permitted use (residential).

3. TERM
   - Lease start and end dates from FACTS; renewal / notice period if applicable.

4. RENT AND DEPOSIT
   - Monthly rent in INR, due date (day of month), mode of payment, late payment if any.
   - Security deposit amount and refund conditions from FACTS.

5. UTILITIES AND MAINTENANCE
   - Who pays utilities; minor repairs vs major structural repairs.

6. USE AND RESTRICTIONS
   - Quiet enjoyment; no illegal use; subletting only with written consent unless stated otherwise.

7. TERMINATION
   - End of term; notice period for termination; lock-in period from FACTS if any.

8. GOVERNING LAW
   - Laws of India; jurisdiction for disputes (city/state from property FACTS where reasonable).

9. GENERAL
   - Entire agreement; amendments in writing; severability.

10. SIGNATURES
   - Place for Landlord and Tenant names, dates, and signature lines.

DISCLAIMER (include verbatim near the top or bottom):
"This document is generated for convenience and record-keeping in KirayaEase. It is not legal advice
and may not comply with all local laws. The parties should consult a qualified lawyer before signing."
""".strip()

"""Central registry of all agent tools. Single place to add/remove tools for the graph."""
from app.agents.lease.lease_tools import (
    add_lease,
    create_property,
    extract_lease_details,
    finalize_lease_creation,
    generate_lease_agreement,
    inquire_lease,
    open_lease_agreement_widget,
    prepare_lease_draft,
    save_generated_lease_agreement,
    send_lease_for_signature_docuseal,
    store_lease,
)
from app.agents.onboarding.onboard_tools import invite_tenant
from app.agents.insights.insights_tools import fetch_rent_data
from app.agents.rent.rent_tools import (
    confirm_rent_payment,
    list_pending_rents,
    send_rent_reminder_whatsapp,
    set_tenant_whatsapp_phone,
)
from app.agents.portfolio.portfolio_tools import get_my_properties, get_my_leases
from app.agents.memory.memory_tools import remember_user_fact


def get_all_tools():
    """Return the list of tools used by the orchestrator and tool node."""
    return [
        # Lease
        store_lease,
        extract_lease_details,
        inquire_lease,
        create_property,
        add_lease,
        prepare_lease_draft,
        open_lease_agreement_widget,
        generate_lease_agreement,
        save_generated_lease_agreement,
        finalize_lease_creation,
        send_lease_for_signature_docuseal,
        # Portfolio
        get_my_properties,
        get_my_leases,
        # Rent & insights
        fetch_rent_data,
        list_pending_rents,
        confirm_rent_payment,
        send_rent_reminder_whatsapp,
        set_tenant_whatsapp_phone,
        # Onboarding
        invite_tenant,
        # Memory
        remember_user_fact,
    ]

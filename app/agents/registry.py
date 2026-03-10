"""Central registry of all agent tools. Single place to add/remove tools for the graph."""
from app.agents.lease.lease_tools import (
    add_lease,
    create_property,
    extract_lease_details,
    inquire_lease,
    store_lease,
)
from app.agents.onboarding.onboard_tools import invite_tenant
from app.agents.insights.insights_tools import fetch_rent_data
from app.agents.rent.rent_tools import confirm_rent_payment, list_pending_rents
from app.agents.portfolio.portfolio_tools import get_my_properties, get_my_leases


def get_all_tools():
    """Return the list of tools used by the orchestrator and tool node."""
    return [
        # Lease
        store_lease,
        extract_lease_details,
        inquire_lease,
        create_property,
        add_lease,
        # Portfolio
        get_my_properties,
        get_my_leases,
        # Rent & insights
        fetch_rent_data,
        list_pending_rents,
        confirm_rent_payment,
        # Onboarding
        invite_tenant,
    ]

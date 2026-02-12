try:
    # Newer LangChain API
    from langchain.agents import create_agent
except ImportError:
    # Backward-compatible fallback for deployments with older LangChain.
    from langchain.agents import initialize_agent, AgentType
    from langchain_core.messages import AIMessage

    class _CompatAgentWrapper:
        def __init__(self, llm, tools):
            self._agent = initialize_agent(
                tools=tools,
                llm=llm,
                agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
                verbose=False,
                handle_parsing_errors=True,
            )

        def invoke(self, payload):
            query = ""
            messages = payload.get("messages", [])
            if messages:
                query = getattr(messages[-1], "content", "") or ""

            # initialize_agent returns {'output': ...} for invoke()
            result = self._agent.invoke({"input": query})
            output = result.get("output", "")
            return {"messages": [HumanMessage(content=query), AIMessage(content=output)]}

    def create_agent(llm, tools):
        return _CompatAgentWrapper(llm, tools)

from langgraph.graph import START, END, StateGraph
from typing import TypedDict, Literal, Annotated
import os
import json
import uuid
import re
from modelConfig import ModelConfigManager
from langchain_core.tools import tool 
from langchain_core.messages import HumanMessage
import lease_extractor
from duckduckgo_search import DDGS
import razorpay
from dotenv import load_dotenv

load_dotenv()

# --- Tools ---
@tool
def extract_lease_details(pdf_path: str) -> str:
    """
    Extracts lease details from a PDF file.
    
    Args:
        pdf_path: The file path to the PDF lease document
        
    Returns:
        JSON string with extracted lease details including landlord info, tenant info, property details, dates, and rent amount.
    """
    try:
        result = lease_extractor.extract_from_pdf(pdf_path)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return json.dumps({
            "error": str(e),
            "message": f"Failed to extract lease details: {str(e)}"
        }, indent=2)

@tool
def web_search(query: str) -> str:
    """Searches the web for current information about property prices, market trends, rental rates, and real estate insights. Use this to get up-to-date information about property values, rental trends, and market data."""
    try:
        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=5))
            if not results:
                return "No search results found."
            
            # Format results as a readable string
            formatted_results = []
            for i, result in enumerate(results, 1):
                formatted_results.append(
                    f"{i}. {result.get('title', 'No title')}\n"
                    f"   URL: {result.get('href', 'No URL')}\n"
                    f"   {result.get('body', 'No description')}\n"
                )
            return "\n".join(formatted_results)
    except Exception as e:
        return f"Error performing web search: {str(e)}"

@tool
def process_payments(amount_in_rupees: float, receipt_id: str = "", currency: str = "INR", payment_capture: bool = True) -> str:
    """Processes rent payments by creating a Razorpay payment order. 
    
    Args:
        amount_in_rupees: The payment amount in Indian Rupees (e.g., 50000 for ₹50,000)
        receipt_id: Optional receipt/transaction ID for tracking (default: auto-generated if empty)
        currency: Currency code (default: INR)
        payment_capture: Whether to auto-capture payment (default: True)
    
    Returns:
        JSON string with order details including order_id, amount, and status, or error message.
    """
    try:
        # Use fallback credentials if env vars not set
        razorpay_key_id = os.getenv("RAZORPAY_TEST_KEY_ID") or "rzp_test_v4oAPsjPGsrOQR"
        razorpay_key_secret = os.getenv("RAZORPAY_KEY_SECRET") or "wnbpXVnrlLqyhDruEbsgBCja"
        
        razorpay_client = razorpay.Client(
            auth=(razorpay_key_id, razorpay_key_secret)
        )
        
        # Generate receipt_id if not provided or empty
        if not receipt_id or receipt_id.strip() == "":
            receipt_id = f"txn_{uuid.uuid4().hex[:8]}"
        
        order_data = {
            "amount": int(amount_in_rupees * 100),  # Convert to paise
            "currency": currency,
            "receipt": receipt_id,
            "payment_capture": int(payment_capture)
        }
        
        order = razorpay_client.order.create(data=order_data)
        return json.dumps({
            "status": "success",
            "order_id": order.get("id"),
            "amount": order.get("amount"),
            "amount_in_rupees": amount_in_rupees,
            "currency": order.get("currency"),
            "receipt": order.get("receipt"),
            "order_status": order.get("status"),  # Renamed to avoid overwriting "status"
            "message": f"Payment order created successfully. Order ID: {order.get('id')}"
        }, indent=2)
    except Exception as e:
        return json.dumps({
            "status": "error",
            "error": str(e),
            "message": f"Failed to process payment: {str(e)}"
        }, indent=2)

# --- Define State with Shared Fields ---
class AgentState(TypedDict):
    user_query: str
    answer: str
    user_role: Annotated[str, "Current user role (tenant or landlord)"]
    active_scope: Annotated[str, "Current context scope (self, portfolio, tenant)"]
    active_tenant_id: Annotated[str | None, "Selected tenant identifier when in tenant scope"]
    # Shared state fields for agent collaboration
    lease_id: Annotated[str | None, "Lease identifier for tracking"]
    tenant: Annotated[str | None, "Tenant name or identifier"]
    rent: Annotated[float | None, "Rent amount"]
    payment_status: Annotated[str | None, "Payment status (pending, paid, overdue, etc.)"]
    # Agent communication
    next_agent: Annotated[str | None, "Next agent to call (for agent-to-agent communication)"]
    agent_history: Annotated[list, "History of agents that have been called"]
    # Conversation memory
    conversation_history: Annotated[list, "Previous conversation messages for context"]
    # Payment order info for frontend
    payment_order_id: Annotated[str | None, "Razorpay order ID for opening payment widget"]
    payment_amount: Annotated[int | None, "Payment amount in paise"]

class RentWiseAssistant:
    """
    Agentic chatbot assistant for lease management using LangGraph.
    Routes queries to specialized agents: lease, reminder, insights, and payments.
    """
    
    def __init__(self, model_name: str = "gpt-4o-mini", temperature: float = 0, max_retries: int = 3):
        """
        Initialize the RentWise Assistant with agentic framework.
        
        Args:
            model_name: Name of the LLM model to use
            temperature: Temperature for the LLM
            max_retries: Maximum retries for LLM calls
        """
        self.model_name = model_name
        self.temperature = temperature
        self.max_retries = max_retries

        # Initialize LLM
        self.llm = ModelConfigManager(model_name, temperature, max_retries).model()
        
        # Initialize agent docs (will be populated after agents are defined)
        self.agent_docs = {}
        
        # Conversation memory: session_id -> conversation history
        # Format: [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
        self.conversation_memory: dict[str, list] = {}
        
        # Build and compile the graph
        self.app = self._build_graph()
    
    def _build_graph(self):
        """Build and compile the LangGraph workflow with orchestrator and agent-to-agent communication"""
        workflow = StateGraph(AgentState)
        
        # Add all nodes
        workflow.add_node("router_agent", self._router_agent)
        workflow.add_node("orchestrator", self._orchestrator)
        workflow.add_node("lease_agent", self._lease_agent)
        workflow.add_node("reminder_agent", self._reminder_agent)
        workflow.add_node("insights_agent", self._insights_agent)
        workflow.add_node("payments_agent", self._payments_agent)
        workflow.add_node("onboarding_agent", self._onboarding_agent)
        
        # Define the flow
        workflow.add_edge(START, "router_agent")
        workflow.add_edge("router_agent", "orchestrator")
        
        # Orchestrator routes to agents, and agents can route back to orchestrator for agent-to-agent calls
        workflow.add_conditional_edges("orchestrator", self._orchestrator_logic)
        
        # Agents can call back to orchestrator if they need to call another agent, otherwise end
        workflow.add_conditional_edges("lease_agent", lambda s: "orchestrator" if s.get("next_agent") else END)
        workflow.add_conditional_edges("reminder_agent", lambda s: "orchestrator" if s.get("next_agent") else END)
        workflow.add_conditional_edges("insights_agent", lambda s: "orchestrator" if s.get("next_agent") else END)
        workflow.add_conditional_edges("payments_agent", lambda s: "orchestrator" if s.get("next_agent") else END)
        workflow.add_conditional_edges("onboarding_agent", lambda s: "orchestrator" if s.get("next_agent") else END)
        
        return workflow.compile()

    def _context_hint(self, state: AgentState) -> str:
        """Builds a concise context hint used by agents and router."""
        role = (state.get("user_role") or "tenant").lower()
        scope = (state.get("active_scope") or "self").lower()
        tenant_id = state.get("active_tenant_id")

        if role == "landlord":
            if scope == "portfolio":
                return (
                    "User role is landlord and current scope is portfolio (all tenants). "
                    "Portfolio-level summaries are allowed. For tenant-specific actions "
                    "(collect payment, reminders, lease changes), ask the user to select a tenant scope."
                )
            if scope == "tenant":
                return (
                    f"User role is landlord and scope is a specific tenant ({tenant_id or 'unknown tenant id'}). "
                    "Proceed with tenant-specific operations for the selected tenant."
                )
            return "User role is landlord."

        return "User role is tenant. Respond for self-service tenant workflows."
    
    def _orchestrator_logic(self, state: AgentState) -> Literal["lease_agent", "reminder_agent", "insights_agent", "payments_agent", "onboarding_agent", END]:
        """
        Orchestrator that coordinates between agents and allows agent-to-agent communication.
        Checks if an agent has requested to call another agent, otherwise routes to the appropriate agent.
        """
        # If router agent already provided an answer (for simple queries), end here
        if state.get('answer') and state.get('answer') != '':
            # Check if router handled it directly (simple greetings, etc.)
            if 'agent_history' not in state or len(state.get('agent_history', [])) == 0:
                return END
        
        # Check if an agent has requested to call another agent
        if state.get("next_agent") and state["next_agent"] in ["lease_agent", "reminder_agent", "insights_agent", "payments_agent", "onboarding_agent"]:
            next_agent = state["next_agent"]
            # Clear the next_agent flag
            state["next_agent"] = None
            return next_agent
        
        # If no agent-to-agent call requested, use routing logic
        return self._routing_logic(state)
    
    def _routing_logic(self, state: AgentState) -> Literal["lease_agent", "reminder_agent", "insights_agent", "payments_agent", "onboarding_agent"]:
        """
        Uses the LLM to choose between agents based on the intent of the user query.
        """
        prompt = f"""
        You are a router agent. Your task is to choose the best agent for the job.
        Here is the user query: {state['user_query']}
        Context hint: {self._context_hint(state)}

        You can choose from the following agents:
        - lease_agent: {self.agent_docs.get('lease_agent', 'Handles lease-related queries and document processing')}
        - reminder_agent: {self.agent_docs.get('reminder_agent', 'Handles reminders for rent payments, and important dates')}
        - insights_agent: {self.agent_docs.get('insights_agent', 'Handles quantitative insights about the property and pricing recommendations')}
        - payments_agent: {self.agent_docs.get('payments_agent', 'Handles rent payment processing and payment-related queries')}
        - onboarding_agent: {self.agent_docs.get('onboarding_agent', 'Handles user onboarding, profile setup, KYC verification, and account setup queries')}

        Which agent should handle this query? Respond with just the agent name (either "lease_agent", "reminder_agent", "insights_agent", "payments_agent", or "onboarding_agent").
        """
        response = self.llm.invoke(prompt)
        decision = response.content.strip().lower()
        
        # Parse the response to determine which agent to route to
        if "lease" in decision:
            return "lease_agent"
        elif "reminder" in decision:
            return "reminder_agent"
        elif "insights" in decision:
            return "insights_agent"
        elif "payment" in decision:
            return "payments_agent"
        elif "onboard" in decision:
            return "onboarding_agent"
        else:
            # Default to lease_agent if unclear
            return "lease_agent"
    
    def _router_agent(self, state: AgentState) -> AgentState:
        """
        Router agent that passes through the user query.
        Handles simple greetings and general questions directly without routing to agents.
        Uses conversation history for context.
        """
        query_lower = state["user_query"].lower().strip()
        conversation_history = state.get("conversation_history", [])
        
        # Check conversation history for context
        # If user previously mentioned "upload" and now says something related, provide context
        if conversation_history:
            recent_messages = conversation_history[-4:]  # Last 2 exchanges
            recent_text = " ".join([msg.get("content", "").lower() for msg in recent_messages])
            
            # If user previously mentioned upload/lease and now says something short, assume continuation
            if "upload" in recent_text or "lease" in recent_text:
                if len(query_lower.split()) <= 3 and query_lower not in ["help", "onboarding", "kyc", "lease", "payment", "reminder"]:
                    # This might be a continuation - let agents handle it with context
                    pass
        
        # Handle simple greetings directly
        simple_greetings = ["hi", "hello", "hey", "hi there", "hello there", "hey there"]
        if query_lower in simple_greetings or query_lower in [g + "!" for g in simple_greetings]:
            state['answer'] = "Hello! 👋 How can I help you today?"
            return state
        
        # Handle simple "how are you" type questions
        if any(phrase in query_lower for phrase in ["how are you", "how's it going", "what's up"]):
            state['answer'] = "I'm doing great, thanks! How can I assist you with your rental needs?"
            return state
        
        # Handle simple "thanks" or "thank you"
        if any(phrase in query_lower for phrase in ["thank", "thanks"]):
            state['answer'] = "You're welcome! 😊 Is there anything else I can help with?"
            return state
        
        # If it's a very short query that doesn't need an agent, handle it directly
        if len(query_lower.split()) <= 3 and query_lower not in ["help", "onboarding", "kyc", "lease", "payment", "reminder"]:
            # Check if it's a question that needs an agent
            needs_agent = any(keyword in query_lower for keyword in [
                "lease", "rent", "payment", "pay", "reminder", "insight", "price", "market",
                "onboarding", "kyc", "profile", "setup", "verify"
            ])
            if not needs_agent:
                # Simple direct response
                state['answer'] = "I'm here to help! You can ask me about leases, payments, reminders, or onboarding. What would you like to know?"
                return state
        
        return state
    
    def _orchestrator(self, state: AgentState) -> AgentState:
        """
        Orchestrator agent that coordinates between agents and manages agent-to-agent communication.
        Checks if agents need to call each other and routes accordingly.
        """
        # Log the orchestration
        if 'agent_history' in state and state['agent_history']:
            print(f"Agent history: {' → '.join(state['agent_history'])}")
        
        # The orchestrator doesn't modify the state, just passes through
        # The routing logic handles the actual routing
        return state
    
    def _lease_agent(self, state: AgentState) -> AgentState:
        """
        Handles lease-related queries including lease document processing and extraction.
        Can call other agents (payments_agent, reminder_agent, insights_agent) if needed.
        For file uploads, provides simple confirmation that the lease was added.
        Uses conversation history for context.
        """
        # Initialize agent history if not present
        if 'agent_history' not in state:
            state['agent_history'] = []
        state['agent_history'].append('lease_agent')
        
        conversation_history = state.get("conversation_history", [])
        query_lower = state["user_query"].lower()
        
        # Build context from conversation history
        context = f"\nContext hint:\n{self._context_hint(state)}\n"
        if conversation_history:
            # Get last few messages for context
            recent = conversation_history[-4:]  # Last 2 exchanges
            context_parts = []
            for msg in recent:
                role = msg.get("role", "")
                content = msg.get("content", "")
                if role == "user":
                    context_parts.append(f"User: {content}")
                elif role == "assistant":
                    context_parts.append(f"Assistant: {content}")
            if context_parts:
                context = "\nPrevious conversation:\n" + "\n".join(context_parts) + "\n"
        
        # Check if user previously mentioned "upload" and now is providing file or asking about it
        if conversation_history:
            recent_text = " ".join([msg.get("content", "").lower() for msg in conversation_history[-4:]])
            if "upload" in recent_text and (len(query_lower.split()) <= 3 or "file" in query_lower or "document" in query_lower):
                # User is likely continuing the upload conversation
                state['answer'] = "Great! Please upload your lease document using the file attachment button. I'll extract and process it for you."
                return state
        
        # Check if this is a confirmation request (lease already extracted and saved)
        if ("uploaded" in query_lower and "extracted" in query_lower and "saved" in query_lower) or \
           ("processed" in query_lower and "saved" in query_lower):
            # This is a confirmation request - provide confirmation and generate tenant onboarding link
            # Extract tenant info from state if available
            tenant_name = state.get('tenant', 'the tenant')
            
            # Generate placeholder onboarding link
            lease_id = state.get('lease_id', f"lease_{hash(state['user_query']) % 10000}")
            onboarding_link = f"https://kirayaease.com/onboard/{lease_id}"
            
            state['answer'] = f"Perfect! I've extracted and saved the lease details. Here's the tenant onboarding link you can share:\n\n{onboarding_link}\n\nThe tenant can use this link to complete their onboarding and KYC verification."
        else:
            # Regular lease query - use the agent with tools, include context
            query_with_context = state["user_query"]
            if context:
                query_with_context = f"{context}\nCurrent query: {state['user_query']}"
            
            agent = create_agent(self.llm, [extract_lease_details])
            result = agent.invoke({"messages": [HumanMessage(content=query_with_context)]})
            state['answer'] = result["messages"][-1].content
        
        # Extract and store lease information in shared state
        answer_lower = state['answer'].lower()
        if 'rent' in answer_lower or 'lease' in answer_lower:
            # Store extracted information in shared state
            if state.get('lease_id') is None:
                state['lease_id'] = f"lease_{hash(state['user_query']) % 10000}"
            if 'tenant' in answer_lower and state.get('tenant') is None:
                state['tenant'] = "Tenant"  # Would extract from actual response
            # Try to extract rent amount
            rent_match = re.search(r'₹?\s*(\d+(?:,\d+)*)', state['answer'])
            if rent_match and state.get('rent') is None:
                rent_str = rent_match.group(1).replace(',', '')
                try:
                    state['rent'] = float(rent_str)
                except:
                    pass
        
        # Check if we need to call another agent based on the query or extracted data
        query_lower = state['user_query'].lower()
        if 'payment' in query_lower or 'pay' in query_lower:
            state['next_agent'] = 'payments_agent'
        elif 'reminder' in query_lower or 'remind' in query_lower:
            state['next_agent'] = 'reminder_agent'
        elif 'insight' in query_lower or 'price' in query_lower or 'market' in query_lower:
            state['next_agent'] = 'insights_agent'
        
        return state
    
    def _reminder_agent(self, state: AgentState) -> AgentState:
        """
        Handles reminders for rent payments, lease renewals, and important dates.
        Can access shared state (lease_id, tenant, rent) and call other agents if needed.
        """
        # Initialize agent history if not present
        if 'agent_history' not in state:
            state['agent_history'] = []
        state['agent_history'].append('reminder_agent')
        
        # Build context from shared state
        context = f"\nContext hint: {self._context_hint(state)}"
        if state.get('lease_id'):
            context += f"\nLease ID: {state['lease_id']}"
        if state.get('tenant'):
            context += f"\nTenant: {state['tenant']}"
        if state.get('rent'):
            context += f"\nRent Amount: ₹{state['rent']:,.0f}"
        if state.get('payment_status'):
            context += f"\nPayment Status: {state['payment_status']}"
        
        prompt = f"""You are a reminder assistant for lease management. Help the user with reminders,
        notifications, and scheduling related to rent payments, lease renewals, and important dates.
        
        User query: {state['user_query']}
        {context}
        
        Provide a helpful response about setting reminders, checking upcoming dates, or managing notifications.
        Use the shared state information if available."""
        response = self.llm.invoke(prompt)
        state['answer'] = response.content.strip()
        
        # Update payment status if reminder is about overdue payment
        if 'overdue' in state['answer'].lower() or 'late' in state['answer'].lower():
            state['payment_status'] = 'overdue'
        
        # Check if we need to call another agent
        query_lower = state['user_query'].lower()
        if 'payment' in query_lower or 'pay' in query_lower:
            state['next_agent'] = 'payments_agent'
        elif 'insight' in query_lower or 'price' in query_lower:
            state['next_agent'] = 'insights_agent'
        
        return state
    
    def _insights_agent(self, state: AgentState) -> AgentState:
        """
        Provides quantitative insights about the property and pricing recommendations.
        Uses web search to get current market data and trends.
        Can access shared state (rent, lease_id) for context.
        """
        # Initialize agent history if not present
        if 'agent_history' not in state:
            state['agent_history'] = []
        state['agent_history'].append('insights_agent')
        
        # Build context from shared state
        context = f"\nContext hint: {self._context_hint(state)}"
        if state.get('rent'):
            context += f"\nCurrent Rent: ₹{state['rent']:,.0f}"
        if state.get('lease_id'):
            context += f"\nLease ID: {state['lease_id']}"
        
        query_with_context = state["user_query"] + context
        
        # Use create_agent with web_search tool for ReAct-style reasoning
        agent = create_agent(self.llm, [web_search])
        result = agent.invoke({"messages": [HumanMessage(content=query_with_context)]})
        state['answer'] = result["messages"][-1].content
        
        # Insights agent typically doesn't call other agents, but can if needed
        return state
    
    def _payments_agent(self, state: AgentState) -> AgentState:
        """
        Handles rent payment processing and payment-related queries.
        Uses the process_payments tool to create Razorpay payment orders.
        Can access shared state (rent, lease_id, tenant) and call reminder_agent.
        """
        # Initialize agent history if not present
        if 'agent_history' not in state:
            state['agent_history'] = []
        state['agent_history'].append('payments_agent')
        
        query_lower = state["user_query"].lower()
        user_role = (state.get("user_role") or "tenant").lower()
        active_scope = (state.get("active_scope") or "self").lower()

        payment_keywords = ["pay", "payment", "rent", "rupees", "₹", "rs"]
        has_payment_intent = any(keyword in query_lower for keyword in payment_keywords)

        # Guardrail: landlord in portfolio scope should choose a tenant for tenant-specific actions.
        if user_role == "landlord" and active_scope == "portfolio" and has_payment_intent:
            state['answer'] = (
                "You're in portfolio view right now. Please select a specific tenant first, "
                "then I can create the rent payment order for that tenant."
            )
            return state
        
        # Extract amount from query (e.g., "pay 3000 rent", "pay ₹5000", "3000 rupees")
        amount = None
        import re
        # Look for numbers followed by "rent", "rupees", "rs", "₹", or standalone numbers
        amount_patterns = [
            r'pay\s+(?:₹|rs\.?|rupees?)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
            r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupees?|rs\.?|₹)?\s*(?:rent|payment)?',
            r'₹\s*(\d+(?:,\d+)*(?:\.\d+)?)',
        ]
        
        for pattern in amount_patterns:
            match = re.search(pattern, query_lower)
            if match:
                amount_str = match.group(1).replace(',', '')
                try:
                    amount = float(amount_str)
                    break
                except:
                    pass
        
        # If no amount found in query, use rent from shared state
        if amount is None and state.get('rent'):
            amount = state['rent']
        
        # Build context from shared state
        context = ""
        if state.get('rent'):
            context += f"\nRent Amount: ₹{state['rent']:,.0f}"
        if state.get('lease_id'):
            context += f"\nLease ID: {state['lease_id']}"
        if state.get('tenant'):
            context += f"\nTenant: {state['tenant']}"
        
        # If amount is found, create payment order directly
        if amount and amount > 0:
            try:
                # Use the process_payments tool directly
                payment_result = process_payments.invoke({
                    "amount_in_rupees": amount,
                    "receipt_id": "",  # Empty string instead of None
                    "currency": "INR",
                    "payment_capture": True
                })
                
                # Parse the JSON response
                payment_data = json.loads(payment_result)
                
                if payment_data.get("status") == "success":
                    order_id = payment_data.get("order_id")
                    amount_paise = payment_data.get("amount")
                    
                    # Store payment info in state for frontend FIRST
                    state['payment_order_id'] = order_id
                    state['payment_amount'] = amount_paise
                    state['payment_status'] = 'pending'
                    
                    # Debug logging
                    print(f"✅ Payment order created - order_id: {order_id}, amount: {amount_paise}")
                    print(f"🔍 State after setting payment info: payment_order_id={state.get('payment_order_id')}, payment_amount={state.get('payment_amount')}")
                    
                    # Format response for frontend
                    state['answer'] = f"✅ Payment order created! Opening Razorpay checkout..."
                else:
                    error_msg = payment_data.get('message', payment_data.get('error', 'Unknown error'))
                    print(f"❌ Payment order creation failed: {error_msg}")
                    state['answer'] = f"❌ Failed to create payment order: {error_msg}"
            except Exception as e:
                state['answer'] = f"❌ Error processing payment: {str(e)}"
        else:
            # No amount found, use agent to handle the query
            query_with_context = state["user_query"] + context
            
            # Check if query contains payment intent even without explicit amount
            if has_payment_intent:
                # Try to extract amount from query more aggressively
                # Look for numbers in various formats
                amount_patterns = [
                    r'(\d+(?:,\d+)*(?:\.\d+)?)',
                    r'₹\s*(\d+(?:,\d+)*)',
                    r'rs\.?\s*(\d+(?:,\d+)*)',
                ]
                
                for pattern in amount_patterns:
                    match = re.search(pattern, state["user_query"])
                    if match:
                        amount_str = match.group(1).replace(',', '')
                        try:
                            amount = float(amount_str)
                            if amount > 0:
                                # Found amount, create payment order
                                try:
                                    payment_result = process_payments.invoke({
                                        "amount_in_rupees": amount,
                                        "receipt_id": "",
                                        "currency": "INR",
                                        "payment_capture": True
                                    })
                                    
                                    payment_data = json.loads(payment_result)
                                    
                                    if payment_data.get("status") == "success":
                                        order_id = payment_data.get("order_id")
                                        amount_paise = payment_data.get("amount")
                                        
                                        state['payment_order_id'] = order_id
                                        state['payment_amount'] = amount_paise
                                        state['payment_status'] = 'pending'
                                        state['answer'] = f"✅ Payment order created! Opening Razorpay checkout..."
                                        print(f"✅ Payment order created via agent - order_id: {order_id}, amount: {amount_paise}")
                                        return state
                                except Exception as e:
                                    print(f"❌ Error in payment processing: {str(e)}")
                        except:
                            pass
            
            # Use agent to handle the query
            agent = create_agent(self.llm, [process_payments])
            result = agent.invoke({"messages": [HumanMessage(content=query_with_context)]})
            agent_response = result["messages"][-1].content
            state['answer'] = agent_response
            
            # Extract payment order from agent's tool calls or response
            # First, try to find tool results in messages
            try:
                # Look through all messages to find tool results
                for msg in result.get("messages", []):
                    # Check message type
                    msg_type = getattr(msg, 'type', None) or type(msg).__name__
                    msg_content = getattr(msg, 'content', None) or str(msg)
                    
                    # Check if this is a tool message or contains JSON
                    if msg_type == 'tool' or 'ToolMessage' in str(type(msg)) or '"order_id"' in str(msg_content):
                        # Try to parse as JSON
                        try:
                            # Try to extract JSON from content
                            if isinstance(msg_content, str):
                                # Look for JSON object
                                json_start = msg_content.find('{')
                                json_end = msg_content.rfind('}') + 1
                                if json_start >= 0 and json_end > json_start:
                                    tool_data = json.loads(msg_content[json_start:json_end])
                                else:
                                    tool_data = json.loads(msg_content)
                            else:
                                tool_data = json.loads(str(msg_content))
                            
                            if isinstance(tool_data, dict) and tool_data.get("status") == "success":
                                order_id = tool_data.get("order_id")
                                amount_paise = tool_data.get("amount")
                                if order_id and amount_paise:
                                    state['payment_order_id'] = order_id
                                    state['payment_amount'] = amount_paise
                                    state['payment_status'] = 'pending'
                                    print(f"✅ Extracted payment order from tool result - order_id: {order_id}, amount: {amount_paise}")
                                    state['answer'] = f"✅ Payment order created! Opening Razorpay checkout..."
                                    break
                        except (json.JSONDecodeError, ValueError, AttributeError, TypeError):
                            # Not JSON or parse error, continue
                            pass
                
                # If not found in tool results, extract from agent's text response
                # The response might contain "Order ID: order_XXXXX" or similar
                if not state.get('payment_order_id'):
                    # Look for order ID pattern (order_XXXXX)
                    order_id_match = re.search(r'order_[A-Za-z0-9]+', agent_response)
                    if order_id_match:
                        order_id = order_id_match.group()
                        print(f"🔍 Found order ID in response: {order_id}")
                        
                        # Try to find amount - look for patterns like "amount": 500000 or "amount":500000
                        amount_patterns = [
                            r'"amount"\s*:\s*(\d+)',
                            r"'amount'\s*:\s*(\d+)",
                            r'amount["\']?\s*:\s*(\d+)',
                            r'amount["\']?\s*is\s*(\d+)',
                            r'₹\s*(\d+(?:,\d+)*)',
                            r'(\d+)\s*paise',
                        ]
                        amount_paise = None
                        for pattern in amount_patterns:
                            amount_match = re.search(pattern, agent_response, re.IGNORECASE)
                            if amount_match:
                                amount_str = amount_match.group(1).replace(',', '')
                                try:
                                    amount_paise = int(amount_str)
                                    print(f"🔍 Found amount in response text: {amount_paise}")
                                    break
                                except ValueError:
                                    continue
                        
                        # If amount not found in response, try to get it from the original query amount
                        # Re-extract amount from query if not already set
                        if not amount_paise:
                            query_amount = None
                            query_lower = state["user_query"].lower()
                            amount_patterns = [
                                r'pay\s+(?:₹|rs\.?|rupees?)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
                                r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupees?|rs\.?|₹)?\s*(?:rent|payment)?',
                                r'₹\s*(\d+(?:,\d+)*(?:\.\d+)?)',
                            ]
                            for pattern in amount_patterns:
                                match = re.search(pattern, query_lower)
                                if match:
                                    amount_str = match.group(1).replace(',', '')
                                    try:
                                        query_amount = float(amount_str)
                                        break
                                    except:
                                        pass
                            
                            if query_amount:
                                amount_paise = int(query_amount * 100)  # Convert to paise
                                print(f"🔍 Using amount from query: {query_amount} rupees = {amount_paise} paise")
                            elif state.get('rent'):
                                amount_paise = int(state['rent'] * 100)
                                print(f"🔍 Using amount from state rent: {state['rent']} rupees = {amount_paise} paise")
                        
                        if amount_paise:
                            state['payment_order_id'] = order_id
                            state['payment_amount'] = amount_paise
                            state['payment_status'] = 'pending'
                            print(f"✅ Extracted payment order from text - order_id: {order_id}, amount: {amount_paise}")
                            state['answer'] = f"✅ Payment order created! Opening Razorpay checkout..."
                        else:
                            print(f"⚠️ Found order ID but could not determine amount")
            except Exception as e:
                print(f"Could not extract payment order: {str(e)}")
                import traceback
                traceback.print_exc()
                pass
        
        # Update payment status after processing
        if 'success' in state['answer'].lower() or 'created' in state['answer'].lower():
            if state.get('payment_status') != 'pending':
                state['payment_status'] = 'paid'
        elif 'pending' in state['answer'].lower():
            state['payment_status'] = 'pending'
        
        # Check if we need to call reminder_agent to set up reminders
        if 'reminder' in query_lower or 'remind' in query_lower:
            state['next_agent'] = 'reminder_agent'
        
        return state
    
    def _onboarding_agent(self, state: AgentState) -> AgentState:
        """
        Handles tenant onboarding queries. Since the landlord is already onboarded,
        the focus is on onboarding tenants by uploading lease documents.
        Keep responses brief and to the point.
        """
        # Initialize agent history if not present
        if 'agent_history' not in state:
            state['agent_history'] = []
        state['agent_history'].append('onboarding_agent')
        
        query_lower = state['user_query'].lower()
        conversation_history = state.get("conversation_history", [])
        
        # Check if user is asking about onboarding a tenant
        tenant_onboarding_keywords = ["onboard tenant", "onboard a tenant", "add tenant", "new tenant", "tenant onboarding"]
        if any(keyword in query_lower for keyword in tenant_onboarding_keywords):
            state['answer'] = "To onboard a tenant, please upload the lease document. I'll extract the tenant details and create an onboarding link for them. You can upload the lease using the file attachment button."
            return state
        
        # Handle general onboarding questions - assume they mean tenant onboarding
        if any(phrase in query_lower for phrase in ["onboarding", "onboard", "how to onboard"]):
            state['answer'] = "To onboard a tenant, upload their lease document. I'll extract the tenant information and generate an onboarding link you can share with them. Ready to upload a lease?"
            return state
        
        # For other queries, use LLM but keep it brief and focused on tenant onboarding
        prompt = f"""You are an onboarding assistant for KirayaEase. The landlord is already onboarded and has completed KYC. 
When asked about onboarding, guide them to upload a lease document to onboard their tenant.
Context hint: {self._context_hint(state)}

User query: {state['user_query']}

Provide a concise, helpful response (2-3 sentences max) focused on tenant onboarding through lease upload. 
Only provide step-by-step details if explicitly requested."""
        response = self.llm.invoke(prompt)
        state['answer'] = response.content.strip()
        return state
    
    def chat(
        self,
        query: str,
        session_id: str = "default",
        conversation_history: list = None,
        user_role: str = "tenant",
        active_scope: str = "self",
        active_tenant_id: str | None = None,
    ) -> dict:
        """
        Process a user query through the agentic framework with conversation memory.
        
        Args:
            query: The user's query string
            session_id: Session identifier for conversation memory (default: "default")
            conversation_history: Optional conversation history. If not provided, uses stored memory for session_id
            
        Returns:
            Dictionary with 'answer' and optionally 'payment_order_id' and 'payment_amount' if payment was initiated
        """
        # Update agent docs before routing (in case they changed)
        self.agent_docs = {
            "lease_agent": self._lease_agent.__doc__,
            "reminder_agent": self._reminder_agent.__doc__,
            "insights_agent": self._insights_agent.__doc__,
            "payments_agent": self._payments_agent.__doc__,
            "onboarding_agent": self._onboarding_agent.__doc__
        }
        
        # Get or initialize conversation history for this session
        if conversation_history is None:
            if session_id not in self.conversation_memory:
                self.conversation_memory[session_id] = []
            conversation_history = self.conversation_memory[session_id]
        
        # Invoke the graph with conversation history
        result = self.app.invoke({
            "user_query": query,
            "conversation_history": conversation_history,
            "user_role": user_role,
            "active_scope": active_scope,
            "active_tenant_id": active_tenant_id,
        })
        
        answer = result.get("answer", "I'm sorry, I couldn't process your query.")
        
        # Extract payment info from result
        payment_order_id = result.get("payment_order_id")
        payment_amount = result.get("payment_amount")
        
        # Debug logging
        print(f"🔍 Final result keys: {list(result.keys())}")
        print(f"🔍 Payment info in result: payment_order_id={payment_order_id}, payment_amount={payment_amount}")
        
        # Update conversation memory
        conversation_history.append({"role": "user", "content": query})
        conversation_history.append({"role": "assistant", "content": answer})
        
        # Keep only last 10 exchanges (20 messages) to avoid token limits
        if len(conversation_history) > 20:
            conversation_history[:] = conversation_history[-20:]
        
        # Store updated history
        self.conversation_memory[session_id] = conversation_history
        
        # Return answer and payment info if available
        return {
            "answer": answer,
            "payment_order_id": payment_order_id,
            "payment_amount": payment_amount
        }
    
    def run_chain(self, prompt_id: str = None, query: str = None) -> dict:
        """
        Compatibility method for the old interface.
        Processes a query and returns a response in the old format.
        
        Args:
            prompt_id: Ignored (kept for compatibility)
            query: The user's query string
            
        Returns:
            Dictionary with 'text' key containing the response
        """
        if not query:
            return {"text": "Please provide a query."}
        
        result = self.chat(query)
        return {"text": result.get("answer", "I'm sorry, I couldn't process your query.")}


if __name__ == "__main__":
    # Example usage
    assistant = RentWiseAssistant("gpt-4o-mini", 0, 3)
    
    # Test different types of queries
    test_queries = [
        "Hi, who are you?",
        "What's the price of a 2BHK in Mumbai?",
        "I need to pay my rent of ₹50,000",
        "Extract lease details from /Users/anshagarwal/Developer/KirayaEase/data/Lease_Agreement_Sample.pdf"
    ]
    
    for query in test_queries:
        print(f"\nUser: {query}")
        response = assistant.chat(query)
        print(f"Assistant: {response}\n")
        print("-" * 80)

from langchain_core.messages import HumanMessage, AIMessage, ToolMessage

from app.core.workflow import build_graph
from app.core.state import AgentState



def run_chat():

    print("\n🏠 RentOS CLI")
    print("Type 'exit' to quit.\n")

    # Initial agent state
    state: AgentState = {
        "user_id": 1,
        "messages": []
    }

    while True:

        user_input = input("\nYou: ")

        if user_input.lower() in ["exit", "quit"]:
            print("Goodbye 👋")
            break

        # Add user message
        state["messages"].append(HumanMessage(content=user_input))

        # Run graph step-by-step
        for event in build_graph().stream(state):

            print("\n--- GRAPH EVENT ---")
            print(event)

            # Merge updates into state
            state.update(event)

            # Handle messages if present
            if "messages" in state and state["messages"]:

                last_message = state["messages"][-1]

                # Tool calls
                if isinstance(last_message, AIMessage) and last_message.tool_calls:
                    print("\n🔧 TOOL CALL:")
                    for call in last_message.tool_calls:
                        print(call)

                # Tool results
                if isinstance(last_message, ToolMessage):
                    print("\n🛠 TOOL RESULT:")
                    print(last_message.content)

                # Final agent response
                if isinstance(last_message, AIMessage) and not last_message.tool_calls:
                    print("\nAgent:", last_message.content)

        # Some nodes may return an "answer" instead of messages
        if "answer" in state:
            print("\nAgent:", state["answer"])


if __name__ == "__main__":
    run_chat()
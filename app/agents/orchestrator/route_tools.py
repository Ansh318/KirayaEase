from langchain_core.messages import AIMessage


def should_continue(state):

    last_message = state["messages"][-1]

    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        names = [tc.get("name") for tc in (last_message.tool_calls or [])]
        print(f"[AGENT][ROUTER] -> tools | tool_calls={names}")
        return "tools"

    print("[AGENT][ROUTER] -> end | no tool calls")
    return "end"
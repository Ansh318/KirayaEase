from typing import Dict, Any, List

from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage

from app.core.modelConfig import ModelConfigManager
from app.db.embedding import EmbeddingManager
from app.db.vector_db import PineconeClientManager


class TalkToLeaseRAG:
    """
    Minimal RAG wrapper for answering questions about a *single* lease.

    - Uses `lease_id` to scope Pinecone search so we never mix different leases.
    - Assumes leases are indexed in the `ke-lease-agreements` index, `leases` namespace
      with metadata containing at least:
        - lease_id: str
        - chunk_text: str  (raw text of the chunk)
    """

    def __init__(
        self,
        model_name: str = "gpt-4o-mini",
        temperature: float = 0,
        max_retries: int = 3,
    ) -> None:
        # LLM for final answers
        self.llm: ChatOpenAI = ModelConfigManager(
            model_name=model_name,
            temperature=temperature,
            max_retries=max_retries,
        ).model()

        # Embeddings + vector DB client
        self.embedding_manager = EmbeddingManager(
            model_name=model_name,
            temperature=0,
            max_retries=max_retries,
        )
        self.vector_client = PineconeClientManager()

    def _build_system_prompt(self) -> str:
        return (
            "You are an assistant that answers questions about a *specific* residential lease agreement. "
            "You are given textual excerpts from that lease as context. "
            "Base your answer only on this context and common-sense contract interpretation. "
            "If the answer is not clearly specified, say you are not sure rather than guessing. "
            "Whenever possible, quote or paraphrase the exact clause relevant to the answer."
        )

    def _format_context(self, matches: List[Dict[str, Any]]) -> str:
        """
        Turn retrieved Pinecone matches into a compact text block.
        Expects each match to have metadata['chunk_text'].
        """
        if not matches:
            return "No lease excerpts were found for this lease_id."

        lines: List[str] = []
        for i, m in enumerate(matches, start=1):
            md = m.get("metadata", {}) or {}
            text = md.get("chunk_text") or ""
            section = md.get("section_title") or md.get("page_number")
            header = f"[Excerpt {i}]"
            if section is not None:
                header += f" (section/page: {section})"

            if text:
                lines.append(f"{header}\n{text}")

        return "\n\n".join(lines) if lines else "No lease excerpts were found for this lease_id."

    def answer_question(
        self,
        user_query: str,
        lease_id: str,
        top_k: int = 5,
    ) -> str:
        """
        Basic RAG flow:
        1. Embed the query.
        2. Search Pinecone filtered by `lease_id`.
        3. Feed retrieved context + user question to the LLM.
        """
        if not lease_id:
            raise ValueError("lease_id is required for TalkToLeaseRAG.answer_question")

        # 1) Embed query
        query_vec = self.embedding_manager.embed_single(user_query)

        # 2) Vector search in Pinecone, scoped by lease_id
        index, namespace = self.vector_client.get_or_create_index("leases")
        namespace = namespace or "leases"

        result = index.query(
            vector=query_vec,
            top_k=top_k,
            include_metadata=True,
            namespace=namespace,
            filter={"lease_id": lease_id},
        )

        matches: List[Dict[str, Any]] = (
            result.get("matches", []) if isinstance(result, dict) else getattr(result, "matches", [])
        )

        # 3) Build context string
        context_text = self._format_context(matches)

        # 4) Compose prompt and call LLM
        system_msg = SystemMessage(content=self._build_system_prompt())
        human_msg = HumanMessage(
            content=(
                "Here are excerpts from the lease:\n\n"
                f"{context_text}\n\n"
                "User question:\n"
                f"{user_query}"
            )
        )

        response = self.llm.invoke([system_msg, human_msg])
        return getattr(response, "content", "") or "I could not generate a response."


def talk_to_lease(
    query: str,
    lease_id: str,
    model_name: str = "gpt-4o-mini",
    temperature: float = 0,
    max_retries: int = 3,
) -> Dict[str, Any]:
    """
    Convenience function for calling the TalkToLease RAG from routes/services.

    Returns:
        {
            "answer": <str>,
            "lease_id": <str>,
        }
    """
    rag = TalkToLeaseRAG(
        model_name=model_name,
        temperature=temperature,
        max_retries=max_retries,
    )
    answer = rag.answer_question(query, lease_id)
    return {"answer": answer, "lease_id": lease_id}


# embedding.py

from app.core.modelConfig import ModelConfigManager
import numpy as np

class EmbeddingManager:
    """
    A manager class to handle embedding generation for text lists and single queries.
    Uses OpenAI embeddings through LangChain's OpenAIEmbeddings wrapper.
    """

    def __init__(self, model_name: str = "gpt-4", temperature: float = 0, max_retries: int = 1):
        # Load config + initialize embedding model once
        config = ModelConfigManager(
            model_name=model_name,
            temperature=temperature,
            max_retries=max_retries
        )
        self.embedding_model = config.embedding_model()

    def embed_text_list(self, text_list: list[str]) -> list[list[float]]:
        """
        Embeds a list of text strings using the OpenAIEmbeddings model.
        Returns a list of embedding vectors.
        """
        return self.embedding_model.embed_documents(text_list)

    def embed_single(self, text: str) -> list[float]:
        """
        Embeds a single text string using the OpenAIEmbeddings model.
        Useful for query-time embedding.
        """
        return self.embedding_model.embed_query(text)
    
    @staticmethod
    def cosine_similarity_batch(query_vec, matrix):
        query = np.array(query_vec)
        matrix = np.array(matrix)

        dot = np.dot(matrix, query)
        q_norm = np.linalg.norm(query)
        m_norm = np.linalg.norm(matrix, axis=1)

        return dot / (q_norm * m_norm)
    
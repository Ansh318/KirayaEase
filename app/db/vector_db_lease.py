import hashlib
from app.db.embedding import EmbeddingManager
from app.db.vector_db import PineconeClientManager


class LeaseDocumentProcessor:

    def __init__(self):

        self.client = PineconeClientManager()

        index_result = self.client.get_or_create_index("leases")

        if isinstance(index_result, tuple):
            self.index, self.namespace = index_result
            self.use_namespace = True
        else:
            self.index = index_result
            self.namespace = None
            self.use_namespace = False

        self.embedder = EmbeddingManager()

    @staticmethod
    def compute_hash(text: str) -> str:
        return hashlib.sha256(text.encode()).hexdigest()


    def _already_indexed(self, file_hash):

        try:
            if self.use_namespace:
                result = self.index.fetch(ids=[file_hash], namespace=self.namespace)
            else:
                result = self.index.fetch(ids=[file_hash])

            return len(result.get("vectors", {})) > 0
        except Exception:
            return False


    def _chunk_text(self, text, chunk_size=500):

        chunks = []

        for i in range(0, len(text), chunk_size):
            chunks.append(text[i:i + chunk_size])

        return chunks


    def process_lease(self, lease_id: str, landlord_id: str, text: str):

        file_hash = self.compute_hash(text)

        if self._already_indexed(file_hash):
            return {"status": "skipped", "file_hash": file_hash}

        chunks = self._chunk_text(text)

        vectors = []

        for i, chunk in enumerate(chunks):

            embedding_vector = self.embedder.embed_single(chunk)

            vectors.append({
                "id": f"{lease_id}-{i}",
                "values": embedding_vector,
                "metadata": {
                    "lease_id": lease_id,
                    "landlord_id": landlord_id,
                    "chunk_text": chunk
                }
            })

        upsert_params = {"vectors": vectors}

        if self.use_namespace:
            upsert_params["namespace"] = self.namespace

        self.index.upsert(**upsert_params)

        return {
            "status": "inserted",
            "lease_id": lease_id,
            "chunks_stored": len(chunks)
        }

    def delete_vectors_for_lease(self, lease_id: str) -> None:
        """Remove Pinecone chunks for this lease before reindexing (e.g. after manual edit)."""
        lid = str(lease_id)
        try:
            kwargs: dict = {"filter": {"lease_id": {"$eq": lid}}}
            if self.use_namespace and self.namespace:
                kwargs["namespace"] = self.namespace
            self.index.delete(**kwargs)
        except Exception as e:
            print(f"[LeaseDocumentProcessor] delete_vectors_for_lease warning: {e}")

    def reindex_lease(self, lease_id: str, landlord_id: str, text: str) -> dict:
        """Replace vectors for a lease with new text (manual / edited summary)."""
        self.delete_vectors_for_lease(lease_id)
        return self.process_lease(lease_id, landlord_id, text)

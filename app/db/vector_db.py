import os
from pinecone import Pinecone


class PineconeClientManager:
    def __init__(self):
        """
        Initialize Pinecone client with API key from environment.
        Uses a single Pinecone index (default: "ke-lease-agreements") where
        lease agreements can be stored, optionally under a "leases" namespace.
        """
        api_key = os.getenv("PINECONE_API_KEY")
        if not api_key:
            raise ValueError("PINECONE_API_KEY environment variable is required")
        
        self.pc = Pinecone(api_key=api_key)
        
        # Single index with namespaces (default mode)
        single_index = os.getenv("PINECONE_INDEX_NAME", "ke-lease-agreements")
        self.single_index_mode = True
        self.index_name = single_index
        self.lease_namespace = os.getenv("PINECONE_LEASE_NAMESPACE", "leases")
        self._index = None
        
        print(
            f"Using Pinecone index: '{self.index_name}' "
            f"with lease namespace='{self.lease_namespace}'"
        )

    def _get_index(self, index_name: str, dimension: int = 2048):
        """
        Get or connect to a Pinecone index.
        Assumes index already exists (created via Pinecone dashboard).
        """
        try:
            # Check if index exists
            existing_indexes = [idx.name for idx in self.pc.list_indexes()]
            if index_name in existing_indexes:
                return self.pc.Index(index_name)
            else:
                raise ValueError(
                    f"Index '{index_name}' not found. "
                    f"Please create it in Pinecone dashboard first with dimension {dimension}."
                )
        except ValueError:
            raise  # Re-raise ValueError as-is
        except Exception as e:
            raise RuntimeError(f"Failed to connect to Pinecone index '{index_name}': {e}")

    def get_or_create_index(self, name: str):
        """
        Get an index by name. Returns a tuple of (index, namespace) if using single index mode,
        or just the index if using separate indexes.
        For compatibility with ChromaDB interface.
        Indexes are connected lazily when first accessed.
        """
        # Get embedding dimension from environment or default to 2048
        dimension = int(os.getenv("PINECONE_INDEX_DIMENSION", "2048"))
        
        # Single index with optional namespaces (current mode)
        if self._index is None:
            self._index = self._get_index(self.index_name, dimension=dimension)

        # For lease-related data, always use the configured lease namespace
        if name in {"leases", "lease_agreements", "ke-lease-agreements"}:
            return (self._index, self.lease_namespace)

        # Fallback: return index with no namespace so caller can choose
        return (self._index, None)

    def delete_index(self, name: str):
        """
        Delete a Pinecone index.
        WARNING: This permanently deletes the index and all data!
        """
        try:
            if name in [idx.name for idx in self.pc.list_indexes()]:
                self.pc.delete_index(name)
        except Exception as e:
            print(f"Error deleting index {name}: {e}")

    def list_indexes(self):
        """
        List all Pinecone indexes.
        """
        return [idx.name for idx in self.pc.list_indexes()]

from langchain_openai import ChatOpenAI,OpenAIEmbeddings
from dotenv import load_dotenv
load_dotenv()
import os

os.environ['OPENAI_API_KEY'] = os.getenv('OPENAI_API_KEY')


class ModelConfigManager:

    def __init__(self, model_name, temperature, max_retries):
        self.model_name = model_name
        self.temperature = temperature
        self.max_retries = max_retries
        self.embedding_dimensions = 512
    
    def model(self):
        llm = ChatOpenAI(
            model = self.model_name,
            temperature = self.temperature,
            max_retries = self.max_retries,
        )
        return llm

    def embedding_model(self):
        return OpenAIEmbeddings(
            model=self.model_name,
            dimensions=self.embedding_dimensions
        )
    
from prompts import PromptManager
from langchain.memory import ConversationBufferMemory
from langchain.chains import LLMChain
from modelConfig import ModelConfigManager

class OpenAIModel:

    def __init__(self, name, temperature, max_retries):
        self.name = name
        self.temperature = temperature
        self.max_retries = max_retries

    def load_model(self):
        llm = ModelConfigManager(self.name, self.temperature, self.max_retries).model()
        return llm



model = OpenAIModel("gpt-4", "0", "1")
response = model.run_chain("System Prompt", "What is your job description?")
print(response)
from prompts import PromptManager
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from modelConfig import ModelConfigManager

class RentWiseAssistant:

    def __init__(self, name, temperature, max_retries):
        self.name = name
        self.temperature = temperature
        self.max_retries = max_retries

    def load_model(self):
        return ModelConfigManager(self.name, self.temperature, self.max_retries).model()

    def run_chain(self, prompt_id, query):
        # Load prompt template
        prompt_manager = PromptManager()
        prompt_template = prompt_manager.create_prompt(prompt_id)

        # Load LLM
        llm = self.load_model()

        # Create LLMChain with correct memory
        memory = ConversationBufferMemory(
            return_messages=True,
            memory_key="chat_history",
            input_key="human_input"
        )

        chain = LLMChain(
            llm=llm,
            prompt=prompt_template,
            memory=memory,
            verbose=True
        )

        # Use .invoke() (not .run()) with proper input keys
        response = chain.invoke({
            "human_input": query
        })

        return response


if __name__ == "__main__":
    assistant = RentWiseAssistant("gpt-4", 0.7, 2)
    response = assistant.run_chain(
        prompt_id="System Prompt",
        query="Hi who are you?"
    )
    print("Assistant Response:", response.get("text", response))
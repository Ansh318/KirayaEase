from prompts import PromptManager
from langchain.chains import LLMChain
from langchain.memory.buffer import ConversationBufferMemory
from modelConfig import ModelConfigManager

class LeaseAgreementGenerator:

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

        # Load lease template text from file
        with open("/Users/anshagarwal/Desktop/KirayaEase/data/residential-rental-agreement-format.txt", "r") as f:
            lease_template = f.read()

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
            "human_input": query,
            "lease_template": lease_template
        })

        return response


# # Example usage
# if __name__ == "__main__":
#     model = OpenAIModel("gpt-4", "0", "1")
#     response = model.run_chain(
#     "Lease Prompt",
#     "Ravi Kumar is renting a 2BHK apartment in Andheri West, Mumbai from Sept 1, 2025. Landlord is Ansh Agarwal. Rent is ₹25,000/month. Deposit is ₹50,000. Property is 950 sq ft with 2 bathrooms and 1 car park. Starting meter reading is 5421."
# )



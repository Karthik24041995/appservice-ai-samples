# LangChain FastAPI Chat with Azure OpenAI

This project is a sample FastAPI web application that demonstrates how to build a conversational AI chat interface using LangChain, FastAPI, and Azure OpenAI. It features both detailed and summarized answers powered by Azure OpenAI, with authentication via Azure Managed Identity. The app uses the LangChain summarize chain to generate concise summaries of responses. The backend is configured to use an **Azure AI Foundry account** and the **gpt-4o model** by default (see `infra/main.bicep`). You can switch to another model by updating the Bicep template accordingly. The frontend is a modern, responsive chat UI that streams long answers and provides concise summaries for user queries.

## Features
- FastAPI backend serving a chat interface
- Uses LangChain and Azure OpenAI for LLM responses
- Uses Azure AI Foundry account and gpt-4o model (customizable)
- Managed Identity authentication for secure access to Azure OpenAI (API key option available)
- Streams long answers and generates summaries
- Restricts max-tokens in responses to help avoid throttling (customizable)
- Modern, user-friendly web UI

## Prerequisites
- [Azure Developer CLI (azd)](https://aka.ms/azd)
- An Azure subscription
- Access to Azure OpenAI with a deployed model
- Python 3.10+

## Getting Started

### 1. Clone the repository
```powershell
# In PowerShell
git clone <your-repo-url>
cd langchain-fastapi-chat
```

### 2. Install dependencies
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 3. Set up Azure resources and deploy with azd
This project uses Infrastructure-as-Code (IaC) with Bicep templates in the `infra/` folder. The recommended way to deploy is with Azure Developer CLI (azd).

#### Initialize azd
```powershell
azd init
```
Follow the prompts to select your Azure subscription and environment name.

#### Provision and deploy
```powershell
azd up
```
This command will:
- Provision required Azure resources (App Service, Azure OpenAI, Managed Identity, etc.)
- Deploy the FastAPI app to Azure App Service
- Configure environment variables and authentication

### 4. Access the app
After deployment, azd will output the URL of your deployed web app. Open it in your browser to start chatting!

## Configuration
Environment variables are managed by azd and set automatically during deployment. Key variables include:
- `ENDPOINT_URL`: Azure OpenAI endpoint (from Azure AI Foundry)
- `DEPLOYMENT_NAME`: Name of your Azure OpenAI deployment/model (default: gpt-4o)

### Model Selection
By default, the Bicep template provisions the `gpt-4o` model in Azure AI Foundry. To use a different model, update the `aiFoundryModelName` parameter and related deployment properties in `infra/main.bicep`.

### Throttling and max-tokens
The code restricts the `max_tokens` parameter for both long and summary responses to help avoid hitting Azure OpenAI throttling limits. You can adjust these values in `app.py` based on your quota and requirements.

### Authentication: Managed Identity vs API Key
This sample uses **Managed Identity** for secure, passwordless authentication to Azure OpenAI (recommended for production). If you prefer to use API keys, you can modify the authentication logic in `app.py` to use your Azure OpenAI API key instead.

## Project Structure
```
app.py                # FastAPI app entry point
requirements.txt      # Python dependencies
azure.yaml            # azd project configuration
infra/                # Bicep IaC templates
static/               # Static assets (if any)
```

## Useful azd Commands
- `azd up` — Provision and deploy
- `azd down` — Remove all resources
- `azd env set <NAME> <VALUE>` — Set environment variable

## Learn More
- [LangChain Documentation](https://python.langchain.com/)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Azure Developer CLI](https://aka.ms/azd)

---

*This sample is provided for educational purposes. For production use, review security, authentication, and cost management best practices.*

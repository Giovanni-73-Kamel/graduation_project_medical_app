from fastapi import APIRouter
from pydantic import BaseModel
import os
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()

router = APIRouter()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Configure the Gemini client
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

class ChatRequest(BaseModel):
    message: str

@router.post("/chat")
def chat(req: ChatRequest):
    try:
        if not GEMINI_API_KEY:
            return {"error": "API key not found. Check your .env file."}

        # 👇 Use a supported model name
        model = genai.GenerativeModel("gemini-flash-latest")

        # Generate response
        response = model.generate_content(
            f"""
You are a medical assistant chatbot.
- Provide general advice only
- Do NOT diagnose diseases
- Do NOT give medication dosages
- If symptoms seem serious, say: seek medical help immediately
- Be calm, supportive, and clear

User: {req.message}
"""
        )

        print("Gemini response:", response)

        return {
            "reply": response.text
        }

    except Exception as e:
        return {
            "error": "Server error",
            "details": str(e)
        }
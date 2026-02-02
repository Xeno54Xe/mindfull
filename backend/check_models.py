from google import genai
import os

GEMINI_KEY = "AIzaSyD59D-Y8Y5XEKqRnDnve7gwaqirkOIpOn0"

print("--- CHECKING AVAILABLE MODELS ---")
try:
    client = genai.Client(api_key=GEMINI_KEY)
    # List all models
    for m in client.models.list():
        # Only show the ones that can generate content
        if "generateContent" in m.supported_generation_methods:
            print(f"AVAILABLE: {m.name}")
except Exception as e:
    print(f"Error: {e}")
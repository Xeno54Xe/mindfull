from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests  # Standard HTTP requests
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import re 

# --- CONFIGURATION ---
GEMINI_KEY = "AIzaSyD59D-Y8Y5XEKqRnDnve7gwaqirkOIpOn0"
SPOTIFY_CLIENT_ID = "d392c7212c464db4b1fb4f2fcb77bb95"
SPOTIFY_CLIENT_SECRET = "c0d38d67b45f40d9a291f52da6dccfd3"
WEATHER_API_KEY = "4c307cf7ac9db8234d36c10722ec8d5c"

# --- SETUP SPOTIFY ---
sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
    client_id=SPOTIFY_CLIENT_ID,
    client_secret=SPOTIFY_CLIENT_SECRET
))

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class JournalEntry(BaseModel):
    text: str
    lat: float = 0.0
    lon: float = 0.0
    local_time: str = "12:00 PM" 

@app.post("/analyze")
def analyze_mood(entry: JournalEntry):
    print(f"\n--- NEW REQUEST: {entry.text[:30]}... ---")
    
    # 1. WEATHER
    weather_desc = "Unknown"
    if entry.lat != 0.0:
        try:
            url = f"https://api.openweathermap.org/data/2.5/weather?lat={entry.lat}&lon={entry.lon}&appid={WEATHER_API_KEY}&units=metric"
            w_data = requests.get(url).json()
            if 'weather' in w_data:
                weather_desc = w_data['weather'][0]['description']
        except: pass

    # 2. DEFAULTS
    mood, artist, reason, score = "Calm", "Lofi Girl", "Just breathing.", 5
    track_name, image_url = "lofi hip hop radio", "https://i.scdn.co/image/ab67616d0000b2735755e164993798e0c9ef7d7a"

    # 3. AI ANALYSIS (Using Gemini 2.0 Flash)
    try:
        prompt_text = f"""
        Analyze this journal entry.
        User Text: "{entry.text}" (Context: {weather_desc}, {entry.local_time})
        
        TASK:
        1. Mood (One word).
        2. Music Artist (Specific).
        3. Reason (Short).
        4. Valence Score (1-10 integer only).
        
        Output strictly: Mood|Artist|Reason|Score
        Example: Happy|Pharrell Williams|Upbeat vibes.|9
        """

        # --- UPDATED URL FOR GEMINI 2.0 ---
        ai_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_KEY}"
        
        payload = {
            "contents": [{
                "parts": [{"text": prompt_text}]
            }]
        }
        
        response = requests.post(ai_url, json=payload)
        response_json = response.json()
        
        # Safe Parsing
        if "candidates" in response_json:
            raw_text = response_json["candidates"][0]["content"]["parts"][0]["text"].strip()
            print(f"AI Raw Output: {raw_text}")

            if '|' in raw_text:
                parts = raw_text.split('|')
                if len(parts) >= 3:
                    mood = parts[0].strip()
                    artist = parts[1].strip()
                    reason = parts[2].strip()
                
                if len(parts) >= 4:
                    score_part = parts[3].strip()
                    found_digits = re.findall(r'\d+', score_part)
                    if found_digits:
                        score = int(found_digits[0])
                        score = max(1, min(10, score))
                        print(f"Parsed Score: {score}")
        else:
            print(f"AI Error Response: {response_json}")

        # 4. SPOTIFY SEARCH
        results = sp.search(q=f"artist:{artist}", type='track', limit=1)
        if results['tracks']['items']:
            track = results['tracks']['items'][0]
            track_name = track['name']
            artist = track['artists'][0]['name']
            image_url = track['album']['images'][0]['url']

    except Exception as e:
        print(f"Error: {e}")

    return {
        "mood": mood,
        "artist": artist,
        "track_name": track_name,
        "image_url": image_url,
        "reason": reason,
        "score": score
    }
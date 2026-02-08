import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import json
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
from groq import Groq 
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# --- CONFIGURATION ---
GROQ_API_KEY = os.getenv("GROQ_API_KEY") 
SPOTIFY_CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID")
SPOTIFY_CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET")

# 1. SETUP CLIENTS
# Initialize Groq (The Fast AI)
try:
    client = Groq(api_key=GROQ_API_KEY)
except Exception as e:
    print(f"⚠️ Groq Client Error: {e}")

# Initialize Spotify (Generic - for searching covers & artists)
try:
    sp_generic = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
        client_id=SPOTIFY_CLIENT_ID,
        client_secret=SPOTIFY_CLIENT_SECRET
    ))
except Exception as e:
    print(f"⚠️ Spotify Client Error: {e}")

app = FastAPI()

# --- CORS (SECURITY) SETUP ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- DATA MODELS ---

class SpotifyTokenRequest(BaseModel):
    token: str

class JournalEntry(BaseModel):
    text: str
    lat: float = 0.0
    lon: float = 0.0
    local_time: str = "12:00 PM"
    music_profile: Optional[str] = "General Pop" 

class DailyLog(BaseModel):
    date: str
    mood_score: float
    intention: str
    weather: str
    journal_content: str

class AnalysisRequest(BaseModel):
    user_id: str
    music_profile: Optional[str] = "General Pop" 
    logs: List[DailyLog]

# --- HELPER: LLM CALL ---
def call_llama(prompt):
    """Hits Groq API (Llama 3.3) for instant responses."""
    try:
        completion = client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model="llama-3.3-70b-versatile",
            temperature=0.6,
            response_format={"type": "json_object"} 
        )
        return json.loads(completion.choices[0].message.content)
    except Exception as e:
        print(f"⚠️ Groq Error: {e}")
        return None

# --- ENDPOINT 1: ARTIST SEARCH (For Onboarding) ---
@app.get("/search-artists")
def search_artists(q: str = ""):
    print(f"🔎 Searching for artist: {q}")
    try:
        # If query is empty, return trending/popular artists
        if not q:
            popular_ids = [
                "06HL4z0CvFAsei5YN2709F", # Taylor Swift
                "1Xyo4u8uXC1ZmMpatF05PJ", # The Weeknd
                "3Nrfpe0tUJi4Q4DXYWgMUX", # BTS
                "4YRxEOlBFzK056c9cEL9wz", # Arijit Singh
                "1uNFoZAHBGtllmzznpCI3s", # Justin Bieber
                "5pKCCKE2ajJHZ9KAiaK11H", # Rihanna
                "3TVXtAsR1Inumwj472S9r4", # Drake
                "6eUKZXaKkcviH0Ku9w2n3V", # Ed Sheeran
                "0du5cEVh5yTK9QJze8zA0C", # Bruno Mars
            ]
            results = sp_generic.artists(popular_ids)
            return {
                "artists": [
                    {"name": a['name'], "image": a['images'][0]['url'] if a['images'] else None, "id": a['id']}
                    for a in results['artists']
                ]
            }

        # Otherwise, search Spotify
        results = sp_generic.search(q=q, type='artist', limit=5)
        return {
            "artists": [
                {"name": a['name'], "image": a['images'][0]['url'] if a['images'] else None, "id": a['id']}
                for a in results['artists']['items']
            ]
        }
    except Exception as e:
        print(f"❌ Search Error: {e}")
        return {"artists": []}

# --- ENDPOINT 2: INSTANT DAILY ANALYSIS ---
@app.post("/analyze")
def analyze_mood(entry: JournalEntry):
    print(f"📝 Analyzing Entry (Profile: {entry.music_profile})...")
    
    # Defaults
    data = {
        "mood": "Calm", "artist": "Lofi Girl", "reason": "Just breathing.", 
        "score": 5, "track_name": "lofi hip hop radio", 
        "image_url": "https://i.scdn.co/image/ab67616d0000b2735755e164993798e0c9ef7d7a"
    }

    try:
        prompt = f"""
        Analyze this diary entry: "{entry.text}" (Time: {entry.local_time}).
        
        USER TASTE PROFILE (The user LOVES these artists):
        "{entry.music_profile}"
        
        Task:
        1. Identify the Mood (1 word) & Score (1-10).
           🔴 SCORING RUBRIC:
           - 1-3: High Distress (Sadness, Anxiety, Anger).
           - 4-6: Neutral, Calm, Bored.
           - 7-10: Happy, Excited, Proud.
        
        2. Suggest ONE song.
           🔴 RECOMMENDATION RULES (CRITICAL):
           - If the user has specific artists in their PROFILE, prioritize a song by those artists (or a very similar style) that matches the MOOD.
           - Example: If user loves "Taylor Swift" and is Sad -> Suggest "this is me trying" or "All Too Well".
           - Example: If user loves "The Weeknd" and is Happy -> Suggest "Starboy" or "Blinding Lights".
           - ANTI-CLICHÉ: Do NOT suggest "Happy" by Pharrell or "Someone Like You" by Adele unless explicitly requested.
        
        3. Give a short reason (mentioning their taste if relevant).

        Return JSON keys: mood, artist, track_name, reason, score.
        """
        
        ai_data = call_llama(prompt)
        if ai_data:
            data.update(ai_data)

            # Search generic spotify to get the cover art
            query = f"track:{data.get('track_name', '')} artist:{data.get('artist', '')}"
            results = sp_generic.search(q=query, type='track', limit=1)
            if results['tracks']['items']:
                track = results['tracks']['items'][0]
                data['track_name'] = track['name']
                data['artist'] = track['artists'][0]['name']
                data['image_url'] = track['album']['images'][0]['url']
            
    except Exception as e:
        print(f"❌ Analysis Error: {e}")

    return data

# --- ENDPOINT 3: WEEKLY REPORT ---
@app.post("/analyze-mood-music")
def analyze_week(request: AnalysisRequest):
    print(f"🧠 Deep Analyzing {len(request.logs)} entries...")
    
    history = "\n".join([f"- {l.date}: {l.mood_score}/10 mood. Intent: {l.intention}. Wrote: {l.journal_content}" for l in request.logs])

    prompt = f"""
    You are an AI Therapist & DJ.
    
    USER TASTE PROFILE:
    "{request.music_profile}"
    
    LAST 7 DAYS JOURNAL:
    {history}

    Task:
    1. Find a psychological pattern.
    2. Curate a "Mood Uplift" Playlist of 5 songs.
       - STRICTLY follow the User's Taste Profile for genre/style.
       - If they like Rap, give Rap. If they like Indie, give Indie.
    3. Give 1 sentence of actionable advice.

    Return JSON:
    {{
        "mood_summary": "String",
        "pattern_insight": "String",
        "playlist_title": "String",
        "suggested_tracks": ["Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist"],
        "advice": "String"
    }}
    """
    
    try:
        return call_llama(prompt)
    except Exception as e:
        print(f"❌ Error: {e}")
        return {
            "mood_summary": "Neutral", "pattern_insight": "Keep writing.", 
            "playlist_title": "Daily Mix", "suggested_tracks": [], "advice": "Take it easy."
        }
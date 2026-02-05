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

# Initialize Spotify (Generic - for searching covers)
try:
    sp_generic = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
        client_id=SPOTIFY_CLIENT_ID,
        client_secret=SPOTIFY_CLIENT_SECRET
    ))
except Exception as e:
    print(f"⚠️ Spotify Client Error: {e}")

app = FastAPI()

# --- CORS (SECURITY) SETUP ---
# This allows your Flutter app (from Chrome or Android) to talk to this server.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow ALL origins (good for development)
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
    # Defaults to "General Pop" for Chrome/Bypass testing
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
            model="llama-3.3-70b-versatile", # UPDATED MODEL
            temperature=0.6,
            response_format={"type": "json_object"} 
        )
        return json.loads(completion.choices[0].message.content)
    except Exception as e:
        print(f"⚠️ Groq Error: {e}")
        return None

# --- ENDPOINT: SPOTIFY SYNC (One-Time Setup) ---
@app.post("/sync-spotify-data")
def sync_spotify(request: SpotifyTokenRequest):
    print("🎵 Syncing User Music Taste...")
    try:
        sp_user = spotipy.Spotify(auth=request.token)
        
        # Get Top 20 Artists & Tracks to build a "DNA Profile"
        top_artists = sp_user.current_user_top_artists(limit=20, time_range='medium_term')
        artist_names = [a['name'] for a in top_artists['items']]
        
        top_tracks = sp_user.current_user_top_tracks(limit=20, time_range='medium_term')
        track_names = [f"{t['name']} by {t['artists'][0]['name']}" for t in top_tracks['items']]
        
        # Create a descriptive string for the AI
        profile_text = f"User loves artists: {', '.join(artist_names)}. Loves songs: {', '.join(track_names)}."
        
        print(f"✅ Success! Created Taste Profile with {len(artist_names)} artists.")
        return {"music_profile": profile_text}

    except Exception as e:
        print(f"❌ Spotify Sync Error (Ignored for Bypass): {e}")
        # FAIL-SAFE: Return dummy profile so app doesn't crash
        return {"music_profile": "General Pop"}

# --- ENDPOINT 1: INSTANT DAILY ANALYSIS ---
@app.post("/analyze")
def analyze_mood(entry: JournalEntry):
    print(f"📝 Analyzing Entry (Profile: {entry.music_profile[:20]}...)...")
    
    # Defaults (Fallback)
    data = {
        "mood": "Calm", "artist": "Lofi Girl", "reason": "Just breathing.", 
        "score": 5, "track_name": "lofi hip hop radio", 
        "image_url": "https://i.scdn.co/image/ab67616d0000b2735755e164993798e0c9ef7d7a"
    }

    try:
        # PROMPT: STRICT SCORING RUBRIC ADDED
        prompt = f"""
        Analyze this diary entry: "{entry.text}" (Time: {entry.local_time}).
        
        USER TASTE PROFILE:
        "{entry.music_profile}"
        
        Task:
        1. Identify the Mood (1 word) & Score (1-10).
           🔴 CRITICAL SCORING RUBRIC (YOU MUST FOLLOW THIS):
           - 1 to 3: High Distress, Sadness, Anxiety, Anger, Grief. (User is struggling).
           - 4 to 6: Neutral, Calm, Tired, Bored, "Just Okay".
           - 7 to 10: Happy, Excited, Grateful, Radiant, Proud.
        
        2. Suggest ONE song.
           - CONDITION: If Profile is "General Pop" or empty, suggest ANY high-quality song that matches the mood perfectly.
           - CONDITION: If Profile has specific artists, suggest a song that matches their *style* (does not have to be exactly from the list).
        
        3. Give a short reason.

        Return JSON keys: mood, artist, track_name, reason, score.
        """
        
        ai_data = call_llama(prompt)
        if ai_data:
            data.update(ai_data)

            # Search generic spotify to get the cover art for the suggested song
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

# --- ENDPOINT 2: WEEKLY REPORT ---
@app.post("/analyze-mood-music")
def analyze_week(request: AnalysisRequest):
    print(f"🧠 Deep Analyzing {len(request.logs)} entries...")
    
    # Format history for the prompt
    history = "\n".join([f"- {l.date}: {l.mood_score}/10 mood. Intent: {l.intention}. Wrote: {l.journal_content}" for l in request.logs])

    prompt = f"""
    You are an AI Therapist & DJ.
    
    USER TASTE PROFILE:
    "{request.music_profile}"
    
    LAST 7 DAYS JOURNAL:
    {history}

    Task:
    1. Find a psychological pattern (e.g., "You tend to feel anxious on Sunday nights").
    2. Curate a "Mood Uplift" Playlist of 5 songs.
       - IF PROFILE IS "General Pop": Just pick 5 excellent songs that match the mood solution.
       - OTHERWISE: Use their taste profile as a style guide.
    3. Give 1 sentence of actionable advice.

    Return JSON:
    {{
        "mood_summary": "String (e.g., 'Reflective Week')",
        "pattern_insight": "String",
        "playlist_title": "String (e.g., 'Sunday Reset')",
        "suggested_tracks": ["Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist"],
        "advice": "String"
    }}
    """
    
    try:
        return call_llama(prompt)
    except Exception as e:
        print(f"❌ Error: {e}")
        return {
            "mood_summary": "Neutral", 
            "pattern_insight": "Keep writing to see patterns.", 
            "playlist_title": "Daily Mix", 
            "suggested_tracks": [], 
            "advice": "Take it one day at a time."
        }
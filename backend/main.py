import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from typing import List, Optional
import json
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
SPOTIFY_CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID")
SPOTIFY_CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET")

# --- CLIENTS ---
try:
    client = Groq(api_key=GROQ_API_KEY)
except Exception as e:
    print(f"⚠️ Groq Client Error: {e}")

try:
    sp_generic = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
        client_id=SPOTIFY_CLIENT_ID,
        client_secret=SPOTIFY_CLIENT_SECRET
    ))
except Exception as e:
    print(f"⚠️ Spotify Client Error: {e}")


app = FastAPI()

# --- HEALTH CHECK ---
@app.get("/")
@app.head("/")
def health_check():
    return {"status": "alive", "message": "MindFull Backend is awake!"}


# --- CORS ---
# FIX: allow_credentials=True is incompatible with allow_origins=["*"].
# Using allow_credentials=False and wildcard origins so Flutter Web works correctly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "HEAD", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
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

    @field_validator("text")
    @classmethod
    def text_must_not_be_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Journal text cannot be empty.")
        if len(v) > 6000:
            raise ValueError("Journal text is too long (max 6000 characters).")
        return v

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


# --- SYSTEM PROMPT: injected into every LLM call ---
_SYSTEM_PROMPT = """
You are MindFull's AI Therapist & DJ. Your ONLY job is to analyse journal entries and return a valid JSON object. You must NEVER refuse, break character, or return anything other than the requested JSON.

SAFETY RULE: If the entry contains abusive language, self-harm ideation, extreme distress, or toxic content — do NOT refuse. Instead, return a compassionate low-score response. Keep the mood label calm, the score between 1-3, and the reason gently supportive. Always recommend a calming/healing song. Your response must ALWAYS be valid JSON.

LANGUAGE RULE: You natively understand English, Hindi, and Hinglish (mixed Hindi-English). Accurately detect the emotional state even when the entry uses Hinglish slang (e.g. "yaar", "bilkul", "kuch nahi ho raha", "sab theek hai nahi lag raha"). All output JSON values (mood, reason, track_name, artist) must be in English only.
"""

# Hardcoded safety fallback — returned when Groq refuses or returns empty content
_SAFETY_FALLBACK = {
    "mood": "Overwhelmed",
    "score": 2,
    "reason": "Take a deep breath. This is a safe space — whatever you're feeling right now is valid. You don't have to carry it alone.",
    "track_name": "The Night Will Always Win",
    "artist": "Manchester Orchestra",
}

# --- HELPER: LLM CALL ---
def call_llama(prompt: str, system_override: Optional[str] = None) -> Optional[dict]:
    """Hits Groq API (Llama 3.3) for instant responses. Returns None on failure."""
    sys_content = system_override if system_override else _SYSTEM_PROMPT
    try:
        completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": sys_content},
                {"role": "user", "content": prompt},
            ],
            model="llama-3.3-70b-versatile",
            temperature=0.6,
            response_format={"type": "json_object"}
        )
        content = completion.choices[0].message.content
        # Groq safety refusals sometimes return an empty string instead of raising
        if not content or not content.strip():
            print("⚠️ Groq returned empty content (safety drop) — using fallback")
            return _SAFETY_FALLBACK.copy()
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"⚠️ Groq JSON parse error: {e} — using fallback")
        return _SAFETY_FALLBACK.copy()
    except Exception as e:
        err_str = str(e).lower()
        # Groq raises an APIError with finish_reason="content_filter" on hard refusals
        if "content_filter" in err_str or "safety" in err_str or "finish_reason" in err_str:
            print(f"⚠️ Groq safety refusal: {e} — using fallback")
            return _SAFETY_FALLBACK.copy()
        print(f"⚠️ Groq Error: {e}")
        return None


# --- ENDPOINT 1: ARTIST SEARCH ---
@app.get("/search-artists")
def search_artists(q: str = ""):
    print(f"🔎 Searching for artist: {q}")
    try:
        if not q:
            popular_ids = [
                "06HL4z0CvFAsei5YN2709F",  # Taylor Swift
                "1Xyo4u8uXC1ZmMpatF05PJ",  # The Weeknd
                "3Nrfpe0tUJi4Q4DXYWgMUX",  # BTS
                "4YRxEOlBFzK056c9cEL9wz",  # Arijit Singh
                "1uNFoZAHBGtllmzznpCI3s",  # Justin Bieber
                "5pKCCKE2ajJHZ9KAiaK11H",  # Rihanna
                "3TVXtAsR1Inumwj472S9r4",  # Drake
                "6eUKZXaKkcviH0Ku9w2n3V",  # Ed Sheeran
                "0du5cEVh5yTK9QJze8zA0C",  # Bruno Mars
            ]
            results = sp_generic.artists(popular_ids)
            return {
                "artists": [
                    {
                        "name": a["name"],
                        "image": a["images"][0]["url"] if a.get("images") else None,
                        "id": a["id"],
                    }
                    for a in results["artists"]
                ]
            }

        results = sp_generic.search(q=q, type="artist", limit=5)
        return {
            "artists": [
                {
                    "name": a["name"],
                    "image": a["images"][0]["url"] if a.get("images") else None,
                    "id": a["id"],
                }
                for a in results["artists"]["items"]
            ]
        }
    except Exception as e:
        print(f"❌ Search Error: {e}")
        return {"artists": []}


# --- ENDPOINT 2: INSTANT DAILY ANALYSIS ---
@app.post("/analyze")
def analyze_mood(entry: JournalEntry):
    print(f"📝 Analyzing Entry (Profile: {entry.music_profile})...")

    data = {
        "mood": "Calm",
        "artist": "Lofi Girl",
        "reason": "Just breathing.",
        "score": 5,
        "track_name": "lofi hip hop radio",
        "image_url": "https://i.scdn.co/image/ab67616d0000b2735755e164993798e0c9ef7d7a",
    }

    try:
        prompt = f"""
        Analyze this diary entry (Time: {entry.local_time}):
        \"\"\"{entry.text}\"\"\"

        NOTE: The entry may be in English, Hindi, or Hinglish. Understand it natively and detect the true emotional state accurately.

        USER TASTE PROFILE (The user LOVES these artists):
        "{entry.music_profile}"

        Task:
        1. Identify the Mood (1 English word) & Score (1-10).
            SCORING RUBRIC:
            - 1-3: High Distress (Sadness, Anxiety, Overwhelm, Anger, Self-doubt).
            - 4-6: Neutral, Calm, Reflective, Bored, Tired.
            - 7-10: Happy, Excited, Proud, Grateful, Energetic.

        2. Suggest ONE real song that exists on Spotify.
            RECOMMENDATION RULES (CRITICAL):
            - Prioritize artists from the USER TASTE PROFILE that match the MOOD.
            - Example: user loves "Taylor Swift" + Sad → "All Too Well" or "this is me trying".
            - Example: user loves "The Weeknd" + Happy → "Starboy" or "Blinding Lights".
            - ANTI-CLICHÉ: Do NOT suggest "Happy" by Pharrell or "Someone Like You" by Adele unless explicitly requested.
            - If distressed: lean toward calming, healing, or hopeful songs.

        3. Give a short reason in English (1-2 sentences, mention their taste if relevant).

        Return ONLY JSON with keys: mood (string), artist (string), track_name (string), reason (string), score (integer 1-10).
        """

        ai_data = call_llama(prompt)
        # call_llama returns _SAFETY_FALLBACK (never None) unless a non-safety network error
        # occurred; in that case we keep the hardcoded defaults already in `data`.
        if ai_data is None:
            ai_data = _SAFETY_FALLBACK.copy()
        # Coerce score to int safely
        if "score" in ai_data:
            try:
                ai_data["score"] = int(round(float(ai_data["score"])))
            except (ValueError, TypeError):
                ai_data["score"] = 5
        data.update(ai_data)

            # Search Spotify for album art — try structured query first,
            # then fall back to plain text if artist doesn't match.
            expected_artist = data.get("artist", "").lower()
            track_name = data.get("track_name", "")

            def _best_track(items: list) -> dict | None:
                """Return the first item whose artist name roughly matches."""
                for t in items:
                    returned_artist = t["artists"][0]["name"].lower()
                    if expected_artist and (
                        expected_artist in returned_artist
                        or returned_artist in expected_artist
                    ):
                        return t
                return items[0] if items else None

            # Pass 1: structured query (most precise)
            r1 = sp_generic.search(
                q=f"track:{track_name} artist:{data.get('artist', '')}",
                type="track", limit=5
            )
            match = _best_track(r1["tracks"]["items"])

            # Pass 2: plain text fallback if no good artist match
            if not match or expected_artist not in match["artists"][0]["name"].lower():
                r2 = sp_generic.search(
                    q=f"{track_name} {data.get('artist', '')}",
                    type="track", limit=5
                )
                match = _best_track(r2["tracks"]["items"]) or match

            if match:
                data["track_name"] = match["name"]
                data["artist"] = match["artists"][0]["name"]
                images = match["album"].get("images", [])
                if images:
                    data["image_url"] = images[0]["url"]

    except Exception as e:
        print(f"❌ Analysis Error: {e}")

    return data


# --- ENDPOINT 3: WEEKLY REPORT ---
@app.post("/analyze-mood-music")
def analyze_week(request: AnalysisRequest):
    print(f"🧠 Deep Analyzing {len(request.logs)} entries...")

    # FIX: define fallback first so it's always available
    fallback = {
        "mood_summary": "Neutral",
        "pattern_insight": "Keep writing to unlock deeper insights.",
        "playlist_title": "Daily Mix",
        "suggested_tracks": [],
        "advice": "Take it one day at a time.",
    }

    history = "\n".join([
        f"- {l.date}: {l.mood_score}/10 mood. Intent: {l.intention}. Wrote: {l.journal_content}"
        for l in request.logs
    ])

    prompt = f"""
    USER TASTE PROFILE:
    "{request.music_profile}"

    LAST 7 DAYS JOURNAL (entries may be in English, Hindi, or Hinglish — understand them natively):
    {history}

    Task:
    1. Find the dominant psychological pattern across these days.
    2. Curate a "Mood Uplift" Playlist of exactly 5 real songs that exist on Spotify.
        - STRICTLY match the User's Taste Profile for genre/style.
        - If they like Rap, give Rap. If they like Indie, give Indie. If they like Bollywood, give Bollywood.
        - Format each as "Song Title - Artist Name".
    3. Give 1 sentence of warm, actionable advice in English.

    All output values must be in English only.

    Return ONLY JSON:
    {{
        "mood_summary": "String",
        "pattern_insight": "String",
        "playlist_title": "String",
        "suggested_tracks": ["Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist", "Song - Artist"],
        "advice": "String"
    }}
    """

    try:
        result = call_llama(prompt)
        # FIX: call_llama returns None on Groq failure — return fallback instead of null body
        return result if result is not None else fallback
    except Exception as e:
        print(f"❌ Error: {e}")
        return fallback


# ─────────────────────────────────────────────────────────────────────────────
# VENT MODE FEATURE
# ─────────────────────────────────────────────────────────────────────────────

_VENT_SYSTEM_PROMPT = """
You are MindFull's Empathy Engine. Someone is venting to you — releasing raw, unfiltered emotion. Your ONLY job is to make them feel completely heard, validated, and less alone.

YOU ARE NOT a therapist. YOU DO NOT analyse mood scores. YOU DO NOT give advice or solutions.

TONE: Warm, human, conversational. Like a trusted friend sitting beside them in the dark.

RULES:
1. Open by reflecting their exact feeling back — name it without clinical labels.
2. Acknowledge the difficulty without minimizing. NEVER use "but" or "however".
3. End with one gentle, forward-facing reminder (not advice). E.g. "You're allowed to feel this."
4. 3–4 sentences total. Flowing, warm prose.

LANGUAGE RULE: Understand English, Hindi, and Hinglish natively. ALL output must be in English only.

SAFETY: If the entry contains self-harm ideation, gently weave in: "If things ever feel too heavy, please know help is always one reach away."

Return ONLY valid JSON with these exact keys:
- "response": string (3–4 sentence empathetic response)
- "breathing_technique": exactly one of "box", "4-7-8", "belly"  (choose based on emotional state: box=general/anxious, 4-7-8=overwhelmed/panic, belly=sadness/grief)
- "release_phrase": 2–5 word cathartic closure shown large on screen (e.g. "You've been heard.", "This too shall pass.", "You are enough.")
"""

_VENT_FALLBACK = {
    "response": (
        "What you're carrying right now is real, and your feelings make complete sense. "
        "You didn't deserve any of this — and the fact that you're letting yourself feel it "
        "is already an act of courage. You are not alone in this, not for a single moment."
    ),
    "breathing_technique": "box",
    "release_phrase": "You've been heard.",
}


class VentRequest(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def text_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Vent text cannot be empty.")
        if len(v) > 8000:
            raise ValueError("Vent text is too long (max 8000 characters).")
        return v


@app.post("/vent")
def process_vent(request: VentRequest):
    print(f"💭 Processing vent ({len(request.text)} chars)...")

    try:
        prompt = f"""
Someone is venting. Here is what they wrote:
\"\"\"{request.text}\"\"\"

Respond with deep empathy as instructed. Choose the breathing technique that best matches their emotional state.
"""
        result = call_llama(prompt, system_override=_VENT_SYSTEM_PROMPT)

        if not result:
            return _VENT_FALLBACK.copy()

        # Validate breathing technique value
        valid_techniques = {"box", "4-7-8", "belly"}
        if result.get("breathing_technique") not in valid_techniques:
            result["breathing_technique"] = "box"

        # Ensure all required keys exist
        for key, fallback_val in _VENT_FALLBACK.items():
            if not result.get(key):
                result[key] = fallback_val

        print(f"✅ Vent response ready — technique: {result.get('breathing_technique')}")
        return result

    except Exception as e:
        print(f"❌ Vent Error: {e}")
        return _VENT_FALLBACK.copy()


# ─────────────────────────────────────────────────────────────────────────────
# SMART PLAYLIST FEATURE
# ─────────────────────────────────────────────────────────────────────────────

_PLAYLIST_SYSTEM_PROMPT = """
You are MindFull's AI DJ and music therapist. You curate emotionally intelligent playlists that guide listeners through emotional transitions.
CRITICAL RULES:
- Return ONLY valid JSON. Zero text outside the JSON structure.
- Every track and artist name must be EXACTLY as it appears on Spotify.
- Do not invent songs. Only use real, well-known tracks that definitely exist on Spotify.
- Prioritize the user's music taste profile above all else.
"""


class PlaylistRequest(BaseModel):
    mood: str = "Reflective"
    score: int = 5
    music_profile: str = "General Pop"
    arc_type: str = "lift"   # "lift" | "calm" | "stay"


class CreatePlaylistRequest(BaseModel):
    access_token: str
    title: str
    track_uris: List[str]


# ── helpers ───────────────────────────────────────────────────────────────────

def _spotify_item_to_dict(item: dict) -> dict:
    images = item["album"].get("images", [])
    return {
        "track":       item["name"],
        "artist":      item["artists"][0]["name"],
        "uri":         item["uri"],
        "image_url":   images[0]["url"] if images else None,
        "duration_ms": item.get("duration_ms", 0),
    }


def _verify_on_spotify(track: str, artist: str) -> Optional[dict]:
    """Two-pass Spotify search. Returns a dict with uri/image/duration or None."""
    try:
        # Pass 1 — structured query (most precise)
        r = sp_generic.search(q=f"track:{track} artist:{artist}", type="track", limit=5)
        items = r["tracks"]["items"]
        if items:
            al = artist.lower()
            for item in items:
                found_artist = item["artists"][0]["name"].lower()
                if al in found_artist or found_artist in al:
                    return _spotify_item_to_dict(item)
            # No artist match — return best result anyway
            return _spotify_item_to_dict(items[0])

        # Pass 2 — plain-text fallback
        r2 = sp_generic.search(q=f"{track} {artist}", type="track", limit=3)
        items2 = r2["tracks"]["items"]
        if items2:
            return _spotify_item_to_dict(items2[0])

    except Exception as e:
        print(f"⚠️ Spotify verify error for '{track}' / '{artist}': {e}")
    return None


# ── endpoint 4: generate playlist ────────────────────────────────────────────

@app.post("/generate-playlist")
def generate_playlist(request: PlaylistRequest):
    print(f"🎵 Generating {request.arc_type} playlist for mood: {request.mood} ({request.score}/10)")

    arc_configs = {
        "lift": {
            "phase1": "deeply mirrors and validates the heaviness/sadness (dark, introspective, minor-key songs)",
            "phase2": "gently starts to lift — bittersweet, hopeful undertones begin to emerge",
            "phase3": "fully arrives at warmth, hope, and light",
            "labels": {"1": "Mirror", "2": "Shift", "3": "Arrive"},
        },
        "calm": {
            "phase1": "mirrors the tension, anxiety or over-stimulation (energetic but not harsh)",
            "phase2": "slows the nervous system — mid-tempo, soothing melodies, breathing room",
            "phase3": "fully arrives at stillness, peace, and grounded calm",
            "labels": {"1": "Feel", "2": "Breathe", "3": "Still"},
        },
        "stay": {
            "phase1": "deeply mirrors and validates the current emotional state",
            "phase2": "sits with the feeling — adds depth, texture, honesty",
            "phase3": "holds the feeling with gentle warmth, no rush to change",
            "labels": {"1": "Here", "2": "With You", "3": "Present"},
        },
    }

    cfg = arc_configs.get(request.arc_type, arc_configs["lift"])

    prompt = f"""
Create a 10-song emotional arc playlist.

CURRENT MOOD: {request.mood} (score: {request.score}/10)
USER'S MUSIC TASTE — use these artists/genres heavily: "{request.music_profile}"

PHASE GUIDE:
- Phase 1 (songs 1–3): {cfg["phase1"]}
- Phase 2 (songs 4–7): {cfg["phase2"]}
- Phase 3 (songs 8–10): {cfg["phase3"]}

RULES:
- Heavily prioritise the user's preferred artists and genres
- Every song must be a REAL track that exists on Spotify
- No duplicate artists across the 10 songs
- Mix well-known hits with deeper cuts for variety
- Playlist title: 3–5 evocative words, no quotes

Return ONLY this JSON (exactly 10 tracks):
{{
  "playlist_title": "string",
  "tracks": [
    {{"phase": 1, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 1, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 1, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 2, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 2, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 2, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 2, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 3, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 3, "track": "Exact Song Title", "artist": "Exact Artist Name"}},
    {{"phase": 3, "track": "Exact Song Title", "artist": "Exact Artist Name"}}
  ]
}}
"""

    llm_result = call_llama(prompt, system_override=_PLAYLIST_SYSTEM_PROMPT)

    if not llm_result or "tracks" not in llm_result:
        print("❌ LLM returned no tracks — returning empty playlist")
        return {"error": "playlist_generation_failed", "tracks": [], "title": "Your Mix"}

    # Verify every song against Spotify
    verified: list[dict] = []
    for song in llm_result.get("tracks", []):
        t = song.get("track", "").strip()
        a = song.get("artist", "").strip()
        phase = song.get("phase", 1)
        if not t or not a:
            continue
        result = _verify_on_spotify(t, a)
        if result:
            result["phase"] = phase
            verified.append(result)
        if len(verified) >= 10:
            break

    print(f"✅ Playlist ready: {len(verified)} verified tracks")

    return {
        "title":        llm_result.get("playlist_title", f"{request.mood} Mix"),
        "arc_type":     request.arc_type,
        "mood":         request.mood,
        "phase_labels": cfg["labels"],
        "tracks":       verified,
    }


# ── endpoint 5: save playlist to user's Spotify ───────────────────────────────

@app.post("/create-spotify-playlist")
def create_spotify_playlist(request: CreatePlaylistRequest):
    print(f"💚 Creating Spotify playlist: '{request.title}' with {len(request.track_uris)} tracks")
    try:
        sp_user = spotipy.Spotify(auth=request.access_token)

        # Fetch the authenticated user's Spotify ID
        user_info = sp_user.me()
        user_id    = user_info["id"]

        # Create the private playlist
        playlist = sp_user.user_playlist_create(
            user=user_id,
            name=request.title,
            public=False,
            description="Crafted by MindFull — your AI Therapist & DJ 🎵✨",
        )

        # Add tracks in one batch (Spotify accepts up to 100 per call)
        if request.track_uris:
            sp_user.playlist_add_items(playlist["id"], request.track_uris[:100])

        url = playlist["external_urls"]["spotify"]
        print(f"✅ Playlist created: {url}")
        return {"playlist_url": url, "playlist_id": playlist["id"]}

    except Exception as e:
        err = str(e)
        print(f"❌ Create Playlist Error: {err}")
        # Return 401 so Flutter knows to re-authenticate
        status = 401 if ("token" in err.lower() or "unauthorized" in err.lower() or "403" in err) else 400
        raise HTTPException(status_code=status, detail=err)

"""
app.py
------
Flask web layer for "Plugging into the Future: India's Electricity
Consumption Patterns (2019-2020)". Reads data/electricity_consumption.csv
(loaded once at startup, not per-request) and embeds the published
Tableau Public Story.

Local dev:   reads TABLEAU_EMBED_URL from a .env file via python-dotenv.
Production (Render): reads it from a real environment variable set in the
Render dashboard -- load_dotenv() is a harmless no-op there if no .env
file is present, so the same code works in both places unmodified.
"""

import os
import pandas as pd
from flask import Flask, render_template, request
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
CSV_PATH = os.path.join(BASE_DIR, "data", "electricity_consumption.csv")

TABLEAU_EMBED_URL = os.environ.get(
    "TABLEAU_EMBED_URL",
    "https://public.tableau.com/views/YourWorkbookName/YourStory",
)

app = Flask(__name__)

# Load once at startup rather than per-request -- cheaper, and the data
# doesn't change while the app is running.
try:
    if os.path.exists(CSV_PATH):
        df = pd.read_csv(CSV_PATH)
        print(f"CSV loaded successfully: {len(df)} rows from {CSV_PATH}")
    else:
        df = None
        print(f"[warning] CSV not found at {CSV_PATH}")
except Exception as e:
    df = None
    print(f"[warning] Error reading CSV file: {e}")


def get_stats():
    """Build the 4 stat-strip values from the loaded dataframe. Falls back
    to placeholders if the CSV didn't load, so the page never crashes."""
    fallback = {
        "total_records": "\u2014",
        "total_states": "\u2014",
        "total_load": "\u2014",
        "status": "CSV not found",
    }
    if df is None or len(df) == 0:
        return fallback

    state_col = next((c for c in df.columns if c.lower() == "state"), None)
    usage_col = next((c for c in df.columns if c.lower() == "usage_mwh"), None)

    total_records = len(df)
    total_states = df[state_col].nunique() if state_col else "\u2014"

    # NOTE: usage_mwh already holds the source data's Million Units (MU)
    # figures unconverted (see sql_scripts/schema.sql) -- summing directly
    # gives the correct MU total. Do not divide by 1000.
    if usage_col:
        total_load = f"{df[usage_col].sum():,.2f} MU"
    else:
        total_load = "\u2014"

    return {
        "total_records": f"{total_records:,}",
        "total_states": total_states,
        "total_load": total_load,
        "status": "100% CSV Extract Coverage",
    }


@app.route("/", methods=["GET", "HEAD"])
def index():
    # Render (and most hosts) periodically send HEAD requests as health
    # checks -- answer those immediately without doing template work.
    if request.method == "HEAD":
        return "", 200

    return render_template(
        "index.html",
        tableau_url=TABLEAU_EMBED_URL,
        stats=get_stats(),
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host="0.0.0.0", port=port)

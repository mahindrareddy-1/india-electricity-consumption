# Plugging into the Future: India's Electricity Consumption Patterns (2019–2020)

State-wise daily electricity consumption across 33 Indian states/UTs,
analyzed for national trends, regional disparities, and the 2020 COVID-19
lockdown's impact and recovery. Built on MySQL, Tableau, and Flask.

## Folder Structure
```
india-electricity-consumption/
├── data/
│   ├── electricity_consumption.csv        # clean export from MySQL, 16,434 rows
│   ├── vw_monthly_national_trend.csv      # exported view, Scenario 1
│   ├── vw_regional_demand.csv             # exported view, Scenario 2
│   └── vw_lockdown_recovery.csv           # exported view, Scenario 3
├── sql_scripts/
│   ├── schema.sql                          # table + indexes + dedup transform
│   └── aggregation.sql                     # 3 views, one per scenario
├── web_app/
│   ├── app.py                              # Flask app (reads its own data/ copy -> HTML)
│   ├── data/
│   │   └── electricity_consumption.csv     # self-contained copy -- see note below
│   ├── requirements.txt
│   ├── runtime.txt                         # pins Python version for Render
│   ├── .env.example                        # copy to .env locally; on Render, use dashboard env vars instead
│   ├── templates/
│   │   └── index.html                      # landing page + Tableau embed
│   └── static/                             # (reserved for future assets)
├── tableau/
│   └── README.txt                          # save your .twbx workbook here
├── .gitignore
└── README.md
```

**Why `electricity_consumption.csv` exists in two places:** Render deploys
are scoped to a "Root Directory" — for this project that's `web_app/`.
Anything outside that folder (like the top-level `data/`) isn't visible to
the deployed app at all, so `app.py` reads its own local copy at
`web_app/data/electricity_consumption.csv`. The top-level `data/` folder
still exists for the MySQL/Tableau side of the workflow. If you rebuild the
database and re-export, copy the new CSV into both locations.

**Why the CSVs and not a live MySQL connection from Flask:** MySQL is still where
the data is transformed (staging → dedup → views, all in `sql_scripts/`), and
it's still what Tableau connects to while you're authoring. But the Flask app
itself reads the CSV directly rather than opening a live DB connection —
meaning it works the same locally and on Render without MySQL running
anywhere near the deployed service.

## Tech Stack
MySQL &middot; Tableau Desktop/Public &middot; Python (Flask) &middot; HTML/CSS &middot; Git

## Deploying to Render

1. Push this repo to GitHub (see the Git steps given earlier in this project's setup).
2. On **render.com** → **New +** → **Web Service** → connect your GitHub repo.
3. Configure:
   - **Root Directory**: `web_app` (critical — this is what makes `app.py`, `requirements.txt`, and `web_app/data/` all resolve correctly)
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
   - **Instance Type**: Free is fine for a student submission
4. Under **Environment**, add a variable: `TABLEAU_EMBED_URL` = your published Story URL. Do this in the dashboard, not in a committed file — this is exactly what `.env` is for locally and env vars are for in production.
5. **Create Web Service**. First build takes 2-3 minutes; your app goes live at `your-service-name.onrender.com`.

**Free tier note:** Render spins the service down after 15 minutes with no traffic, and the next visitor waits ~30-60 seconds for it to wake back up. If you're demoing live to a mentor, open the URL a minute or two before you need it so it's already warm.

## Quick Start (Local Development)
See the full phase-by-phase execution guide for exact clicks and commands.
Short version:
```bash
# 1. MySQL: run schema.sql, import data/state_wise_power_consumption.csv,
#    then run aggregation.sql  (see execution guide for Workbench steps)
#    (data/electricity_consumption.csv + the 3 vw_*.csv files are already
#    exported for you -- only re-export if you rebuild the database)

# 2. Tableau: connect to electricity_db (or the CSVs above, if using
#    Tableau Public Desktop Edition), build the dashboard/story,
#    publish to Tableau Public, copy the embed URL

# 3. Flask app
cd web_app
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env         # then edit .env with your embed URL (no DB password needed)
python app.py
# visit http://127.0.0.1:5000
```

> **Security note (again):** the real database password showed up in
> `.env.example` a second time in a later upload of this project. Fixed
> again here — but if you're regenerating this file yourself, double-check
> before committing that it has a placeholder, not a real password. And
> actually rotate the MySQL `app_user` password in Workbench if you haven't
> yet; the same leaked password appearing twice suggests it's still in use.

## Data Notes
- Source columns: `state, region, usage_date, usage_mwh, latitude, longitude`
- `usage_mwh` carries the source data's Million Units (MU) figures unconverted
  (1 MU = 1,000 MWh) — multiply by 1000 if you need true MWh.
- The raw source CSV has 165 rows with two conflicting usage readings for
  the same state+date (5 dates in July 2019). schema.sql loads it into a
  staging table first, then de-duplicates into the final
  `electricity_consumption` table by averaging the conflicting pair. The
  final table has 16,434 rows (33 states x 498 reported dates), verified
  total usage 1,695,001.75 (MU, i.e. `usage_mwh` summed directly — don't
  divide by 1000, that column already holds MU-scale figures despite the
  name).
"# india-electricity-consumption" 

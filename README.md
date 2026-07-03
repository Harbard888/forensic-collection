# Weather Dashboard

This repository contains a small Weather Dashboard (frontend) and a simple Node/Express proxy to fetch weather from OpenWeatherMap without exposing the API key in the browser.

Setup (recommended: proxy)
1. Clone the repo and change into it.
2. The public/ folder contains index.html, styles.css, script.js (already added).
3. Create a .env file in the project root with the following content:

   OPENWEATHERMAP_KEY=your_api_key_here

4. Install dependencies:

   npm install

5. Start the server:

   npm start

6. Open http://localhost:3000 in your browser.

Quick frontend-only (not recommended for public repos)
- Set USE_PROXY = false in public/script.js and add const API_KEY = "YOUR_KEY" into the file.

Security
- Never commit your API key. Keep it in .env and ensure .gitignore contains .env.

Deployment
- Deploy the repo to a platform like Render, Heroku, Railway, or similar. Set OPENWEATHERMAP_KEY as an environment variable in the platform dashboard.

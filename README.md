# Weather Dashboard

This repository contains a small Weather Dashboard (frontend) and a simple Node/Express proxy to fetch weather from OpenWeatherMap without exposing the API key in the browser.


## Setup (recommended: Proxy)

1. Clone the repo and change into it.

2. The `public/` folder contains `index.html`, `styles.css`, `script.js` (already added).

3. Create a `.env` file in the project root with the following content:

```
OPENWEATHERMAP_KEY=your_api_key_here
```

4. Install dependencies:

```
npm install
```

5. Start the server (development):

```
npm start
```

6. Open http://localhost:3000 in your browser.


## Quick frontend-only (not recommended for public repos)

- Set `USE_PROXY = false` in `public/script.js` and add `const API_KEY = "YOUR_KEY"` into the file.


## Security

- Never commit your API key. Keep it in `.env` and ensure `.gitignore` contains `.env`.


## Deployment

Below are short guides for common deployment targets.

### Render (recommended — easy)

1. Create a Render account and connect your GitHub account.
2. Create a new Web Service and select this repository.
3. Set the build command to:

```
npm install
```

and the start command to:

```
node server.js
```

4. Under Environment, add the environment variable:

```
OPENWEATHERMAP_KEY = <your_api_key>
```

5. Deploy — Render will build and run the app and provide a public URL.


### Heroku (quick, uses Procfile)

1. Install Heroku CLI and login:

```
heroku login
```

2. Create an app or use an existing one:

```
heroku create your-app-name
```

3. Set the config var (OpenWeatherMap API key):

```
heroku config:set OPENWEATHERMAP_KEY=your_api_key_here
```

4. Push to Heroku (deploy):

```
git push heroku main
```

Heroku uses the provided `Procfile` (included) which runs `node server.js`.


### Docker (container)

Build locally and run:

```
docker build -t weather-dashboard .
docker run -p 3000:3000 -e OPENWEATHERMAP_KEY=your_api_key_here weather-dashboard
```

Push the image to Docker Hub / registry and use your hosting platform to run the container.


### GitHub Actions → Heroku (example)

You can add a GitHub Action to deploy to Heroku on push. Create a repository secret `HEROKU_API_KEY` and `HEROKU_APP_NAME`.

Example workflow (not included by default):

```yaml
name: Deploy to Heroku
on:
  push:
    branches:
      - main
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install deps
        run: npm ci
      - name: Build (if needed)
        run: echo "No build step"
      - name: Deploy to Heroku
        uses: akhileshns/heroku-deploy@v3.12.12
        with:
          heroku_api_key: ${{ secrets.HEROKU_API_KEY }}
          heroku_app_name: ${{ secrets.HEROKU_APP_NAME }}
          heroku_email: ${{ secrets.HEROKU_EMAIL }}
```

(If you prefer, I can add a workflow file that deploys to a platform you choose — tell me which one and I will create it and explain what secrets to add.)


## Notes

- Default server port is `3000`. Platforms usually map that port automatically or set `PORT` environment variable; `server.js` respects `process.env.PORT`.
- The front-end by default calls the proxy at `/api/weather`. Keep `USE_PROXY = true` in `public/script.js` for production.


## Troubleshooting

- If the app returns a 500 from `/api/weather`, verify `OPENWEATHERMAP_KEY` is set and valid.
- Check logs on the hosting platform for runtime errors.


---

If you want, I can now:
- Add a GitHub Actions workflow that deploys automatically to Render or Heroku (I will need the name of the target platform and guidance on what secrets you will set).
- Add a small health-check endpoint or basic monitoring.
- Create a Docker Compose file if you want to run additional services locally.

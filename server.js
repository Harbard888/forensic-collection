// Simple proxy to OpenWeatherMap to keep API key secret.
require('dotenv').config();
const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.OPENWEATHERMAP_KEY;

if (!API_KEY) {
  console.error('Missing OPENWEATHERMAP_KEY in .env');
  process.exit(1);
}

app.use(cors());
app.use(express.static('public'));

app.get('/health', (req, res) => {
  res.status(200).json({
    ok: true,
    service: 'forensic-collection',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/weather', async (req, res) => {
  try {
    const { city, lat, lon } = req.query;
    let currentUrl, forecastUrl;

    if (city) {
      currentUrl = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&units=metric&appid=${API_KEY}`;
      forecastUrl = `https://api.openweathermap.org/data/2.5/forecast?q=${encodeURIComponent(city)}&units=metric&appid=${API_KEY}`;
    } else if (lat && lon) {
      currentUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`;
      forecastUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`;
    } else {
      return res.status(400).json({ message: 'Provide city or lat+lon' });
    }

    const [cwRes, fcRes] = await Promise.all([
      fetch(currentUrl),
      fetch(forecastUrl),
    ]);

    const cw = await cwRes.json();
    const fc = await fcRes.json();

    if (!cwRes.ok || !fcRes.ok) {
      return res.status(400).json({
        message: 'Could not fetch weather data',
        details: {
          current: cw?.message || null,
          forecast: fc?.message || null,
        },
      });
    }

    res.json({ current: cw, forecast: fc });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Weather proxy listening on http://localhost:${PORT}`);
});
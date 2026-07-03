// CONFIG
const USE_PROXY = true; // Empfohlen: Proxy-Backend nutzen (kein API-Key im Browser)

const API_BASE = USE_PROXY ? "/api/weather" : "https://api.openweathermap.org/data/2.5";
const ICON_URL = (icon) => `https://openweathermap.org/img/wn/${icon}@2x.png`;

const $ = (id) => document.getElementById(id);
const searchBtn = $("searchBtn");
const geoBtn = $("geoBtn");
const cityInput = $("cityInput");
const message = $("message");
const current = $("current");
const forecast = $("forecast");
const cityNameEl = $("cityName");
const weatherIcon = $("weatherIcon");
const tempEl = $("temp");
const descEl = $("desc");
const detailsEl = $("details");
const forecastList = $("forecastList");

function showMessage(msg, isError = true){
  message.textContent = msg;
  message.style.color = isError ? "#b91c1c" : "#094c14";
}

function clearMessage(){ message.textContent = ""; }

async function fetchWeatherByCity(city){
  clearMessage();
  try{
    if(USE_PROXY){
      const res = await fetch(`${API_BASE}?city=${encodeURIComponent(city)}`);
      if(!res.ok) throw new Error(`Server returned ${res.status}`);
      return await res.json();
    } else {
      if(typeof API_KEY === "undefined") throw new Error("API_KEY missing in script (frontend mode).");
      const cw = await fetch(`${API_BASE}/weather?q=${encodeURIComponent(city)}&units=metric&appid=${API_KEY}`).then(r=>r.json());
      const fc = await fetch(`${API_BASE}/forecast?q=${encodeURIComponent(city)}&units=metric&appid=${API_KEY}`).then(r=>r.json());
      return { current: cw, forecast: fc };
    }
  }catch(err){
    throw err;
  }
}

async function fetchWeatherByCoords(lat, lon){
  clearMessage();
  try{
    if(USE_PROXY){
      const res = await fetch(`${API_BASE}?lat=${lat}&lon=${lon}`);
      if(!res.ok) throw new Error(`Server returned ${res.status}`);
      return await res.json();
    } else {
      if(typeof API_KEY === "undefined") throw new Error("API_KEY missing in script (frontend mode).");
      const cw = await fetch(`${API_BASE}/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`).then(r=>r.json());
      const fc = await fetch(`${API_BASE}/forecast?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`).then(r=>r.json());
      return { current: cw, forecast: fc };
    }
  }catch(err){ throw err; }
}

function renderCurrent(data){
  const c = data.current;
  if(!c || c.cod && c.cod !== 200){ showMessage("City not found"); return; }
  current.classList.remove("hidden");
  cityNameEl.textContent = `${c.name}, ${c.sys?.country || ""}`;
  weatherIcon.src = ICON_URL(c.weather[0].icon);
  weatherIcon.alt = c.weather[0].description || "weather";
  tempEl.textContent = `${Math.round(c.main.temp)}°C`;
  descEl.textContent = c.weather[0].description;
  detailsEl.textContent = `Humidity: ${c.main.humidity}% • Wind: ${c.wind.speed} m/s • Pressure: ${c.main.pressure} hPa`;
}

function renderForecast(data){
  const f = data.forecast;
  if(!f || f.cod && f.cod !== "200"){ forecast.classList.add("hidden"); return; }
  forecast.classList.remove("hidden");
  forecastList.innerHTML = "";
  const items = f.list.slice(0, 8);
  items.forEach(it => {
    const dt = new Date(it.dt * 1000);
    const item = document.createElement("div");
    item.className = "forecast-item";
    item.innerHTML = `
      <div style="font-size:13px">${dt.toLocaleString([], { weekday:'short', hour:'2-digit', minute:'2-digit' })}</div>
      <img src="${ICON_URL(it.weather[0].icon)}" alt="${it.weather[0].description}" style="width:64px;height:64px"/>
      <div style="font-weight:600">${Math.round(it.main.temp)}°C</div>
      <div style="color:var(--muted);font-size:13px">${it.weather[0].description}</div>
    `;
    forecastList.appendChild(item);
  });
}

searchBtn.addEventListener("click", async () => {
  const city = cityInput.value.trim();
  if(!city){ showMessage("Please enter a city."); return; }
  showMessage("Loading...", false);
  try{
    const data = await fetchWeatherByCity(city);
    clearMessage();
    renderCurrent(data);
    renderForecast(data);
  }catch(err){
    showMessage("Error fetching weather: " + err.message);
  }
});

geoBtn.addEventListener("click", () => {
  if(!navigator.geolocation){ showMessage("Geolocation not supported."); return; }
  showMessage("Getting location...", false);
  navigator.geolocation.getCurrentPosition(async pos => {
    try{
      const { latitude, longitude } = pos.coords;
      const data = await fetchWeatherByCoords(latitude, longitude);
      clearMessage();
      renderCurrent(data);
      renderForecast(data);
    }catch(err){
      showMessage("Error fetching weather: " + err.message);
    }
  }, err => {
    showMessage("Unable to get location: " + err.message);
  }, { timeout:10000 });
});

cityInput.addEventListener("keyup", (e) => { if(e.key === "Enter") searchBtn.click(); });

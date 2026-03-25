export default async function(ctx) {
  const AUTO = ctx.env.AUTO_LOCATION === "true";
  const cities = (ctx.env.CITIES || "Singapore").split(",");
  const rotateInterval = parseInt(ctx.env.ROTATE_INTERVAL || "10") * 60 * 1000;
  const TTL = parseInt(ctx.env.CACHE_TTL || "600");

  // ✅ 城市轮播 index
  const now = Date.now();
  const index = Math.floor(now / rotateInterval) % cities.length;
  const cityNameRaw = cities[index].trim();

  const cacheKey = `weather:${cityNameRaw}`;

  // ✅ 缓存
  const cached = await ctx.storage.get(cacheKey);
  if (cached && now - cached.time < TTL * 1000) {
    return render(cached.data, cached.city);
  }

  let lat, lon, cityName;

  // 📍 自动定位（只在第一个城市生效）
  if (AUTO && index === 0) {
    try {
      const loc = await ctx.location.getCurrent();
      lat = loc.latitude;
      lon = loc.longitude;
      cityName = loc.city || "My Location";
    } catch {}
  }

  // fallback 城市解析
  if (!lat) {
    const geo = await ctx.http.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityNameRaw)}&count=1`
    );
    const g = await geo.json();

    lat = g.results[0].latitude;
    lon = g.results[0].longitude;
    cityName = g.results[0].name;
  }

  // 🌦️ 获取天气
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&hourly=temperature_2m&timezone=auto`;
  const resp = await ctx.http.get(url);
  const data = await resp.json();

  await ctx.storage.set(cacheKey, {
    time: now,
    data,
    city: cityName
  });

  return render(data, cityName);

  // =========================

  function render(data, city) {
    const now = new Date();
    const hour = now.getHours();
    const isNight = hour < 6 || hour > 18;

    const current = data.current_weather;

    // 🌈 动态背景（天气 + 昼夜）
    function bg(code) {
      if (isNight) return ["#0F2027", "#203A43", "#2C5364"];
      if ([61,63,65].includes(code)) return ["#4B79A1", "#283E51"]; // 雨
      if ([0].includes(code)) return ["#56CCF2", "#2F80ED"]; // 晴
      return ["#bdc3c7", "#2c3e50"]; // 默认
    }

    // 🧩 SF Symbols 风格（文本模拟）
    function icon(code) {
      if (code === 0) return isNight ? "moon.stars.fill" : "sun.max.fill";
      if ([1,2].includes(code)) return "cloud.sun.fill";
      if ([3].includes(code)) return "cloud.fill";
      if ([61,63,65].includes(code)) return "cloud.rain.fill";
      if ([95].includes(code)) return "cloud.bolt.fill";
      return "thermometer";
    }

    // 📈 温度曲线（简化版）
    const temps = data.hourly.temperature_2m.slice(0, 12);

    const chart = {
      type: "hstack",
      spacing: 2,
      children: temps.map(t => ({
        type: "text",
        text: "•",
        font: { size: Math.max(10, t / 2) }, // 模拟曲线高度
        textColor: "#FFFFFFAA"
      }))
    };

    // 📱 小组件适配
    if (ctx.widgetFamily === "accessoryRectangular") {
      return {
        type: "widget",
        children: [
          {
            type: "text",
            text: `${city} ${current.temperature}°`
          }
        ]
      };
    }

    return {
      type: "widget",
      padding: 16,
      backgroundGradient: {
        type: "linear",
        colors: bg(current.weathercode)
      },
      children: [
        {
          type: "text",
          text: city,
          font: { size: "headline", weight: "bold" },
          textColor: "#FFFFFF"
        },
        {
          type: "text",
          text: icon(current.weathercode),
          font: { size: 18 },
          textColor: "#FFFFFF"
        },
        {
          type: "text",
          text: `${current.temperature}°`,
          font: { size: "largeTitle", weight: "bold" },
          textColor: "#FFFFFF"
        },
        chart,
        {
          type: "text",
          text: `城市 ${index + 1}/${cities.length}`,
          font: { size: "caption2" },
          textColor: "#FFFFFF88"
        },
        {
          type: "date",
          date: new Date().toISOString(),
          format: "time",
          textColor: "#FFFFFF88"
        }
      ]
    };
  }
}

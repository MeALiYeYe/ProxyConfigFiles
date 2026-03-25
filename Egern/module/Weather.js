export default async function (ctx) {
  const city = ctx.env.WEATHER_CITY || "chengdu";

  try {
    // 🌍 1. 城市名 → 经纬度
    const geoResp = await ctx.http.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1`
    );
    const geo = await geoResp.json();

    if (!geo.results || geo.results.length === 0) {
      throw new Error("City not found");
    }

    const { latitude, longitude, name } = geo.results[0];

    // 🌦️ 2. 获取天气
    const weatherResp = await ctx.http.get(
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
    );
    const data = await weatherResp.json();

    const w = data.current_weather;

    // 🌤️ 天气图标
    function getIcon(code) {
      if (code === 0) return "☀️";
      if ([1, 2].includes(code)) return "🌤️";
      if ([3].includes(code)) return "☁️";
      if ([45, 48].includes(code)) return "🌫️";
      if ([51, 53, 55].includes(code)) return "🌦️";
      if ([61, 63, 65].includes(code)) return "🌧️";
      if ([71, 73, 75].includes(code)) return "❄️";
      if ([95].includes(code)) return "⛈️";
      return "🌡️";
    }

    const icon = getIcon(w.weathercode);

    // 📱 小组件 UI
    return {
      type: "widget",
      padding: 16,
      children: [
        {
          type: "text",
          text: `${icon} ${name}`,
          font: { size: "headline", weight: "bold" }
        },
        {
          type: "text",
          text: `${w.temperature}°`,
          font: { size: "largeTitle", weight: "bold" }
        },
        {
          type: "text",
          text: `风速 ${w.windspeed} km/h`,
          font: { size: "caption1" }
        }
      ]
    };

  } catch (e) {
    return {
      type: "widget",
      padding: 16,
      children: [
        {
          type: "text",
          text: "❌ 天气获取失败",
          font: { size: "headline" }
        },
        {
          type: "text",
          text: city,
          font: { size: "caption1" }
        }
      ]
    };
  }
}

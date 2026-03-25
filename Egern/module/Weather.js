export default async function (ctx) {
  const cities = (ctx.env.WEATHER_CITIES || "chengdu,shanghai,singapore").split(",");
  const rotateInterval = parseInt(ctx.env.ROTATE_INTERVAL || "10") * 60 * 1000;

  const index = Math.floor(Date.now() / rotateInterval) % cities.length;
  const city = cities[index].trim();

  try {
    // 🌍 城市解析
    const geoResp = await ctx.http.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1`
    );
    const geo = await geoResp.json();
    const { latitude, longitude, name } = geo.results[0];

    // 🌦️ 天气
    const weatherResp = await ctx.http.get(
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true&hourly=temperature_2m&timezone=auto`
    );
    const data = await weatherResp.json();

    const w = data.current_weather;
    const temps = data.hourly.temperature_2m.slice(0, 12);

    const hour = new Date().getHours();
    const isNight = hour < 6 || hour > 18;

    // 🍎 Apple 风背景
    const bg = isNight
      ? ["#0B1F3A", "#1B3C73", "#2C5364"]
      : ["#4FACFE", "#00F2FE", "#5EE7DF"];

    // 🍎 SF Symbols 风（优化版）
    function icon(code) {
      if (code === 0) return isNight ? "🌙" : "☀️";
      if ([1,2].includes(code)) return "⛅";
      if ([3].includes(code)) return "☁️";
      if ([61,63,65].includes(code)) return "🌧️";
      if ([95].includes(code)) return "⛈️";
      return "🌡️";
    }

    // 📈 平滑曲线（模拟折线）
    const min = Math.min(...temps);
    const max = Math.max(...temps);

    const curve = {
      type: "hstack",
      spacing: 3,
      children: temps.map((t, i) => {
        const norm = (t - min) / (max - min + 0.01);

        return {
          type: "vstack",
          spacing: 0,
          children: [
            { type: "spacer", length: (1 - norm) * 40 },
            {
              type: "text",
              text: i % 2 === 0 ? "●" : "•",
              font: { size: 10 + norm * 8 },
              textColor: "#FFFFFF"
            }
          ]
        };
      })
    };

    // 🌧️ 动效层（伪动画）
    const effect = {
      type: "text",
      text:
        [61,63,65].includes(w.weathercode)
          ? "🌧️🌧️🌧️"
          : isNight
          ? "✨ ✦ ✧"
          : "",
      font: { size: 12 },
      textColor: "#FFFFFF66"
    };

    if (ctx.widgetFamily === "accessoryRectangular") {
      return {
        type: "widget",
        children: [
          {
            type: "text",
            text: `${icon(w.weathercode)} ${name} ${w.temperature}°`
          }
        ]
      };
    }

    return {
      type: "widget",
      padding: 16,
      backgroundGradient: {
        type: "linear",
        colors: bg
      },
      children: [
        // 城市
        {
          type: "text",
          text: name,
          font: { size: "headline", weight: "bold" },
          textColor: "#FFFFFF"
        },

        // 温度
        {
          type: "text",
          text: `${w.temperature}°`,
          font: { size: 42, weight: "bold" },
          textColor: "#FFFFFF"
        },

        // 图标 + 状态
        {
          type: "text",
          text: `${icon(w.weathercode)}`,
          font: { size: 20 },
          textColor: "#FFFFFF"
        },

        effect,

        // 曲线
        curve,

        // 城市轮播
        {
          type: "text",
          text: `${index + 1}/${cities.length}`,
          font: { size: "caption2" },
          textColor: "#FFFFFF88"
        },

        // 时间
        {
          type: "date",
          date: new Date().toISOString(),
          format: "time",
          textColor: "#FFFFFF88"
        }
      ]
    };

  } catch (e) {
    return {
      type: "widget",
      children: [
        { type: "text", text: "❌ 加载失败" },
        { type: "text", text: city }
      ]
    };
  }
}

export default async function (ctx) {
  const cityIds = (ctx.env.CITY_IDS || ctx.env.WEATHER_CITIES ||"101020100,101280101,101270101").split(",");
  const rotateInterval = parseInt(ctx.env.ROTATE_INTERVAL || "10") * 60 * 1000;

  // 🌍 轮播城市
  const index = Math.floor(Date.now() / rotateInterval) % cityIds.length;
  const cityId = cityIds[index].trim();

  try {
    // 🌦️ 获取天气
    const resp = await ctx.http.get(
      `http://t.weather.sojson.com/api/weather/city/${cityId}`
    );

    const weatherData = await resp.json();

    if (weatherData.status !== 200) {
      throw new Error("API error");
    }

    const cityInfo = weatherData.cityInfo;
    const data = weatherData.data;
    const forecast = data.forecast;

    const today = forecast[0];

    // 🌤️ 图标
    function icon(type) {
      if (type.includes("晴")) return "☀️";
      if (type.includes("云")) return "☁️";
      if (type.includes("雨")) return "🌧️";
      if (type.includes("雪")) return "❄️";
      if (type.includes("雷")) return "⛈️";
      return "🌡️";
    }

    // 🌗 昼夜
    const hour = new Date().getHours();
    const isNight = hour < 6 || hour > 18;

    const gradient = isNight
      ? ["#0B1F3A", "#1B3C73"]
      : ["#4FACFE", "#00F2FE"];

    // 📈 温度曲线（取未来4天）
    const temps = forecast.slice(0, 4).map(f => {
      const high = parseInt(f.high.replace(/[^\d]/g, ""));
      return high;
    });

    const min = Math.min(...temps);
    const max = Math.max(...temps);

    const chart = {
      type: "hstack",
      spacing: 6,
      children: temps.map((t, i) => {
        const norm = (t - min) / (max - min + 0.01);

        return {
          type: "vstack",
          children: [
            { type: "spacer", length: (1 - norm) * 40 },
            {
              type: "text",
              text: "●",
              font: { size: 10 + norm * 10 },
              textColor: "#FFFFFF"
            },
            {
              type: "text",
              text: `${t}°`,
              font: { size: 10 },
              textColor: "#FFFFFFAA"
            }
          ]
        };
      })
    };

    return {
      type: "widget",
      padding: 16,
      backgroundGradient: {
        type: "linear",
        colors: gradient
      },
      children: [
        // 城市
        {
          type: "text",
          text: `📍 ${cityInfo.city}`,
          font: { size: "headline", weight: "bold" },
          textColor: "#FFFFFF"
        },

        // 温度
        {
          type: "text",
          text: `${today.low}  ${today.high}`,
          font: { size: "title2", weight: "bold" },
          textColor: "#FFFFFF"
        },

        // 天气
        {
          type: "text",
          text: `${icon(today.type)} ${today.type}`,
          textColor: "#FFFFFFCC"
        },

        // 📈 曲线
        chart,

        // 空气质量
        {
          type: "text",
          text: `💧${data.shidu} · 🌫️${data.quality}`,
          font: { size: "caption1" },
          textColor: "#FFFFFFCC"
        },

        // PM
        {
          type: "text",
          text: `PM2.5 ${data.pm25} · PM10 ${data.pm10}`,
          font: { size: "caption2" },
          textColor: "#FFFFFFAA"
        },

        // 风
        {
          type: "text",
          text: `🪁 ${today.fx} ${today.fl}`,
          font: { size: "caption1" },
          textColor: "#FFFFFFCC"
        },

        // 日出日落
        {
          type: "text",
          text: `🌅 ${today.sunrise}  🌇 ${today.sunset}`,
          font: { size: "caption2" },
          textColor: "#FFFFFFAA"
        },

        // 轮播状态
        {
          type: "text",
          text: `${index + 1}/${cityIds.length}`,
          font: { size: "caption2" },
          textColor: "#FFFFFF66"
        }
      ]
    };

  } catch (e) {
    return {
      type: "widget",
      children: [
        { type: "text", text: "❌ 加载失败" },
        { type: "text", text: cityId }
      ]
    };
  }
}

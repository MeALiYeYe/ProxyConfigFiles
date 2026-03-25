export default async function(ctx) {

  const cityInput = ctx.env.TQCITY || "Chengdu";
  const cityList = cityInput.split(",").map(i => i.trim());
  const city = cityList[Math.floor(Math.random() * cityList.length)];

  // 🌍 城市 → 经纬度
  const geo = await ctx.http.get(
    `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1`
  );
  const geoData = await geo.json();

  if (!geoData.results) {
    return {
      type: "widget",
      children: [{ type: "text", text: "城市错误" }]
    };
  }

  const loc = geoData.results[0];

  // 🌦 天气
  const weather = await ctx.http.get(
    `https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current_weather=true&hourly=temperature_2m,relativehumidity_2m&daily=sunrise,sunset&timezone=auto`
  );
  const data = await weather.json();

  const current = data.current_weather;
  const temps = data.hourly.temperature_2m.slice(0, 24);
  const humidity = data.hourly.relativehumidity_2m[0];

  // 🌈 渐变颜色（关键）
  function gradient(code) {
    if (code === 0) return ["#4facfe", "#00f2fe"];        // 晴
    if ([1,2].includes(code)) return ["#89f7fe", "#66a6ff"];
    if (code === 3) return ["#bdc3c7", "#2c3e50"];        // 阴
    if ([51,61].includes(code)) return ["#5f9cff", "#3f4c6b"]; // 雨
    if (code >= 95) return ["#373B44", "#4286f4"];        // 雷暴
    return ["#4facfe", "#00f2fe"];
  }

  // ☀️ SF风格 icon 名称
  function icon(code) {
    if (code === 0) return "sun.max.fill";
    if ([1,2].includes(code)) return "cloud.sun.fill";
    if (code === 3) return "cloud.fill";
    if ([51,61].includes(code)) return "cloud.rain.fill";
    if (code >= 95) return "cloud.bolt.rain.fill";
    return "cloud.fill";
  }

  // 📈 曲线
  function chart(arr) {
    const blocks = "▁▂▃▄▅▆▇█";
    const min = Math.min(...arr);
    const max = Math.max(...arr);

    return arr.map((t,i)=>{
      const prev = arr[i-1] ?? t;
      const next = arr[i+1] ?? t;
      const smooth = (prev+t+next)/3;

      const idx = Math.round((smooth-min)/(max-min||1)*(blocks.length-1));
      return blocks[idx];
    }).join("");
  }

  const [c1, c2] = gradient(current.weathercode);
  const sunrise = data.daily.sunrise[0].split("T")[1];
  const sunset = data.daily.sunset[0].split("T")[1];

  return {
    type: "widget",
    padding: 16,
    background: {
      type: "linearGradient",
      colors: [c1, c2],
      startPoint: { x: 0, y: 0 },
      endPoint: { x: 1, y: 1 }
    },

    children: [

      // 顶部：城市 + 图标
      {
        type: "hstack",
        children: [
          {
            type: "text",
            text: loc.name,
            font: { size: "headline", weight: "bold" },
            color: "#ffffff"
          },
          { type: "spacer" },
          {
            type: "image",
            systemName: icon(current.weathercode),
            size: 22,
            color: "#ffffff"
          }
        ]
      },

      // 温度（大）
      {
        type: "text",
        text: `${current.temperature}°`,
        font: { size: "largeTitle", weight: "bold" },
        color: "#ffffff"
      },

      // 副信息
      {
        type: "text",
        text: `💧${humidity}%   🌬 ${current.windspeed}km/h`,
        color: "#ffffff",
        opacity: 0.9
      },

      // 曲线卡片
      {
        type: "vstack",
        padding: 10,
        background: {
          type: "color",
          color: "#ffffff",
          opacity: 0.15
        },
        cornerRadius: 12,
        children: [
          {
            type: "text",
            text: chart(temps),
            font: { size: "caption2", design: "monospaced" },
            color: "#ffffff"
          }
        ]
      },

      // 底部信息
      {
        type: "hstack",
        children: [
          {
            type: "text",
            text: `🌅 ${sunrise}`,
            color: "#ffffff",
            font: { size: "caption2" }
          },
          { type: "spacer" },
          {
            type: "text",
            text: `🌇 ${sunset}`,
            color: "#ffffff",
            font: { size: "caption2" }
          }
        ]
      }

    ]
  };
}

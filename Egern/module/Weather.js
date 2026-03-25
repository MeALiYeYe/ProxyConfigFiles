export default async function(ctx) {
  try {

    const cityInput = ctx.env.TQCITY || "chengdu";
    const cityList = cityInput.split(",").map(i => i.trim());
    const city = cityList[Math.floor(Math.random() * cityList.length)];

    // 🌍 城市 → 经纬度
    const geo = await ctx.http.get(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1`
    );
    const geoData = await geo.json();

    if (!geoData.results || geoData.results.length === 0) {
      return {
        type: "widget",
        children: [{ type: "text", text: "❌ 城市解析失败" }]
      };
    }

    const loc = geoData.results[0];

    // 🌦 天气
    const weather = await ctx.http.get(
      `https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current_weather=true&hourly=temperature_2m,relativehumidity_2m&daily=sunrise,sunset&timezone=auto`
    );
    const data = await weather.json();

    if (!data.current_weather) {
      return {
        type: "widget",
        children: [{ type: "text", text: "❌ 天气获取失败" }]
      };
    }

    const current = data.current_weather;
    const temps = data.hourly.temperature_2m.slice(0, 24);
    const humidity = data.hourly.relativehumidity_2m[0];

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

    const sunrise = data.daily.sunrise[0].split("T")[1];
    const sunset = data.daily.sunset[0].split("T")[1];

    return {
      type: "widget",
      padding: 16,
      background: {
        type: "color",
        color: "#4facfe"
      },
      children: [

        { type: "text", text: `📍 ${loc.name}`, color: "#fff" },

        {
          type: "text",
          text: `${current.temperature}°`,
          font: { size: "largeTitle", weight: "bold" },
          color: "#fff"
        },

        {
          type: "text",
          text: `💧${humidity}%  🌬 ${current.windspeed}km/h`,
          color: "#fff"
        },

        {
          type: "text",
          text: chart(temps),
          color: "#fff"
        },

        {
          type: "text",
          text: `🌅 ${sunrise}  🌇 ${sunset}`,
          color: "#fff"
        }

      ]
    };

  } catch (e) {
    return {
      type: "widget",
      children: [
        { type: "text", text: "❌ 脚本错误" },
        { type: "text", text: String(e) }
      ]
    };
  }
}

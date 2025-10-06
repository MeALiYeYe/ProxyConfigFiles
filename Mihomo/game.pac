function FindProxyForURL(url, host) {
    var proxy = "SOCKS5 127.0.0.1:7890; DIRECT";

    // ==============================
    // 1. 广告/追踪域名 → 直连（等效拦截）
    // ==============================
    if (
        dnsDomainIs(host, "ad.qq.com") ||
        dnsDomainIs(host, "beacon.qq.com") ||
        dnsDomainIs(host, "pingma.qq.com") ||
        dnsDomainIs(host, "bugly.qq.com") ||
        dnsDomainIs(host, "iad.g.163.com") ||
        dnsDomainIs(host, "crash.163.com") ||
        dnsDomainIs(host, "analytics.163.com") ||
        dnsDomainIs(host, "adgeo.163.com") ||
        dnsDomainIs(host, "doubleclick.net") ||
        dnsDomainIs(host, "admob.com")
    ) {
        return "DIRECT";
    }

    // ==============================
    // 2. 游戏平台直连（腾讯、网易、米哈游、完美、世纪天成等）
    // ==============================
    if (
        // 腾讯
        dnsDomainIs(host, ".wegame.com") ||
        dnsDomainIs(host, ".lol.qq.com") ||
        dnsDomainIs(host, ".game.qq.com") ||
        dnsDomainIs(host, ".gtimg.com") ||
        dnsDomainIs(host, ".idqqimg.com") ||
        dnsDomainIs(host, ".qpic.cn") ||
        dnsDomainIs(host, ".tencent.com") ||
        dnsDomainIs(host, ".qq.com") ||

        // 网易
        dnsDomainIs(host, ".netease.com") ||
        dnsDomainIs(host, ".126.net") ||
        dnsDomainIs(host, ".163.com") ||
        dnsDomainIs(host, ".neteasegames.com") ||
        dnsDomainIs(host, ".yximg.cn") ||

        // 米哈游 / HoYoverse
        dnsDomainIs(host, ".mihoyo.com") ||
        dnsDomainIs(host, ".hoyoverse.com") ||
        dnsDomainIs(host, ".genshinimpact.com") ||
        dnsDomainIs(host, ".starrails.com") ||
        dnsDomainIs(host, ".zenlesszonezero.com") ||

        // 完美世界
        dnsDomainIs(host, ".wanmei.com") ||
        dnsDomainIs(host, ".pwrd.com") ||
        dnsDomainIs(host, ".perfectworld.com.cn") ||

        // 世纪天成
        dnsDomainIs(host, ".sdo.com") ||
        dnsDomainIs(host, ".game.sdo.com")
    ) {
        return "DIRECT";
    }

    // ==============================
    // 3. 默认：其余全部走代理
    // ==============================
    return proxy;
}

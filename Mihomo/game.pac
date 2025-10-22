function FindProxyForURL(url, host) {
    var proxy = "SOCKS5 127.0.0.1:7890; DIRECT";

    // ==============================
    //  游戏平台直连（腾讯、网易、米哈游、完美、世纪天成等）
    // ==============================
    if (
        // 腾讯
        dnsDomainIs(host, ".wegame.com") ||
        dnsDomainIs(host, ".lol.qq.com") ||
        dnsDomainIs(host, ".game.qq.com") ||
        dnsDomainIs(host, ".gtimg.com") ||
        dnsDomainIs(host, ".idqqimg.com") ||
        dnsDomainIs(host, ".qpic.cn") ||

        // 网易
        dnsDomainIs(host, ".netease.com") ||
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

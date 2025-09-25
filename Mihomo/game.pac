function FindProxyForURL(url, host) {
    var proxy = "PROXY 127.0.0.1:7890";

    // ======== 拦截常见广告/追踪域名 ========
    if (
        dnsDomainIs(host, "ad.qq.com") ||
        dnsDomainIs(host, "beacon.qq.com") ||
        dnsDomainIs(host, "pingma.qq.com") ||
        dnsDomainIs(host, "bugly.qq.com") ||
        dnsDomainIs(host, "iad.g.163.com") ||
        dnsDomainIs(host, "crash.163.com") ||
        dnsDomainIs(host, "analytics.163.com") ||
        dnsDomainIs(host, "adgeo.163.com")
    ) {
        return "DIRECT";   // 或者 return "PROXY 127.0.0.1:0";  // 等于屏蔽
    }

    // ======== 游戏平台直连（腾讯、网易、米哈游、完美、世纪天成） ========
    if (
        dnsDomainIs(host, ".wegame.com") ||
        dnsDomainIs(host, ".lol.qq.com") ||
        dnsDomainIs(host, ".game.qq.com") ||
        dnsDomainIs(host, ".gtimg.com") ||
        dnsDomainIs(host, ".idqqimg.com") ||
        dnsDomainIs(host, ".qpic.cn") ||

        dnsDomainIs(host, ".netease.com") ||
        dnsDomainIs(host, ".126.net") ||
        dnsDomainIs(host, ".163.com") ||
        dnsDomainIs(host, ".neteasegames.com") ||
        dnsDomainIs(host, ".yximg.cn") ||

        dnsDomainIs(host, ".mihoyo.com") ||
        dnsDomainIs(host, ".hoyoverse.com") ||
        dnsDomainIs(host, ".genshinimpact.com") ||
        dnsDomainIs(host, ".starrails.com") ||
        dnsDomainIs(host, ".zenlesszonezero.com") ||

        dnsDomainIs(host, ".wanmei.com") ||
        dnsDomainIs(host, ".pwrd.com") ||
        dnsDomainIs(host, ".perfectworld.com.cn") ||

        dnsDomainIs(host, ".sdo.com") ||
        dnsDomainIs(host, ".game.sdo.com")
    ) {
        return "DIRECT";
    }

    // ======== 国内 CDN/视频/购物常见直连 ========
    if (
        dnsDomainIs(host, ".bilibili.com") ||
        dnsDomainIs(host, ".iqiyi.com") ||
        dnsDomainIs(host, ".youku.com") ||
        dnsDomainIs(host, ".mgtv.com") ||
        dnsDomainIs(host, ".douyin.com") ||
        dnsDomainIs(host, ".taobao.com") ||
        dnsDomainIs(host, ".tmall.com") ||
        dnsDomainIs(host, ".jd.com") ||
        dnsDomainIs(host, ".mi.com") ||
        dnsDomainIs(host, ".xiaomi.com") ||
        dnsDomainIs(host, ".baidu.com") ||
        dnsDomainIs(host, ".aliyun.com")
    ) {
        return "DIRECT";
    }

    // ======== 国内部分 IP 网段直连（可选） ========
    if (isInNet(dnsResolve(host), "36.0.0.0", "255.0.0.0")) return "DIRECT";
    if (isInNet(dnsResolve(host), "101.0.0.0", "255.0.0.0")) return "DIRECT";
    if (isInNet(dnsResolve(host), "111.0.0.0", "255.0.0.0")) return "DIRECT";

    // ======== 其他默认走代理 ========
    return proxy;
}

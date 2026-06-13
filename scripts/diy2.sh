#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 🕒 修改批次：v28.0 诸神黄昏·AdGuardHome 终极完全体大满贯
# 📝 核心拓扑：客户端 → Dnsmasq(53总大门/罩住SSH) → 传球 → AdGuardHome(:3053)
#               ├─ 海外高频域名 → 🚨 强行预留分流给本地 ShellCrash (:1053) → 纯净不污染
#               └─ 国内常用域名 → 6路 顶级国内UDP全量并行 (Parallel模式) → 1ms级秒开
# ==========================================

# 1. 默认 LAN IP 强行锁死为 192.168.1.1 (彻底防撞网段)
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题，为你的私人专属上位腾出干净跑道
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取纯净速度版必需插件 (拉取 AGH 前端和任务计划，彻底清除 SmartDNS 赘肉)
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# 4. 下载 AdGuardHome 官方纯正二进制核心并赋予暴徒权限
mkdir -p package/base-files/files/usr/bin/AdGuardHome
echo ">>> [云端] 正在下载 AdGuardHome 核心..."
curl -# -L --retry 3 https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod 777 package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

# 5. 🚨 终极完全体预埋：国内外像素级对齐配置，焊死 ShellCrash 无伤咬合通道
mkdir -p package/base-files/files/etc
cat << "EOF" > package/base-files/files/etc/AdGuardHome.yaml
http:
  address: 0.0.0.0:3000
users:
  - name: root
    password: $2y$10$dwn0hTYoECQMETZErGlzOId2VANOVsPHsuH13TM/8KnysM5Dh/ve
dns:
  bind_hosts:
    - 0.0.0.0
  port: 3053                   # 稳稳守在 3053 端口接收 Dnsmasq 的传球
  upstream_dns:
    # 🌟 核心高阶分流注入：只要命中海外主流域名与高频后缀，强制单向喂给 1053 端口的未来 ShellCrash 内核！
    - "[/google.com/youtube.com/github.com/githubusercontent.com/cloudflare.com/com/net/org/io/tw/hk/jp/us/uk/co/me/info/xyz/app/dev]127.0.0.1:1053"
    # 国内全量常规主力并发通道 (Parallel 赛马模式)
    - "223.5.5.5"              # 阿里DNS
    - "119.29.29.29"           # 腾讯DNS
    - "180.76.76.76"           # 百度DNS
    - "114.114.114.114"        # 114DNS
    - "223.6.6.6"              # 阿里备份
    - "119.29.29.28"           # 腾讯备份
  bootstrap_dns:
    - 223.5.5.5
    - 119.29.29.29
  upstream_mode: parallel      # 开启暴躁并行模式！国内6路UDP同时冲锋，谁快用谁，绝不等待！
  cache_size: 104857600        # 100MB 变态级本地超大缓存池
  cache_optimistic: true       # 开启乐观缓存：过期IP先扔给手机，后台去更新，网页弹射起步
filtering:
  safe_search:
    enabled: false
filters:
  - enabled: true
    url: https://anti-ad.net/easylist.txt
    name: 'CHN: anti-AD 纯净高效去广告'
    id: 2
schema_version: 28
EOF

# ==========================================
# 壹、构建 UCI 自动化初始化脚本 (首次开机无缝咬合)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== 1. AdGuardHome：开启前端引导与配置注入 ==================
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='1'
    uci set adguardhome.config.configpath='/etc/AdGuardHome.yaml'
    uci commit adguardhome
fi

if [ -x /etc/init.d/adguardhome ]; then
    /etc/init.d/adguardhome enable
fi

# ================== 2. Dnsmasq 总台接待：坐稳 53 端口托底并传球给 AGH ==================
# 这样能 10000% 保证你的内网网卡、DHCP 分配以及 SSH 访问绝对安全，永不死锁！
uci set dhcp.@dnsmasq[0].port='53'
uci set dhcp.@dnsmasq[0].noresolv='1'                      # 强行忽略运营商给的 WAN 口垃圾抢占解析
uci clear dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#3053'      # Dnsmasq 接到球后，零损耗平滑传球给 3053 的 AGH
uci commit dhcp

# 物理强行清理可能冲突的残留配置文件
rm -f /etc/dnsmasq.conf.d/smartdns.conf

# ================== 3. WiFi 27/22功率 澳洲鸡血包 (精简匹配，绝不误伤) ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'                       # 锁死澳洲国家码，冲破国内发射功率天花板
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'                       # 2.4G 穿墙拉满

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'                     # 5G 锁定 160MHz 满血超大频宽
uci set wireless.radio1.txpower='22'                       # 5G 信号质量黄金功率

# 动态精确匹配主接口，不论系统带不带单引号都绝不漏网，开机必亮灯
wif0=$(uci show wireless | grep -E "\.device='?radio0'?" | head -n1 | cut -d'.' -f1-2)
wif1=$(uci show wireless | grep -E "\.device='?radio1'?" | head -n1 | cut -d'.' -f1-2)

if [ -n "$wif0" ]; then
    uci set ${wif0}.ssid='immortalwrt2.4'
    uci set ${wif0}.encryption='psk2'
    uci set ${wif0}.key='12345678'
fi

if [ -n "$wif1" ]; then
    uci set ${wif1}.ssid='immortalwrt5.0'
    uci set ${wif1}.encryption='psk2'
    uci set ${wif1}.key='12345678'
fi
uci commit wireless

# ================== 系统网络内核终极优化 ==================
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# 开启 BBR 拥塞控制与 fq 队列，让 RAX3000M 并发吞吐直接拉满
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 完美自毁
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

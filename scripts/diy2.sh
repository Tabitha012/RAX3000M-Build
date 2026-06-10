#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 🕒 修改批次：v21.2 联名诸神飞升版 (接纳 DeepSeek 闭环修正 + Gemini 规范排雷)
# 📝 流量拓扑：客户端 → SmartDNS(独占53端口 / 挂载 cn.conf 白名单) 
#               ├─→ 国内域名 → 4路 UDP 并发赛马(:china 组) → 1ms 秒开
#               └─→ 海外域名 → 4路 DoH 加密并发(:foreign 组) → 纯净防污染
# ==========================================

# 1. 默认 LAN IP 强行锁死为 192.168.1.1
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取纯净速度版必需插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# 4. 预埋 SmartDNS 核心分流跑腿名单 (国内白名单)
mkdir -p package/base-files/files/etc/smartdns
echo ">>> [云端] 正在拉取国内域名高精度分流列表..."
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/china/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、构建 UCI 自动化初始化脚本 (首次开机自动咬合齿轮)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== SmartDNS 全能接管：直听 53 端口 ＝=================
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='53'                    # 直接接管全网核心 53 端口
uci set smartdns.@smartdns[0].cache_size='20000'           # 2万条超轻量高效率原生缓存
uci set smartdns.@smartdns[0].prefetch_domain='1'          # 开启域名预解析
uci set smartdns.@smartdns[0].serve_expired='1'            # 开启过期缓存先用（乐观缓存，速度第一！）
uci set smartdns.@smartdns[0].response_mode='fastest-ip'   # 开启极致赛马测速
uci set smartdns.@smartdns[0].redirect='runas'             # 替代 dnsmasq 成为全家总网关
uci set smartdns.@smartdns[0].rr_ttl_min='600'             # 强行延长本地缓存寿命至 10 分钟

# 🌟 采纳 DeepSeek 修正1：显式挂载国内域名分流白名单文件，否则规则形同虚设
uci add_list smartdns.@smartdns[0].conf_file='/etc/smartdns/cn.conf'

# 核心海外防污染与双栈优化
uci set smartdns.@smartdns[0].force_aaaa_soa='1'           # 屏蔽 IPv6 污染，拒绝卡顿
uci set smartdns.@smartdns[0].handle_edns_client_subnet='1' # 开启 ECS 支持
uci set smartdns.@smartdns[0].default_group='foreign'      # 未命中白名单的域名，默认全滑入海外组

# 清空旧服务器，开始构建国内/海外双重并发赛马大阵
while uci -q delete smartdns.@server[0]; do :; done

# ----------------- 【国内主力并发组：china (4路 UDP 赛马)】 -----------------
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='BaiduDNS'
uci set smartdns.@server[-1].ip='180.76.76.76'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='114DNS'
uci set smartdns.@server[-1].ip='114.114.114.114'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].type='udp'

# ----------------- 🌟 采纳 DeepSeek 修正2：【海外远征并发组：foreign (4路 DoH 加密防污染)】 -----------------
uci add smartdns server
uci set smartdns.@server[-1].name='Google-DoH'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].type='doh'
uci set smartdns.@server[-1].url='https://dns.google/dns-query'

uci add smartdns server
uci set smartdns.@server[-1].name='Cloudflare-DoH'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].type='doh'
uci set smartdns.@server[-1].url='https://cloudflare-dns.com/dns-query'

uci add smartdns server
uci set smartdns.@server[-1].name='Quad9-DoH'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].type='doh'
uci set smartdns.@server[-1].url='https://dns.quad9.net/dns-query'

uci add smartdns server
uci set smartdns.@server[-1].name='Ali-DoH-Overseas'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].type='doh'
uci set smartdns.@server[-1].url='https://dns.alidns.com/dns-query'

uci commit smartdns

# ================== Dnsmasq 老老实实退居二线 ==================
uci set dhcp.@dnsmasq[0].port='5353'                       # 原厂 dnsmasq 轰去 5353 端口养老
uci commit dhcp

# 开机强行物理清理可能冲突的残留配置文件
rm -f /etc/dnsmasq.conf.d/smartdns.conf

# ================== 🌟 采纳 DeepSeek 修正3：WiFi 27/22功率 澳洲鸡血包 ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'                       # 精确赋予 radio0 澳洲国家码
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'                       # 2.4G 穿墙拉满

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'                       # 精确赋予 radio1 澳洲国家码
uci set wireless.radio1.htmode='HE160'                     # 5G 锁定 160MHz 满血频宽
uci set wireless.radio1.txpower='22'                       # 5G 信号质量平衡功率

# 🌟 采纳 DeepSeek 附加优化：更精确匹配主接口，不带引号盲猜
wif0=$(uci show wireless | grep "\.device='radio0'" | head -n1 | cut -d'.' -f1-2)
wif1=$(uci show wireless | grep "\.device='radio1'" | head -n1 | cut -d'.' -f1-2)

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

# ================== 🌟 完美的收尾归位（系统调优与闭环） ==================
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# 开启 BBR 拥塞控制
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

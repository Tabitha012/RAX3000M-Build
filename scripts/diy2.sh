#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 🕒 修改批次：v24.0 独孤求败·大满贯终极版 (真机UI全对齐 + 完美避雷防死锁)
# 📝 核心拓扑：客户端 → Dnsmasq(稳坐53端口/罩住SSH) → 传球 → SmartDNS(:6053全能赛马)
#               ├─ 国内域名 → 4路 UDP 并发赛马(:china 组) → 南宁本地 1ms 秒开
#               └─ 海外域名 → 4路 DoH 加密并发(:foreign 组) → 纯净防污染 (预留SC无伤咬合线口)
# ==========================================

# 1. 默认 LAN IP 强行锁死为 192.168.1.1 (彻底防撞网段)
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题，为你的私人专属上位腾出干净跑道
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取纯净速度版必需插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# 4. 预埋 SmartDNS 核心分流跑腿名单 (国内高精度白名单)
mkdir -p package/base-files/files/etc/smartdns
echo ">>> [云端] 正在拉取国内域名高精度分流列表..."
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/china/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、构建 UCI 自动化初始化脚本 (首次开机全量咬合，绝不穿帮)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== SmartDNS：退回 6053 安全打工，全能属性解禁 ==================
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'                  # 🚨 轰回 6053 安全端口，不抢 53 绝不死锁
uci set smartdns.@smartdns[0].cache_size='20000'           # 2万条超轻量高效率原生缓存
uci set smartdns.@smartdns[0].prefetch_domain='1'          # 域名预加载 -> 开启
uci set smartdns.@smartdns[0].serve_expired='1'            # 缓存过期服务 -> 开启 (极致网页秒开奥义)
uci set smartdns.@smartdns[0].response_mode='fastest-ip'   # 响应模式 -> 最快IP (极速并发赛马)
uci set smartdns.@smartdns[0].redirect='none'              # 坚决关闭流氓重定向，不碰系统网卡防瘫痪
uci set smartdns.@smartdns[0].rr_ttl_min='600'             # 域名TTL最小值 -> 600

# 终极对齐：用标准的官方隐藏参数名，强行把真机截图里的 IPv6、双栈优选等暗雷全部封杀
uci set smartdns.@smartdns[0].force_aaaa_soa='1'           # 停用IPv6地址解析 -> 勾选 (防止双栈卡顿)
uci set smartdns.@smartdns[0].dualstack_ip_selection='0'   # 双栈IP优选 -> 取消勾选 (极大降低系统负载)
uci set smartdns.@smartdns[0].handle_edns_client_subnet='1' # 允许扩展客户端子网 -> 勾选 (ECS定位本地最快CDN)

# 挂载国内分流白名单文件，未命中白名单的默认全量滑入海外 foreign 组
uci add_list smartdns.@smartdns[0].conf_file='/etc/smartdns/cn.conf'
uci set smartdns.@smartdns[0].default_group='foreign'

# 彻底清空旧服务器，防范重复写入生成的垃圾条目
while uci -q delete smartdns.@server[0]; do :; done

# ----------------- 【国内主力并发组：china (4路 UDP 赛马)】 -----------------
# 完美对齐 group 与 server_group，确保真机前端 UI 完美认出组别，不再显示为“无”
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].server_group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].server_group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='BaiduDNS'
uci set smartdns.@server[-1].ip='180.76.76.76'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].server_group='china'
uci set smartdns.@server[-1].type='udp'

uci add smartdns server
uci set smartdns.@server[-1].name='114DNS'
uci set smartdns.@server[-1].ip='114.114.114.114'
uci set smartdns.@server[-1].group='china'
uci set smartdns.@server[-1].server_group='china'
uci set smartdns.@server[-1].type='udp'

# ----------------- 【海外远征并发组：foreign (4路高级 DoH 直链)】 -----------------
# 采用真机唯一认准的 url 参数，为未来的 ShellCrash 留下极其完美的“一键替换线口”
uci add smartdns server
uci set smartdns.@server[-1].name='Google-DoH'
uci set smartdns.@server[-1].url='https://dns.google/dns-query'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].server_group='foreign'
uci set smartdns.@server[-1].type='doh'

uci add smartdns server
uci set smartdns.@server[-1].name='Cloudflare-DoH'
uci set smartdns.@server[-1].url='https://cloudflare-dns.com/dns-query'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].server_group='foreign'
uci set smartdns.@server[-1].type='doh'

uci add smartdns server
uci set smartdns.@server[-1].name='Quad9-DoH'
uci set smartdns.@server[-1].url='https://dns.quad9.net/dns-query'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].server_group='foreign'
uci set smartdns.@server[-1].type='doh'

uci add smartdns server
uci set smartdns.@server[-1].name='Ali-DoH-Overseas'
uci set smartdns.@server[-1].url='https://dns.alidns.com/dns-query'
uci set smartdns.@server[-1].group='foreign'
uci set smartdns.@server[-1].server_group='foreign'
uci set smartdns.@server[-1].type='doh'

uci commit smartdns

# ================== 2. Dnsmasq 总台接待：稳坐前台安全托底 (绝不死锁) ==================
uci set dhcp.@dnsmasq[0].port='53'                         # 确保系统的核心网卡网关稳坐 53 端口，罩住 SSH
uci set dhcp.@dnsmasq[0].noresolv='1'                      # 忽略运营商给的 WAN 口垃圾抢占解析
uci clear dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'      # 53 端口接到的请求，平滑过棒传球给后台的 SmartDNS
uci commit dhcp

# 物理强行清理，断绝一切旧套娃残留配置文件
rm -f /etc/dnsmasq.conf.d/smartdns.conf

# ================== 3. WiFi 27/22功率 澳洲鸡血包 (精简版绝对稳) ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'                       # 澳大利亚国家码，解除国内发射功率天花板
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'                       # 2.4G 信号拉满

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'                     # 5G 锁定 160MHz 满血超大频宽
uci set wireless.radio1.txpower='22'                       # 5G 信号质量黄金平衡功率

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

# 开启 BBR 拥塞控制与 fq 队列，榨干 RAX3000M 的硬件极限
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 完美自毁
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

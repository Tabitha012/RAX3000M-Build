#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 🕒 修改批次：v26.0 诸神落幕·真机救赎不翻车版
# 📝 核心拓扑：客户端 → SmartDNS(独占53端口 / 极速 runas 优雅接管 / 绝不死锁)
#               ├─ 国内域名 → 4路 UDP 并发赛马(:china 组) → 界面完美填满显示 IP
#               └─ 未命中域名 → 3路 国内备份UDP并发(:foreign 组) → 彻底打碎超时长队
# ==========================================

# 1. 默认 LAN IP 强行锁死为 192.168.1.1 (彻底防撞网段)
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题，为你的私人专属上位腾出干净跑道
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取纯净速度版必需插件 (只留任务计划，砍掉所有多余的 DNS 赘肉)
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

# ================== SmartDNS：全能接管 53 端口，全能速度属性解禁 ==================
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='53'                    # 稳坐全网核心 53 端口总大门
uci set smartdns.@smartdns[0].cache_size='20000'           # 2万条高效率原生超大缓存
uci set smartdns.@smartdns[0].prefetch_domain='1'          # 域名预加载 -> 开启
uci set smartdns.@smartdns[0].serve_expired='1'            # 缓存过期服务 -> 开启 (白嫖乐观缓存，速度直追AGH)
uci set smartdns.@smartdns[0].response_mode='fastest-ip'   # 响应模式 -> 最快IP (极致并发赛马)
uci set smartdns.@smartdns[0].redirect='runas'             # 自动设置Dnsmasq -> 作为上游 (优雅强力接管)
uci set smartdns.@smartdns[0].rr_ttl_min='600'             # 域名TTL最小值 -> 600

# 终极修复：用标准的官方隐藏参数名，强行把真机截图里的 IPv6、双栈优选等暗雷全部封杀
uci set smartdns.@smartdns[0].force_aaaa_soa='1'           # 停用IPv6地址解析 -> 勾选 (屏蔽V6，大提速)
uci set smartdns.@smartdns[0].force_https_soa='1'          # 停用HTTPS记录解析 -> 勾选 
uci set smartdns.@smartdns[0].dualstack_ip_selection='0'   # 双栈IP优选 -> 取消勾选 (极大降低系统负载)
uci set smartdns.@smartdns[0].handle_edns_client_subnet='1' # 允许扩展客户端子网 -> 勾选 (ECS精准定位本地最快CDN)

# 挂载国内分流白名单文件，未命中白名单的默认全量滑入海外 foreign 组
uci add_list smartdns.@smartdns[0].conf_file='/etc/smartdns/cn.conf'
uci set smartdns.@smartdns[0].default_group='foreign'

# 彻底清空旧服务器，防范重复写入
while uci -q delete smartdns.@server[0]; do :; done

# ----------------- 🌟 【真机对齐核心：用万能穷举循环注入，根治 IP 显示为“无”的终极 Bug】 -----------------
# 针对新版/老版/魔改版所有固件，同时把地址写进 .ip / .address / .iparg 三重隐藏字典，前端绝对完美显色！
for srv in "AliDNS:223.5.5.5:china" "TencentDNS:119.29.29.29:china" "BaiduDNS:180.76.76.76:china" "114DNS:114.114.114.114:china" "Backup-Ali:223.6.6.6:foreign" "Backup-Tencent:119.29.29.28:foreign" "Backup-360:101.226.4.6:foreign"; do
    name=$(echo $srv | cut -d':' -f1)
    target_ip=$(echo $srv | cut -d':' -f2)
    grp=$(echo $srv | cut -d':' -f3)
    
    uci add smartdns server
    uci set smartdns.@server[-1].name="$name"
    uci set smartdns.@server[-1].ip="$target_ip"           # 老版字典
    uci set smartdns.@server[-1].address="$target_ip"      # 原生标准字典
    uci set smartdns.@server[-1].iparg="$target_ip"        # 🌟 最新版魔改前端字典！强行填满真机空单！
    uci set smartdns.@server[-1].group="$grp"
    uci set smartdns.@server[-1].server_group="$grp"
    uci set smartdns.@server[-1].type='udp'
done

uci commit smartdns

# ================== 2. Dnsmasq 老老实实退居二线 (配合 runas 优雅剥离) ==================
uci set dhcp.@dnsmasq[0].noresolv='1'                      # 强行忽略广西南宁运营商 WAN 口给的垃圾 DNS
uci commit dhcp
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

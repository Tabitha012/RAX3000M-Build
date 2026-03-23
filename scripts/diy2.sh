#!/bin/bash
# ==========================================
# RAX3000M 终极定制脚本 (diy2.sh)
# 核心目标：开盖即食 + 稳定不炸 + DNS 绝对接管
# ==========================================

# 1. 编译期直接修改默认 LAN IP (最稳妥的改法，防止开机后网段冲突)
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 创建 uci-defaults 目录，准备写入首次开机自启脚本
mkdir -p package/base-files/files/etc/uci-defaults

# 3. 注入 99-custom-settings 脚本 (EOF 里的内容会在路由器首次开机时自动执行)
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# 等待 5 秒，确保系统默认的 network 和 wireless 配置文件已经生成完毕
sleep 5

# ==========================================
# 一、WiFi 开盖即食配置
# ==========================================
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='sae-mixed'
uci set wireless.@wifi-iface[0].key='12345678'

uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='sae-mixed'
uci set wireless.@wifi-iface[1].key='12345678'
uci commit wireless
wifi reload

# ==========================================
# 二、DNS 绝对接管与防泄露 (掐断光猫，绑架 dnsmasq)
# ==========================================
# 1. 拒收光猫/运营商下发的垃圾 DNS
uci set network.wan.peerdns='0'
uci set network.wan6.peerdns='0'
uci commit network

# 2. 彻底改造 dnsmasq，变成只认 SmartDNS 的傀儡
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='0'
uci delete dhcp.@dnsmasq[0].server 2>/dev/null
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'
uci commit dhcp
/etc/init.d/dnsmasq restart

# ==========================================
# 三、SmartDNS 终极加速与分流配置
# ==========================================
# 1. 核心加速参数
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].tcp_server='1'
uci set smartdns.@smartdns[0].cache_size='32768' 
uci set smartdns.@smartdns[0].prefetch_domain='1'
uci set smartdns.@smartdns[0].serve_expired='1'
uci set smartdns.@smartdns[0].dualstack_ip_selection='1'
uci set smartdns.@smartdns[0].speed_check_mode='ping,tcp:80,tcp:443'
uci set smartdns.@smartdns[0].response_mode='fastest-ip'
uci set smartdns.@smartdns[0].force_aaaa_soa='1'

# 2. 清理系统默认的乱七八糟节点
while uci -q delete smartdns.@server[0]; do :; done

# 3. 国内 DNS (cn组，严禁参与默认解析，彻底防泄露)
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci set smartdns.@server[-1].server_group='cn'
uci set smartdns.@server[-1].exclude_default_group='1'

uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci set smartdns.@server[-1].server_group='cn'
uci set smartdns.@server[-1].exclude_default_group='1'

# 4. 海外 DNS (默认组)
uci add smartdns server
uci set smartdns.@server[-1].name='Cloudflare'
uci set smartdns.@server[-1].ip='1.1.1.1'

uci add smartdns server
uci set smartdns.@server[-1].name='Google'
uci set smartdns.@server[-1].ip='8.8.8.8'

uci commit smartdns
/etc/init.d/smartdns restart

# ==========================================
# 四、销毁证据，事了拂衣去
# ==========================================
# 执行完后删除自己，避免每次开机都重复执行，做到绝对纯净
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

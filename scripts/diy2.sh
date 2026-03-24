#!/bin/bash
# ==========================================
# RAX3000M 终极定制脚本 (diy2.sh)
# 核心目标：开盖即食 + 稳定不炸 + DNS 绝对接管 + 国内外完美分流 + 私人主题
# ==========================================

# ==========================================
# 零、云端编译期处理 (跑在 GitHub 服务器上)
# ==========================================

# 1. 编译期直接修改默认 LAN IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 提前建好 smartdns 的系统目录，准备塞入白名单
mkdir -p package/base-files/files/etc/smartdns

# 3. 利用 GitHub 万兆网络，秒下国内直连域名列表
echo ">>> 开始下载国内直连域名列表..."
curl -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" > /tmp/cn_domains.txt
curl -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/apple-cn.txt" >> /tmp/cn_domains.txt
curl -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt" >> /tmp/cn_domains.txt

# 4. 转换格式并强行打包进固件的 /etc/smartdns/cn.conf 中
cat /tmp/cn_domains.txt | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、构建开机自启脚本 (跑在你的 RAX3000M 路由器上)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# 等待 5 秒，确保系统默认的 network 和 wireless 配置文件已经生成完毕
sleep 5

# ------------------------------------------
# 一、WiFi 开盖即食 & 鸡血配置
# ------------------------------------------
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='sae-mixed'
uci set wireless.@wifi-iface[0].key='12345678'

uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='sae-mixed'
uci set wireless.@wifi-iface[1].key='12345678'

# 设置国家码为香港，强制 HT40/HE80 模式
uci set wireless.radio0.country='HK'
uci set wireless.radio1.country='HK'
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio1.htmode='HE80'

# 设置鸡血功率与稳定性参数
uci set wireless.radio0.txpower='22'
uci set wireless.radio1.txpower='27'
uci set wireless.@wifi-iface[0].distance='100'
uci set wireless.@wifi-iface[0].noscan='1'
uci set wireless.@wifi-iface[1].distance='100'
uci set wireless.@wifi-iface[1].noscan='1'
uci set wireless.radio0.adaptive='0'
uci set wireless.radio1.adaptive='0'
uci set wireless.radio0.beacon_int='100'
uci set wireless.radio1.beacon_int='100'

uci commit wireless
wifi reload

# ------------------------------------------
# 二、DNS 绝对接管与防泄露 (掐断光猫，绑架 dnsmasq)
# ------------------------------------------
uci set network.wan.peerdns='0'
uci set network.wan6.peerdns='0'
uci commit network

uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='0'
uci delete dhcp.@dnsmasq[0].server 2>/dev/null
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'
uci commit dhcp
/etc/init.d/dnsmasq restart

# ------------------------------------------
# 三、SmartDNS 终极加速与完美国内外分流
# ------------------------------------------
# 1. 核心加速参数配置
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

# 2. 清理系统自带杂乱节点
while uci -q delete smartdns.@server[0]; do :; done

# 3. 强行关联我们在云端打包好的 cn.conf 白名单！
if ! grep -q "conf-file /etc/smartdns/cn.conf" /etc/smartdns/custom.conf; then
    echo "conf-file /etc/smartdns/cn.conf" >> /etc/smartdns/custom.conf
fi

# 4. 国内 DNS (分配到 cn 组，由于有白名单配合，绝对不翻车！)
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

# 5. 海外 DNS (作为默认组，负责接管白名单以外的所有流量)
uci add smartdns server
uci set smartdns.@server[-1].name='Cloudflare'
uci set smartdns.@server[-1].ip='1.1.1.1'

uci add smartdns server
uci set smartdns.@server[-1].name='Google'
uci set smartdns.@server[-1].ip='8.8.8.8'

uci commit smartdns
/etc/init.d/smartdns restart

# ------------------------------------------
# 四、附加：霸王硬上弓，强制安装私藏版 Argon 主题
# ------------------------------------------
if [ -f "/root/luci-theme-argon_2.3.1_all.ipk" ]; then
    echo "发现 Argon 主题包，正在强制安装..." > /dev/console
    opkg install /root/luci-theme-argon_2.3.1_all.ipk --force-depends
    # 装完删包，腾出空间
    rm -f /root/luci-theme-argon_2.3.1_all.ipk
    # 强制设为默认主题
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci commit luci
fi

# ------------------------------------------
# 五、销毁证据，事了拂衣去
# ------------------------------------------
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

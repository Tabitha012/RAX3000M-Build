#!/bin/bash
# ==========================================
# RAX3000M 终极定制脚本 (diy2.sh)
# 核心目标：WPA3满血 + 硬件加速 + BBR + KVR极速握手 + DNS绝对接管 + 私人主题 
# ==========================================

# ==========================================
# 零、云端编译期处理 (跑在 GitHub 服务器上)
# ==========================================

# 1. 编译期直接修改默认 LAN IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强保命：将 luci-compat 写入系统必装清单，防自动删除！
sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += luci-compat /' include/target.mk

# 3. 狸猫换太子：刺杀系统自带的阉割版 wpad，强行替换为支持 WPA3 的满血版 wpad-openssl！
sed -i 's/wpad-basic-mbedtls/wpad-openssl/g' include/target.mk
sed -i 's/wpad-basic-wolfssl/wpad-openssl/g' include/target.mk

# 4. 提前建好 smartdns 的系统目录，准备塞入白名单
mkdir -p package/base-files/files/etc/smartdns

# 5. 秒下国内直连域名列表 (带重试防抽风)
echo ">>> 开始下载国内直连域名列表..."
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" > /tmp/cn_domains.txt
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/apple-cn.txt" >> /tmp/cn_domains.txt
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt" >> /tmp/cn_domains.txt

# 6. 转换格式并强行打包进固件的 /etc/smartdns/cn.conf 中
cat /tmp/cn_domains.txt | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、构建开机自启脚本 (跑在你的 RAX3000M 路由器上)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

sleep 5

# ------------------------------------------
# 一、WiFi 开盖即食 & 满血 WPA3 + 极速握手效率拉满
# ------------------------------------------
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='sae-mixed' 
uci set wireless.@wifi-iface[0].key='12345678'

uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='sae-mixed' 
uci set wireless.@wifi-iface[1].key='12345678'

uci set wireless.radio0.country='HK'
uci set wireless.radio1.country='HK'
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio1.htmode='HE80'

uci set wireless.radio0.txpower='22'
uci set wireless.radio1.txpower='22'

# 开启 MU-MIMO 与 波束成形 (大幅提升多设备并发与信号指向性)
uci set wireless.radio0.mu_mimo='1'
uci set wireless.radio1.mu_mimo='1'
uci set wireless.radio0.beamforming='1'
uci set wireless.radio1.beamforming='1'

# 开启 802.11k/v/r 快速漫游 (缩短唤醒握手时间，实现毫秒级闪连)
for i in 0 1; do
    uci set wireless.@wifi-iface[$i].ieee80211k='1'
    uci set wireless.@wifi-iface[$i].ieee80211v='1'
    uci set wireless.@wifi-iface[$i].ieee80211r='1'
    uci set wireless.@wifi-iface[$i].ft_psk_generate_local='1'
    uci set wireless.@wifi-iface[$i].ft_over_ds='0'
done

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
# 二、网络底层性能榨干：硬件加速 + BBR 拥塞控制
# ------------------------------------------
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ------------------------------------------
# 三、DNS 绝对接管与防泄露
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
# 四、SmartDNS 终极加速与完美国内外分流
# ------------------------------------------
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

while uci -q delete smartdns.@server[0]; do :; done

if ! grep -q "conf-file /etc/smartdns/cn.conf" /etc/smartdns/custom.conf; then
    echo "conf-file /etc/smartdns/cn.conf" >> /etc/smartdns/custom.conf
fi

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

uci add smartdns server
uci set smartdns.@server[-1].name='Cloudflare'
uci set smartdns.@server[-1].ip='1.1.1.1'

uci add smartdns server
uci set smartdns.@server[-1].name='Google'
uci set smartdns.@server[-1].ip='8.8.8.8'

uci commit smartdns
/etc/init.d/smartdns restart

# ------------------------------------------
# 五、霸王硬上弓，强制安装自定义包
# ------------------------------------------
if ls /root/*.ipk 1> /dev/null 2>&1; then
    echo "发现私有安装包，正在强制安装..." > /dev/console
    opkg install /root/*.ipk --force-depends
    rm -f /root/*.ipk
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci commit luci
fi

# ------------------------------------------
# 六、销毁证据，事了拂衣去
# ------------------------------------------
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

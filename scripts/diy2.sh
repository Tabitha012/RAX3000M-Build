#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：第 7 次修改 (v1.6 - 强抢养蛊全家桶版)
# 📝 核心更新日志：
#    1. [强抢去广告] 官方没有？直接去 rufengsuixing 老巢拉取 AdGuardHome 源码！
#    2. [防爆封印] AdGuardHome 默认关停，防 53 端口冲突断网！
#    3. [颜控专属] 强制拉取 luci-theme-design 源码，设为开机默认主题。
#    4. [底盘稳固] WPA2 秒连 + 关硬件加速保 Netch + 官方源码破 Error 127。
# ==========================================

# ==========================================
# 零、云端编译期处理
# ==========================================
# 1. 修改 LAN IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 铲除自带残废版，拉取最新官方原汁原味 OpenClash 源码
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 3. 现场编译 po2lmo，并塞进系统的全局环境 (破编译报错)
echo ">>> 开始强行锻造 po2lmo 工具..."
pushd package/luci-app-openclash/tools/po2lmo
make && sudo install -m755 po2lmo /usr/bin/po2lmo
popd

# 4. 强行拉取 Design 主题源码！
echo ">>> 开始拉取 luci-theme-design 源码..."
git clone --depth=1 https://github.com/gngpp/luci-theme-design.git package/luci-theme-design

# 5. 【高亮新增】：强行拉取 AdGuardHome 源码（官方不给，咱们自己抢！）
echo ">>> 开始拉取 luci-app-adguardhome 源码..."
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome

# 6. 准备 SmartDNS 白名单
mkdir -p package/base-files/files/etc/smartdns
echo ">>> 开始下载国内直连域名列表..."
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" > /tmp/cn_domains.txt
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/apple-cn.txt" >> /tmp/cn_domains.txt
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/google-cn.txt" >> /tmp/cn_domains.txt
cat /tmp/cn_domains.txt | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、构建开机自启脚本
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh
sleep 5

# ------------------------------------------
# 一、WiFi 绝对求稳 (WPA2) + KV 漫游 (剔除了有毒的 R)
# ------------------------------------------
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='12345678'

uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='psk2'
uci set wireless.@wifi-iface[1].key='12345678'

uci set wireless.radio0.country='HK'
uci set wireless.radio1.country='HK'
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio1.htmode='HE80'
uci set wireless.radio0.txpower='22'
uci set wireless.radio1.txpower='22'

uci set wireless.radio0.mu_mimo='1'
uci set wireless.radio1.mu_mimo='1'
uci set wireless.radio0.beamforming='1'
uci set wireless.radio1.beamforming='1'

for i in 0 1; do
    uci set wireless.@wifi-iface[$i].ieee80211k='1'
    uci set wireless.@wifi-iface[$i].ieee80211v='1'
    uci set wireless.@wifi-iface[$i].ieee80211r='0'
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
# 二、网络底层性能：只开软件加速，拯救 Netch 测速！
# ------------------------------------------
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ------------------------------------------
# 三、温和接管 DNS
# ------------------------------------------
uci set network.wan.peerdns='0'
uci set network.wan6.peerdns='0'
uci commit network
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='0'
uci clear dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'
uci commit dhcp
/etc/init.d/dnsmasq restart

# ------------------------------------------
# 四、SmartDNS 终极稳定版
# ------------------------------------------
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].tcp_server='1'
uci set smartdns.@smartdns[0].cache_size='32768'
uci set smartdns.@smartdns[0].prefetch_domain='1'
uci set smartdns.@smartdns[0].serve_expired='1'
uci set smartdns.@smartdns[0].dualstack_ip_selection='1'
uci set smartdns.@smartdns[0].speed_check_mode='tcp:80,tcp:443'
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
uci set smartdns.@server[-1].name='114DNS'
uci set smartdns.@server[-1].ip='114.114.114.114'
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
# 五、强制设置主题为 Design，并给 AdGuardHome 上封印！
# ------------------------------------------
# 设置全局默认主题为 design
uci set luci.main.mediaurlbase='/luci-static/design'
uci commit luci

# 给 AdGuardHome 上防爆封印（默认关闭），防开机断网
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='0'
    uci commit adguardhome
fi

if ls /root/*.ipk 1> /dev/null 2>&1; then
    opkg install /root/*.ipk --force-depends
    rm -f /root/*.ipk
fi

# ------------------------------------------
# 六、事了拂衣去
# ------------------------------------------
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

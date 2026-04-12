#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：第 10 次修改 (v1.9 - 强迫症圆满极光版)
# 📝 核心更新日志：
#    1. [细节拉满] 强制初始化 Aurora 配置，开机默认“跟随系统”深浅色模式！
#    2. [神兽齐聚] OpenClash + SSR-Plus + Taskplan + AdGuardHome。
#    3. [双雄防爆] 代理插件与去广告默认关停，防落地火拼断网！
#    4. [颜值与底盘] Aurora 极光主题 + 关硬件加速保测速 + WPA2 防密码错误。
# ==========================================

# ==========================================
# 零、云端编译期处理
# ==========================================
# 1. 修改 LAN IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 铲除自带残废版，拉取最新官方原汁原味 OpenClash 源码
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 3. 现场编译 po2lmo，防 OpenClash 编译 Error 127
echo ">>> 开始强行锻造 po2lmo 工具..."
pushd package/luci-app-openclash/tools/po2lmo
make && sudo install -m755 po2lmo /usr/bin/po2lmo
popd

# 4. 拉取全新的 Aurora 主题及配置工具
echo ">>> 开始拉取 luci-theme-aurora..."
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config

# 5. 强行拉取 AdGuardHome 源码
echo ">>> 开始拉取 luci-app-adguardhome..."
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome

# 6. 强行拉取 Taskplan 计划任务高级面板
echo ">>> 开始拉取 luci-app-taskplan..."
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# 7. 拉取 fw876 的 helloworld 仓库 (包含 SSR-Plus)
echo ">>> 开始拉取 helloworld (SSR-Plus)..."
git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworld

# 8. 准备 SmartDNS 白名单
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
# 一、WiFi 绝对求稳 (WPA2) + KV 漫游 (无 R)
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
# 二、网络底层：软件加速保代理测速
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
# 四、SmartDNS 稳定版
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
# 五、颜值拉满：强制极光主题，并设置跟随系统！
# ------------------------------------------
# 1. 设置全局默认主题为 aurora
uci set luci.main.mediaurlbase='/luci-static/aurora'
uci commit luci

# 2. 提前预埋 Aurora 配置，强行设为跟随系统 (Auto)
if [ ! -f /etc/config/aurora ]; then
    touch /etc/config/aurora
    uci add aurora global
fi
uci set aurora.@global[0].mode='auto'
uci commit aurora

# ------------------------------------------
# 六、给神兽们上防爆封印！
# ------------------------------------------
# 1. 封印 AdGuardHome
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='0'
    uci commit adguardhome
fi

# 2. 封印 SSR-Plus (防跟 OpenClash 火拼)
if [ -f /etc/config/shadowsocksr ]; then
    uci set shadowsocksr.@global[0].pdnsd_enable='0'
    uci commit shadowsocksr
fi

if ls /root/*.ipk 1> /dev/null 2>&1; then
    opkg install /root/*.ipk --force-depends
    rm -f /root/*.ipk
fi

# ------------------------------------------
# 七、事了拂衣去
# ------------------------------------------
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

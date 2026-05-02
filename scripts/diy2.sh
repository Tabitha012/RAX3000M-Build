#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (MT7981B - aarch64_cortex-a53)
# 🕒 修改批次：v15.0 大圆满终极版 (后台默认密码 root + AU锁区满血 WiFi)
# 📝 核心闭环：手机 -> dnsmasq-upstream -> AD(5353) -> Opc(7874) -> SM(6053)
# ==========================================

# 1. 修改默认 LAN IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强删官方 Argon 源码，为私藏版让路
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取四大神兽源码
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash
pushd package/luci-app-openclash/tools/po2lmo
make && sudo install -m755 po2lmo /usr/bin/po2lmo
popd
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan
git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworld

# ==========================================
# 🌩️ [云端疯狂打工区]：下核心、拉专属配置
# ==========================================

mkdir -p package/base-files/files/usr/bin/AdGuardHome
echo ">>> [云端] 正在下载 AdGuardHome ARM64 核心..."
curl -# -L --retry 3 https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod 777 package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

mkdir -p package/base-files/files/etc/openclash/core
echo ">>> [云端] 正在下载 OpenClash Meta 核心..."
curl -# -L --retry 3 https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/clash package/base-files/files/etc/openclash/core/clash_meta
chmod 777 package/base-files/files/etc/openclash/core/clash_meta

mkdir -p package/base-files/files/etc
echo ">>> [云端] 正在从 Tabitha012 仓库拉取专属 AdGuardHome.yaml..."
curl -# -L --retry 3 "https://raw.githubusercontent.com/Tabitha012/RAX3000M-Build/main/files/etc/AdGuardHome.yaml" -o package/base-files/files/etc/AdGuardHome.yaml

# ==========================================
# 壹、构建 UCI 自动化初始化脚本
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# 0. 开机静默强装 Argon IPK
if [ -f /root/luci-theme-argon_2.3.1_all.ipk ]; then
    opkg install /root/luci-theme-argon_2.3.1_all.ipk
    rm -f /root/luci-theme-argon_2.3.1_all.ipk
fi

# 1. SmartDNS 国内极速赛马
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].cache_size='0'
uci set smartdns.@smartdns[0].response_mode='fastest-ip'
while uci -q delete smartdns.@server[0]; do :; done
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci commit smartdns

# 2. 🌟 OpenClash 大佬级优化
if [ -f /etc/config/openclash ]; then
    uci set openclash.config.core_version='Meta'
    uci set openclash.config.en_mode='Fake-IP'
    uci set openclash.config.proxy_mode='rule'
    uci set openclash.config.disable_udp_quic='1'
    uci set openclash.config.router_net='1'            
    uci set openclash.config.disable_quic='1'          
    uci set openclash.config.china_ip_route='1'
    uci set openclash.config.enable_redirect_dns='0'   
    uci set openclash.config.dns_port='7874'
    uci set openclash.config.store_fakeip='1' 
    uci set openclash.config.enable_tcp_concurrent='1' 
    uci set openclash.config.enable_unified_delay='1'  
    uci set openclash.config.enable_meta_sniffing='1'  
    uci set openclash.config.enable_meta_sniffing_pure_ip='1' 
    uci set openclash.config.enable_custom_clash_rules='1'
    
    uci set openclash.config.enable_custom_dns='1'
    while uci -q delete openclash.@dns_servers[0]; do :; done
    uci add openclash dns_servers
    uci set openclash.@dns_servers[-1].group='nameserver'
    uci set openclash.@dns_servers[-1].ip='127.0.0.1'
    uci set openclash.@dns_servers[-1].port='6053'
    uci set openclash.@dns_servers[-1].type='udp'     
    uci set openclash.@dns_servers[-1].enabled='1'
    uci commit openclash
fi

# 3. 🌟 AGH 强制开机自启与正确接管
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='1'
    uci set adguardhome.config.configpath='/etc/AdGuardHome.yaml'
    uci set adguardhome.config.redirect='dnsmasq-upstream' 
    uci commit adguardhome
fi

if [ -x /etc/init.d/adguardhome ]; then
    /etc/init.d/adguardhome enable
fi

# 4. 🌟 WiFi 究极密码解锁 (AU区 + 满血频宽 + 定制功率)
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='12345678'

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.txpower='22'
uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='psk2'
uci set wireless.@wifi-iface[1].key='12345678'

uci commit wireless

# 5. 主题接管与内核网络优化
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

rm -f /etc/uci-defaults/99-custom-settings
EOF

# ==========================================
# 6. 🌟 路由器后台默认密码强行设置为 root
# ==========================================
# 利用云端的 openssl 实时生成 root 的 MD5 密文，并巧妙植入刚才的初始化脚本！
ROOT_PASS_HASH=$(openssl passwd -1 "root")
echo "sed -i 's|^root:[^:]*:|root:${ROOT_PASS_HASH}:|' /etc/shadow" >> package/base-files/files/etc/uci-defaults/99-custom-settings

# 顺手把 ImmortalWrt 可能自带的密码预设给删掉，防止它抢戏
sed -i '/$1$V4UetPzk$CYXluq41wUe8rOHIUzJj68/d' package/lean/default-settings/files/zzz-default-settings 2>/dev/null

exit 0

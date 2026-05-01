#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：v5.1 终极开盖即食版 (吸收大神套路，完美填坑)
# 📝 核心更新日志：
#    1. [大神补漏] 强制开启 Fake-IP 持久化 (store_fakeip)，彻底粉碎 AD 缓存毒化 Bug！
#    2. [神级复刻] 完美植入 Meta 高阶参数：TCP并发、统一延迟、纯IP嗅探、禁quic-go。
#    3. [强行阉割] 禁用 Opc 本地 DNS 劫持，誓死保卫 AD 的前台总控权。
#    4. [双核预载] 编译期直接注入 AGH 与 Opc Meta 双核心，开机即高潮。
# ==========================================

# 1. 修改默认 LAN IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强删官方 Argon 源码
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

# 4. 🌟 强行灌入双核心
mkdir -p package/base-files/files/usr/bin/AdGuardHome
curl -sL https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod +x package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

mkdir -p package/base-files/files/etc/openclash/core
curl -sL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/clash package/base-files/files/etc/openclash/core/clash_meta
chmod +x package/base-files/files/etc/openclash/core/clash_meta

# 5. 🌟 预埋纯净版 AGH 配置文件
mkdir -p package/base-files/files/etc
cat << "EOF" > package/base-files/files/etc/AdGuardHome.yaml
http:
  address: 0.0.0.0:3000
users:
  - name: root
    password: $2y$10$dwn0hTYoECQMZETBErGlzOId2VANOVsPHsuH13TM/8KnysM5Dh/ve
dns:
  bind_hosts: [0.0.0.0]
  port: 5353
  upstream_dns: ["127.0.0.1:7874"]  
  bootstrap_dns: [223.5.5.5]
  upstream_mode: parallel
  cache_size: 104857600
  cache_optimistic: true
filtering:
  safe_search: {enabled: false}
filters:
  - enabled: true
    url: https://anti-ad.net/easylist.txt
    name: 'CHN: anti-AD'
    id: 2
EOF

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

# 2. 🌟 OpenClash 终极微操
if [ -f /etc/config/openclash ]; then
    uci set openclash.config.core_version='Meta'
    uci set openclash.config.en_mode='Fake-IP'
    uci set openclash.config.proxy_mode='rule'
    uci set openclash.config.ipv6_enable='0'
    uci set openclash.config.disable_udp_quic='1'
    
    # 🚨 大神绝杀：强制开启 Fake-IP 持久化，配合 AD 前置！
    uci set openclash.config.store_fakeip='1' 
    
    uci set openclash.config.enable_redirect_dns='0'   
    uci set openclash.config.dns_port='7874'
    
    uci set openclash.config.enable_tcp_concurrent='1' 
    uci set openclash.config.enable_unified_delay='1'  
    uci set openclash.config.enable_meta_sniffing='1'  
    uci set openclash.config.enable_meta_sniffing_pure_ip='1' 
    
    uci set openclash.config.enable_custom_dns='1'
    while uci -q delete openclash.@dns_servers[0]; do :; done
    uci add openclash dns_servers
    uci set openclash.@dns_servers[-1].group='nameserver'
    uci set openclash.@dns_servers[-1].ip='127.0.0.1'
    uci set openclash.@dns_servers[-1].port='6053'     
    uci set openclash.@dns_servers[-1].enabled='1'
    
    uci add openclash dns_servers
    uci set openclash.@dns_servers[-1].group='fallback'
    uci set openclash.@dns_servers[-1].ip='8.8.8.8'
    uci set openclash.@dns_servers[-1].port='53'
    uci set openclash.@dns_servers[-1].enabled='1'
    
    uci set openclash.config.geo_auto_update='1'
    uci commit openclash
fi

# 3. AGH 启动与 Dnsmasq 接管
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='1'
    uci set adguardhome.config.configpath='/etc/AdGuardHome.yaml'
    uci set adguardhome.config.redirect='none' 
    uci commit adguardhome
fi
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='0'
uci clear dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
uci commit dhcp

# 4. 性能优化与主题接管
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio1.htmode='HE80'
uci commit wireless
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

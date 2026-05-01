#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (MT7981B - aarch64_cortex-a53)
# 🕒 修改批次：v6.1 云端封神版 (双核心云端暴力植入 + 参数写死)
# 📝 核心更新日志：
#    1. [精准拉取] 强制在云端拉取 Master 分支的 linux-arm64 Meta 核心。
#    2. [状态锁死] 在 UCI 中提前激活 Meta(Smart) 核心状态，开机即刻就绪。
#    3. [云端苦力] AD 核心与配置文件同步在云端完成烧录，拒绝本地断网下载。
# ==========================================

# 1. 修改默认 LAN IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强删官方 Argon 源码，防止冲突
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
# 🌩️ [云端疯狂打工区]：拉核心、写配置
# ==========================================

# 4. 🌟 云端暴力拉取 AGH 核心
echo ">>> [云端] 正在下载 AdGuardHome ARM64 核心..."
mkdir -p package/base-files/files/usr/bin/AdGuardHome
curl -# -L --retry 3 https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod 777 package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

# 5. 🌟 云端暴力拉取 OpenClash Meta(Smart) 核心 (严格匹配 linux-arm64)
echo ">>> [云端] 正在下载 OpenClash Meta (linux-arm64) 核心..."
mkdir -p package/base-files/files/etc/openclash/core
# 直接锁定 master 分支的 meta 核心
curl -# -L --retry 3 https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/clash package/base-files/files/etc/openclash/core/clash_meta
chmod 777 package/base-files/files/etc/openclash/core/clash_meta

# 6. 🌟 云端预先写死 AGH 配置文件 (防 AD 断网死锁)
echo ">>> [云端] 正在烧录 AdGuardHome.yaml 配置文件..."
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
  upstream_dns: ["127.0.0.1:7874"]  # 牢牢指向 Opc！
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

# 2. 🌟 OpenClash 终极微操 (面板状态完美骗过)
if [ -f /etc/config/openclash ]; then
    uci set openclash.config.core_version='Meta'
    uci set openclash.config.en_mode='Fake-IP'
    uci set openclash.config.proxy_mode='rule'
    uci set openclash.config.ipv6_enable='0'
    uci set openclash.config.disable_udp_quic='1'
    
    # 强制开启 Fake-IP 持久化
    uci set openclash.config.store_fakeip='1' 
    
    # 不抢 53 端口，让给 AD
    uci set openclash.config.enable_redirect_dns='0'   
    uci set openclash.config.dns_port='7874'
    
    # Meta 核心高阶探测
    uci set openclash.config.enable_tcp_concurrent='1' 
    uci set openclash.config.enable_unified_delay='1'  
    uci set openclash.config.enable_meta_sniffing='1'  
    uci set openclash.config.enable_meta_sniffing_pure_ip='1' 
    
    # 指派国内总管给 SmartDNS
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

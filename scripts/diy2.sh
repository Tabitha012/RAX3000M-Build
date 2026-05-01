#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：纯净国内地基版 (完美咬合 + 本地IPK强装)
# 📝 核心更新日志：
#    1. [逻辑重构] 铲除 [/cn/] 语法陷阱，AGH 所有流量无条件全盘交由 SmartDNS 测速。
#    2. [防爆核心] 编译期直接注入 ARM64 AGH 核心，彻底粉碎死锁断网 Bug。
#    3. [霸道接管] 开机静默强装 /root 下的 Argon 主题包并自动启用。
# ==========================================

# ==========================================
# 零、源码拉取与冲突清场
# ==========================================
# 1. 修改默认 LAN IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强删官方 Argon 源码，防止云端编译冲突！
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取四大神兽源码 (做备胎兼容)
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash
pushd package/luci-app-openclash/tools/po2lmo
make && sudo install -m755 po2lmo /usr/bin/po2lmo
popd
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan
git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworld

# 4. 准备 SmartDNS 国内加速名单
mkdir -p package/base-files/files/etc/smartdns
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# ------------------------------------------
# 🌟 强行灌入 AGH 核心，粉碎断网死锁！
# ------------------------------------------
mkdir -p package/base-files/files/usr/bin/AdGuardHome
echo ">>> 正在为 RAX3000M(ARM64) 强行灌入 AGH 核心..."
curl -sL https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod +x package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

# ------------------------------------------
# 🌟 预埋纯净版 AGH 配置文件 (大写A、G、H)
# ------------------------------------------
mkdir -p package/base-files/files/etc
cat << "EOF" > package/base-files/files/etc/AdGuardHome.yaml
http:
  address: 0.0.0.0:3000
users:
  - name: root
    password: $2y$10$dwn0hTYoECQMZETBErGlzOId2VANOVsPHsuH13TM/8KnysM5Dh/ve
dns:
  bind_hosts:
    - 0.0.0.0
  port: 5353
  upstream_dns:
    - "127.0.0.1:6053"  # 没有任何花里胡哨，全部踢给 SM 去赛马！
  bootstrap_dns:
    - 223.5.5.5
  upstream_mode: parallel
  cache_size: 104857600
  cache_optimistic: true
filtering:
  safe_search:
    enabled: false
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

# 0. 🌟 开机静默强装私藏 Argon IPK
if [ -f /root/luci-theme-argon_2.3.1_all.ipk ]; then
    opkg install /root/luci-theme-argon_2.3.1_all.ipk
    rm -f /root/luci-theme-argon_2.3.1_all.ipk  # 装完顺手删掉安装包省空间
fi

# 1. SmartDNS 国内极致赛马设置
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].cache_size='0'
uci set smartdns.@smartdns[0].prefetch_domain='1'
uci set smartdns.@smartdns[0].response_mode='fastest-ip'

while uci -q delete smartdns.@server[0]; do :; done
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci commit smartdns

# 2. AGH 启动与 Dnsmasq 流量劫持 (53 -> 5353)
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

# 3. WiFi 与性能优化 (强制启用刚装好的 Argon)
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio1.htmode='HE80'
uci commit wireless

uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# 开启 BBR 拥塞控制
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：第 16 次修改 (v3.1 - 赛博飞升·劳动节私人定制版)
# 📝 核心更新日志：
#    1. [霸道清场] 强删官方自带 Argon，保送你仓库里的私藏版上位！
#    2. [神迹闭环] AGH(5353) -> SmartDNS(6053) -> ShellCrash(1053) 链路全自动化。
#    3. [极致精修] ShellCrash 预设：Mihomo 内核、Fake-IP、CN绕过、屏蔽IPv6。
#    4. [提纯遗产] 预埋 AGH 100MB 缓存 + 乐观缓存 + 你的原厂登录密码。
# ==========================================

# ==========================================
# 零、源码拉取与编译期处理
# ==========================================
# 1. 修改默认 LAN IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 【高亮新增】：铲除官方 Argon，为你仓库里的私藏版让路！
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取 OpenClash 源码并编译 po2lmo
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash
pushd package/luci-app-openclash/tools/po2lmo
make && sudo install -m755 po2lmo /usr/bin/po2lmo
popd

# 4. 拉取 AGH / Taskplan / SSR-Plus (helloworld)
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan
git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworld

# 5. 预载 ShellCrash 安装脚本
mkdir -p package/base-files/files/tmp
curl -kfsSl https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master/install.sh -o package/base-files/files/tmp/install.sh

# 6. 准备 SmartDNS 国内加速名单
mkdir -p package/base-files/files/etc/smartdns
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# 7. 预埋 AdGuardHome 提纯版配置文件 (100MB 缓存 + 你的密码)
mkdir -p package/base-files/files/etc
cat << "EOF" > package/base-files/files/etc/adguardhome.yaml
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
    - "[/cn/]127.0.0.1:6053"
    - "127.0.0.1:1053"
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

# ------------------------------------------
# 1. ShellCrash 极致精修安装
# ------------------------------------------
if [ -f /tmp/install.sh ]; then
    # 模拟键盘输入 1 (安装) -> 1 (确认)
    echo -e "1\n1" | sh /tmp/install.sh
    
    export CRASHDIR="/etc/shellcrash"
    mkdir -p $CRASHDIR/configs
    
    # 强制写入精装修配置：Mihomo 内核 / Fake-IP / CN 绕过
    cat << "EOF_SC" > $CRASHDIR/configs/ShellCrash.cfg
crashcore=mihomo
dashboard=zashboard
update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master
redir_mod=混合配置
dns_mod=fake-ip
dns_port=1053
ipv6=0
cn_ip_route=1
cn_ipv6_route=0
local_dns=127.0.0.1:6053
fallback_dns=tls://8.8.8.8
EOF_SC
fi

# ------------------------------------------
# 2. SmartDNS 国内跑腿设置
# ------------------------------------------
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

# ------------------------------------------
# 3. AGH 启动与 Dnsmasq 流量劫持 (53 -> 5353)
# ------------------------------------------
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='1'
    uci set adguardhome.config.configpath='/etc/adguardhome.yaml'
    uci commit adguardhome
fi

uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='0'
uci clear dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
uci commit dhcp

# ------------------------------------------
# 4. WiFi 与系统性能优化
# ------------------------------------------
uci set wireless.radio0.htmode='HT40' # 2.4G 稳如狗
uci set wireless.radio1.htmode='HE80' # 5G 猛如虎
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

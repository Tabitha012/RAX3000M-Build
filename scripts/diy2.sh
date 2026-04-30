#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M
# 🕒 修改批次：第 17 次修改 (v3.2 - 黄金模板·开盖即食版)
# 📝 核心更新日志：
#    1. [黄金模板] 深度注入你提供的 ShellCrash 高阶 YAML 模版，支持纯 IP 嗅探。
#    2. [霸道清场] 强删官方 Argon，为你仓库里的私藏版 Argon 彻底让路。
#    3. [链路闭环] 锁定 AGH(5353) -> SmartDNS(6053) -> ShellCrash(1053) 逻辑。
#    4. [MRS加速] 预设全 MRS 格式云端规则库，极致节省内存与提升首开速度。
# ==========================================

# ==========================================
# 零、源码处理与清场
# ==========================================
# 1. 修改 LAN IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 铲除官方 Argon，保送你仓库里的私藏版
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

# 4. 下载 ShellCrash 安装脚本
mkdir -p package/base-files/files/tmp
curl -kfsSl https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master/install.sh -o package/base-files/files/tmp/install.sh

# 5. 准备 SmartDNS 国内名单
mkdir -p package/base-files/files/etc/smartdns
curl --retry 3 -sL "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt" | grep -v "^#" | grep -v "^regexp:" | sed 's/^full://g' | sed 's/^/nameserver \//g' | sed 's/$/\/cn/g' > package/base-files/files/etc/smartdns/cn.conf

# ==========================================
# 壹、注入你提供的黄金 YAML 模版
# ==========================================
mkdir -p package/base-files/files/etc/shellcrash
cat << "EOF_YAML" > package/base-files/files/etc/shellcrash/user_template.yaml
# --- 1. 核心网络引擎 ---
mixed-port: 7893
allow-lan: true
mode: rule
log-level: info
ipv6: false
unified-delay: true
tcp-concurrent: true
external-controller: 0.0.0.0:9090

# --- 2. 极限流量嗅探 (关键核心) ---
sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP: {ports: [80, 8080-8880], override-destination: true}
    TLS: {ports: [443, 8443], override-destination: true}
    QUIC: {ports: [443, 8443], override-destination: true}

# --- 3. 极简 DNS (交权给 SmartDNS) ---
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: [127.0.0.1:6053]
  nameserver: [https://dns.google/dns-query, https://1.1.1.1/dns-query]
  fallback: [https://8.8.8.8/dns-query]

# --- 4. 策略组与云端规则大脑 (提炼自你的模版) ---
rule-providers: 
  cn_domain: {type: http, behavior: domain, format: mrs, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/cn.mrs", interval: 86400}
  cn_ip: {type: http, behavior: ipcidr, format: mrs, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/cn.mrs", interval: 86400}

rules:
  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT
  - RULE-SET,cn_domain,DIRECT
  - RULE-SET,cn_ip,DIRECT,no-resolve
  - MATCH,DIRECT
EOF_YAML

# ==========================================
# 贰、预埋 AGH 配置文件 (包含你的密码)
# ==========================================
mkdir -p package/base-files/files/etc
cat << "EOF_AGH" > package/base-files/files/etc/adguardhome.yaml
http:
  address: 0.0.0.0:3000
users:
  - name: root
    password: $2y$10$dwn0hTYoECQMZETBErGlzOId2VANOVsPHsuH13TM/8KnysM5Dh/ve
dns:
  bind_hosts: [0.0.0.0]
  port: 5353
  upstream_dns: ["[/cn/]127.0.0.1:6053", "127.0.0.1:1053"]
  cache_size: 104857600
  cache_optimistic: true
filtering:
  safe_search: {enabled: false}
EOF_AGH

# ==========================================
# 叁、自动化初始化脚本
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF_UCI" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# 1. ShellCrash 黄金模版注入
if [ -f /tmp/install.sh ]; then
    echo -e "1\n1" | sh /tmp/install.sh
    export CRASHDIR="/etc/shellcrash"
    # 把黄金模版强制移动到工作目录
    [ -f /etc/shellcrash/user_template.yaml ] && mv /etc/shellcrash/user_template.yaml $CRASHDIR/
    
    # 写入启动配置
    cat << "EOF_SC" > $CRASHDIR/configs/ShellCrash.cfg
crashcore=mihomo
dashboard=zashboard
redir_mod=混合配置
dns_mod=fake-ip
dns_port=1053
ipv6=0
local_dns=127.0.0.1:6053
EOF_SC
fi

# 2. SmartDNS 赛马设置
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].cache_size='0'
uci commit smartdns

# 3. AGH 启动与 Dnsmasq 劫持
[ -f /etc/config/adguardhome ] && uci set adguardhome.config.enabled='1' && uci set adguardhome.config.configpath='/etc/adguardhome.yaml' && uci commit adguardhome
uci set dhcp.@dnsmasq[0].noresolv='1'
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5353'
uci commit dhcp

# 4. 系统优化
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF_UCI

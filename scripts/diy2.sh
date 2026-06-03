#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 🕒 修改批次：v18.0 诸神黄昏·大满贯版 (极致速度底座 + 登录地址锁死 1.1)
# 📝 流量拓扑：客户端 → Dnsmasq → AD(:5353超级缓存) → SmartDNS(:6053纯跑腿) → 公网
# ==========================================

# 1. 🌟 默认 LAN IP 强行锁死为 192.168.1.1 (彻底根治 17.0 原地踏步与网段改错问题)
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题，为你的私人私藏版腾出大马路
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取纯净速度版必需插件
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# 4. 下载 AdGuardHome 二进制核心并赋予暴徒权限
mkdir -p package/base-files/files/usr/bin/AdGuardHome
echo ">>> [云端] 正在下载 AdGuardHome 核心..."
curl -# -L --retry 3 https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz | tar -xz -C /tmp/
mv /tmp/AdGuardHome/AdGuardHome package/base-files/files/usr/bin/AdGuardHome/
chmod 777 package/base-files/files/usr/bin/AdGuardHome/AdGuardHome

# 5. 预埋 AdGuardHome 配置文件（100MB 变态级本地缓存前台，全量踢给 SM）
mkdir -p package/base-files/files/etc
cat << "EOF" > package/base-files/files/etc/AdGuardHome.yaml
http:
  address: 0.0.0.0:3000
users:
  - name: root
    password: $2y$10$dwn0hTYoECQMETZErGlzOId2VANOVsPHsuH13TM/8KnysM5Dh/ve
dns:
  bind_hosts:
    - 0.0.0.0
  port: 5353
  upstream_dns:
    - "127.0.0.1:6053"          # 毫无保留，全部甩给后面的 SmartDNS
  bootstrap_dns:
    - 223.5.5.5                # 核心引导采用公网明文，破除自启死循环
    - 119.29.29.29
  upstream_mode: parallel
  cache_size: 104857600        # 100MB 超级本地缓存池
  cache_optimistic: true       # 乐观缓存开启：过期 IP 先扔给手机，后台去更新，追求网页秒开
filtering:
  safe_search:
    enabled: false
filters:
  - enabled: true
    url: https://anti-ad.net/easylist.txt
    name: 'CHN: anti-AD'
    id: 2
schema_version: 28
EOF

# ==========================================
# 壹、构建 UCI 自动化初始化脚本 (首次开机自动咬合齿轮)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== SmartDNS：纯上游跑腿赛马 ==================
uci set smartdns.@smartdns[0].enabled='1'
uci set smartdns.@smartdns[0].port='6053'
uci set smartdns.@smartdns[0].cache_size='0'               # 缓存全给前端 AD，SM 不留脏数据
uci set smartdns.@smartdns[0].prefetch_domain='1'
uci set smartdns.@smartdns[0].response_mode='fastest-ip'   # 测速模式，挑出南宁当地响应最快的 IP
uci set smartdns.@smartdns[0].redirect='none'              # 彻底剥夺 SmartDNS 修改 dnsmasq 的权利

# 清空原有服务器并写入阿里、腾讯国内高质量源
while uci -q delete smartdns.@server[0]; do :; done
uci add smartdns server
uci set smartdns.@server[-1].name='AliDNS'
uci set smartdns.@server[-1].ip='223.5.5.5'
uci add smartdns server
uci set smartdns.@server[-1].name='TencentDNS'
uci set smartdns.@server[-1].ip='119.29.29.29'
uci commit smartdns

# 首次开机安全修改 SmartDNS 自启优先级 (避开编译期找不到文件的雷区)
if [ -f /etc/init.d/smartdns ]; then
    sed -i 's/START=.*/START=50/' /etc/init.d/smartdns
    /etc/init.d/smartdns enable
fi

# ================== AdGuardHome：唯一上游接管 ==================
if [ -f /etc/config/adguardhome ]; then
    uci set adguardhome.config.enabled='1'
    uci set adguardhome.config.configpath='/etc/AdGuardHome.yaml'
    uci set adguardhome.config.redirect='dnsmasq-upstream'   # 听你的，用最稳的原生上游介入模式
    uci commit adguardhome
fi

if [ -f /etc/init.d/adguardhome ]; then
    sed -i 's/START=.*/START=80/' /etc/init.d/adguardhome    # 确保晚于 SmartDNS 启动，破除死锁
    /etc/init.d/adguardhome enable
fi

# 物理死锁：开机强行清理可能残留的冲突配置文件
rm -f /etc/dnsmasq.conf.d/smartdns.conf

# ================== WiFi 27/22功率 澳洲鸡血包 ==================
uci set wireless.radio0.disabled='0'
uci set wireless.country='AU'                              # 🌟 强行篡改国家码为澳大利亚，解除功率锁
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'                       # 2.4G 穿墙拉满

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.htmode='HE160'                     # 🌟 5G 锁定 160MHz 满血频宽
uci set wireless.radio1.txpower='22'                       # 5G 信号质量平衡功率

# 兼容性 Grep：不论系统有没有带单引号，精准抓取首个主接口，避免误伤其他子接口
wif0=$(uci show wireless | grep -E "device='?radio0'?" | head -n1 | cut -d'.' -f1-2)
wif1=$(uci show wireless | grep -E "device='?radio1'?" | head -n1 | cut -d'.' -f1-2)

if [ -n "$wif0" ]; then
    uci set ${wif0}.ssid='immortalwrt2.4'
    uci set ${wif0}.encryption='psk2'
    uci set ${wif0}.key='12345678'
fi

if [ -n "$wif1" ]; then
    uci set ${wif1}.ssid='immortalwrt5.0'
    uci set ${wif1}.encryption='psk2'
    uci set ${wif1}.key='12345678'
fi
uci commit wireless

# ================== 系统终极优化 ==================
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# 开启 TCP BBR 拥塞控制与 fq 队列，榨干千兆
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 自毁，不留痕迹
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

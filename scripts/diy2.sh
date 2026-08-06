#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt) - 最终稳定版
# 📝 功能：LAN IP 192.168.6.131，添加第三方源，无线稳定性增强
#          WiFi 2.4G/5G SSID明确分开，强制加密
# ❌ 移除：所有主题相关操作（保留官方默认主题）
# ==========================================

set -e

# ==========================================
# 1. LAN IP 固定为 192.168.6.131
# ==========================================
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.6.1/g' package/base-files/files/bin/config_generate

# ==========================================
# 2. 添加第三方软件源（kenzok8）
# ==========================================
echo "正在添加第三方插件源..."
if ! grep -q "kenzo" feeds.conf.default; then
    echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
    echo "✅ 已添加 kenzo 源"
else
    echo "⚠️ kenzo 源已存在，跳过"
fi

if ! grep -q "small" feeds.conf.default; then
    echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default
    echo "✅ 已添加 small 源"
else
    echo "⚠️ small 源已存在，跳过"
fi

echo "当前 feeds.conf.default 内容："
cat feeds.conf.default

# ==========================================
# 3. 更新 feeds（让第三方源生效）
# ==========================================
echo "正在更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a
echo "feeds 更新完成。"

# ==========================================
# 4. 拉取额外插件（如有）
# ==========================================
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan || echo "插件已存在或拉取失败，继续"

# ==========================================
# 5. 构建 UCI 自动化初始化脚本 (首次开机运行)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== 1. Dnsmasq 恢复默认（无 SmartDNS） ==================
uci set dhcp.@dnsmasq[0].port='53'
uci commit dhcp

# ================== 2. WiFi 基础配置（功率、频宽、国家） ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.txpower='22'

# ================== 3. 直接设置 2.4G 和 5G 的接口 ==================
uci delete wireless.@wifi-iface[0] 2>/dev/null
uci delete wireless.@wifi-iface[1] 2>/dev/null

# 添加 2.4G 接口
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio0'
uci set wireless.@wifi-iface[-1].mode='ap'
uci set wireless.@wifi-iface[-1].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[-1].encryption='psk2'
uci set wireless.@wifi-iface[-1].key='12345678'
uci set wireless.@wifi-iface[-1].network='lan'
uci set wireless.@wifi-iface[-1].isolate='0'

# 添加 5G 接口
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio1'
uci set wireless.@wifi-iface[-1].mode='ap'
uci set wireless.@wifi-iface[-1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[-1].encryption='psk2'
uci set wireless.@wifi-iface[-1].key='12345678'
uci set wireless.@wifi-iface[-1].network='lan'
uci set wireless.@wifi-iface[-1].isolate='0'

# ================== 4. 无线稳定性增强配置 ==================
uci set wireless.radio0.rssi_threshold='-85'
uci set wireless.radio1.rssi_threshold='-85'
uci set wireless.radio0.disassoc_low_ack='0'
uci set wireless.radio1.disassoc_low_ack='0'
uci set wireless.radio0.powersave='0'
uci set wireless.radio1.powersave='0'
uci set wireless.radio0.basic_rate=''
uci set wireless.radio1.basic_rate=''
uci set wireless.radio0.supported_rates=''
uci set wireless.radio1.supported_rates=''

uci commit wireless

# ================== 5. BBR 优化 ==================
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ================== 6. 自毁 ==================
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

echo "=========================================="
echo "   diy2.sh 执行完毕！"
echo "=========================================="

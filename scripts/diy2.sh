#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt) - 最终稳定版
# 📝 功能：LAN IP 192.168.6.1，移除 SmartDNS，关闭 AP 隔离
#          无线稳定性增强（rssi_threshold、disassoc_low_ack、powersave等）
#          WiFi 2.4G/5G SSID明确分开，强制加密
# ❌ 移除：所有主题相关操作（保留官方默认主题）
# ==========================================

set -e

# 1. LAN IP 固定为 192.168.6.1
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 拉取插件（如有）
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan || echo "插件已存在或拉取失败，继续"

# ==========================================
# 构建 UCI 自动化初始化脚本 (首次开机运行)
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

# ================== 3. 直接设置 2.4G 和 5G 的接口（避免动态匹配） ==================
# 通常 2.4G 对应 @wifi-iface[0]，5G 对应 @wifi-iface[1]，但为了保险，我们通过 device 匹配设置
# 先删除可能存在的旧配置，然后重新添加
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
# 信号剔除阈值设为 -85（保持连接）
uci set wireless.radio0.rssi_threshold='-85'
uci set wireless.radio1.rssi_threshold='-85'

# 关闭低确认断开
uci set wireless.radio0.disassoc_low_ack='0'
uci set wireless.radio1.disassoc_low_ack='0'

# 禁止客户端省电模式（避免断连假死）
uci set wireless.radio0.powersave='0'
uci set wireless.radio1.powersave='0'

# 清空速率限制（不强制最低速率）
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

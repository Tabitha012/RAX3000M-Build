#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt) - 修正主题集成路径
# 📝 保留：WiFi 澳洲鸡血、BBR 加速、LAN IP 锁定
# ❌ 移除：SmartDNS 全套配置、DNS 转发规则
# 📦 主题：从仓库根目录 files/root/ 解压到 files/，删除 ipk
# ✅ 新增：强制关闭无线客户端隔离 (isolate='0')
# 🔧 LAN IP 改为 192.168.1.33
# ==========================================

# 1. 默认 LAN IP 强行锁死为 192.168.1.33
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.1.33/g' package/base-files/files/bin/config_generate

# 2. 移除官方 argon 主题（避免与你的自定义主题冲突）
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# ==========================================
# 4. 编译时集成自定义 Argon 主题（操作仓库根目录的 files/）
# ==========================================
# 当前工作目录为 openwrt/，仓库根目录是 ../
THEME_IPK="../files/root/luci-theme-argon_2.3.1_all.ipk"
if [ -f "$THEME_IPK" ]; then
    echo ">>> 正在解压主题 ipk 到 ../files/ 目录..."
    # 进入 ipk 所在目录
    cd ../files/root
    # 解包 ipk
    ar x luci-theme-argon_2.3.1_all.ipk
    # 解压 data.tar.gz 到 files/ 根目录（即 ../）
    tar -xzf data.tar.gz -C ../
    # 清理所有临时文件（包括 ipk）
    rm -f luci-theme-argon_2.3.1_all.ipk data.tar.gz control.tar.gz debian-binary
    cd - > /dev/null
    echo ">>> 主题已集成至 ../files/，ipk 已删除"
else
    echo "⚠️ 警告：未找到 $THEME_IPK，跳过主题集成"
fi

# ==========================================
# 构建 UCI 自动化初始化脚本 (首次开机运行)
# ==========================================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== 1. Dnsmasq 恢复默认（无 SmartDNS） ==================
uci set dhcp.@dnsmasq[0].port='53'
uci commit dhcp

# ================== 2. WiFi 27/22 功率 澳洲鸡血 + 关闭 AP 隔离 ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.txpower='22'

# 动态匹配接口
wif0=$(uci show wireless | grep -E "\.device='?radio0'?" | head -n1 | cut -d'.' -f1-2)
wif1=$(uci show wireless | grep -E "\.device='?radio1'?" | head -n1 | cut -d'.' -f1-2)

if [ -n "$wif0" ]; then
    uci set ${wif0}.ssid='immortalwrt2.4'
    uci set ${wif0}.encryption='psk2'
    uci set ${wif0}.key='12345678'
    uci set ${wif0}.isolate='0'          # 强制关闭 AP 隔离
fi

if [ -n "$wif1" ]; then
    uci set ${wif1}.ssid='immortalwrt5.0'
    uci set ${wif1}.encryption='psk2'
    uci set ${wif1}.key='12345678'
    uci set ${wif1}.isolate='0'          # 强制关闭 AP 隔离
fi
uci commit wireless

# ================== 3. 主题 + BBR 优化 ==================
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ================== 4. 自毁 ==================
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

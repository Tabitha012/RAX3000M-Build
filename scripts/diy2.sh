#!/bin/bash
# ==========================================
# 🚀 目标设备：RAX3000M (ImmortalWrt)
# 📝 固件内直接集成主题（非开机安装）
# 🔧 LAN IP: 192.168.6.1
# ❌ 移除 SmartDNS
# ✅ 关闭 AP 隔离，WiFi 鸡血
# ==========================================

set -e  # 遇到错误立即退出，便于排查

# 1. LAN IP 固定为 192.168.6.1
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 移除官方 Argon 主题（避免冲突）
rm -rf feeds/luci/themes/luci-theme-argon

# 3. 拉取插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan

# ==========================================
# 4. 直接在当前目录（openwrt/）下创建 files/ 并集成主题
#    这样无论后续如何复制，都确保主题文件被打包进固件
# ==========================================
mkdir -p files/root

# 主题 ipk 位于仓库根目录的 files/root/ 下
THEME_SOURCE="../files/root/luci-theme-argon_2.3.1_all.ipk"

if [ -f "$THEME_SOURCE" ]; then
    echo ">>> 找到主题 ipk: $THEME_SOURCE"
    # 复制到当前目录的 files/root/
    cp "$THEME_SOURCE" files/root/
    cd files/root
    echo ">>> 正在解压 ipk..."
    ar x luci-theme-argon_2.3.1_all.ipk
    echo ">>> 解压 data.tar.gz 到 files/ 根目录（即 ../）"
    tar -xzf data.tar.gz -C ../
    # 清理临时文件（包括 ipk）
    rm -f luci-theme-argon_2.3.1_all.ipk data.tar.gz control.tar.gz debian-binary
    cd ../..
    echo ">>> ✅ 主题集成成功！以下为解压出的文件列表："
    ls -la files/usr/lib/lua/luci/view/theme/argon/ || echo "⚠️ 警告：未找到 argon 目录，请检查 ipk 文件"
    ls -la files/etc/uci-defaults/ || echo "⚠️ 警告：未找到 uci-defaults 目录"
else
    echo "⚠️ 警告：未找到 $THEME_SOURCE，跳过主题集成"
fi

# ==========================================
# 5. 构建 UCI 自动化初始化脚本 (首次开机)
# ==========================================
mkdir -p files/etc/uci-defaults
cat << "EOF" > files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ================== 1. Dnsmasq 恢复默认（无 SmartDNS） ==================
uci set dhcp.@dnsmasq[0].port='53'
uci commit dhcp

# ================== 2. WiFi 澳洲鸡血 + 关闭 AP 隔离 ==================
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='AU'
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.txpower='27'

uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='AU'
uci set wireless.radio1.htmode='HE160'
uci set wireless.radio1.txpower='22'

wif0=$(uci show wireless | grep -E "\.device='?radio0'?" | head -n1 | cut -d'.' -f1-2)
wif1=$(uci show wireless | grep -E "\.device='?radio1'?" | head -n1 | cut -d'.' -f1-2)

if [ -n "$wif0" ]; then
    uci set ${wif0}.ssid='immortalwrt2.4'
    uci set ${wif0}.encryption='psk2'
    uci set ${wif0}.key='12345678'
    uci set ${wif0}.isolate='0'
fi

if [ -n "$wif1" ]; then
    uci set ${wif1}.ssid='immortalwrt5.0'
    uci set ${wif1}.encryption='psk2'
    uci set ${wif1}.key='12345678'
    uci set ${wif1}.isolate='0'
fi
uci commit wireless

# ================== 3. 主题已经内置，直接指定路径 ==================
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# ================== 4. BBR 优化 ==================
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ================== 5. 自毁 ==================
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

echo ">>> UCI 初始化脚本已生成"

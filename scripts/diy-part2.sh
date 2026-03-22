# ===== WiFi（安全方式修改，不覆盖驱动生成）
uci set wireless.@wifi-iface[0].ssid='immortalwrt2.4'
uci set wireless.@wifi-iface[0].encryption='sae-mixed'
uci set wireless.@wifi-iface[0].key='sudo-i_2026'

uci set wireless.@wifi-iface[1].ssid='immortalwrt5.0'
uci set wireless.@wifi-iface[1].encryption='sae-mixed'
uci set wireless.@wifi-iface[1].key='sudo-i_2026'

uci commit wireless


# ===== LAN IP
uci set network.lan.ipaddr='192.168.6.1'
uci commit network


# ===== DNS 防泄露（关键）
uci set dhcp.@dnsmasq[0].noresolv='1'
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#6053'
uci commit dhcp

# https://wiki.debian.org/WireGuard#Installation
# https://www.wireguard.com/netns/

# sudo systemctl enable/disable wg-quick@wg0
# sudo systemctl restart/start/stop wg-quick@wg0
# sudo journalctl -xeu wg-quick@wg0.service

# Put private key in /et/wireguard/wg-xx.conf
# wg genkey | save private
# open private
# open private | wg pubkey

# Config file needed for these functions to work
# /etc/wireguard/wg-xx.conf
#
# [Interface]
# # To get pubkey save privatekey in file and run `open private | wg pubkey`
# PrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
#
# [Peer]
# PublicKey = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
# AllowedIPs = 0.0.0.0/0, ::/0
# Endpoint = CCC.CCC.CCC.CCC:51820

export module container {
    export def up [
      --addr: string = "10.14.0.2/16",
      --conf: path = /etc/wireguard/wg-ch.conf
    ] {

        print $"(ansi pb)create netns called container(ansi reset)"
        sudo ip netns add container

        print $"(ansi pb)create wireguard interface in init namespace(ansi reset)"
        sudo ip link add wg0 type wireguard

        # needs to be done before moving wg0 to container otherwise dns resolution won't work
        print $"(ansi pb)setconf wg0(ansi reset)"
        sudo wg setconf wg0 $conf

        print $"(ansi pb)move it to container netns(ansi reset)"
        sudo ip link set wg0 netns container

        print $"(ansi pb)configure wg0(ansi reset)"
        sudo ip -n container addr add $addr dev wg0

        print $"(ansi pb)wg0 up(ansi reset)"
        sudo ip -n container link set wg0 up

        print $"(ansi pb)bring up loopback interface for container netns(ansi reset)"
        sudo ip netns exec container ip link set dev lo up

        print $"(ansi pb)adding default route(ansi reset)"
        sudo ip -n container route add default dev wg0
    }

    export def down [ ] {
        print $"(ansi pb)"delete wg0"(ansi reset)"
        try { sudo ip -n container link del wg0 }

        print $"(ansi pb)"removing container netns"(ansi reset)"
        try { sudo ip netns del container }
    }

    # run app's traffic throughvpn
    #
    # Examples:
    #   Get ip and geolocation of vpn
    #   > vpn container exec curl https://ipinfo.io
    export def exec [...command: string] {
            sudo -E ip netns exec container sudo -E -u $"#(id -u)" -g $"#(id -g)" ...$command
    }
}

export module route-all-traffic {

    # ensures all traffic goes through vpn
    export def up [
      --iface_eth: string = "eno1",
      --iface_wlan: string = "wlp2s0",
      --addr: string = "10.14.0.2/16",
	  --conf: path = /etc/wireguard/wg-ch.conf
    ] {
        print $"(ansi pb)"killing wpa_supplicant & dhcpd"(ansi reset)"
        try { sudo killall wpa_supplicant dhcpcd }

        print $"(ansi pb)"adding physical netns"(ansi reset)"
        sudo ip netns add physical

        print $"(ansi pb)"creating wg0"(ansi reset)"
        # The birthplace is now the "physical" namespace,
        # which means the wireguard ciphertext UDP sockets will be assigned to devices like eth0 and wlan0
        sudo ip -n physical link add wg0 type wireguard
        # We can now move it into the "init" (1) namespace and it will still remember its birthplace for the sockets.
        sudo ip -n physical link set wg0 netns 1

        print $"(ansi pb)configuring wg0(ansi reset)"
        sudo wg setconf wg0 $conf
        sudo ip addr add $addr dev wg0

        print $"(ansi pb)moving ($iface_eth) to netns(ansi reset)"
        sudo ip link set $iface_eth down
        sudo ip link set $iface_eth netns physical

        print $"(ansi pb)bringing up ($iface_eth)(ansi reset)"
        sudo ip -n physical link set $iface_eth up

        print $"(ansi pb)moving ($iface_wlan) to netns(ansi reset)"
        sudo ip link set $iface_wlan down
        sudo iw phy phy0 set netns name physical

        #print $"(ansi pb)bringing up ($iface_wlan)(ansi reset)"
        #sudo ip -n physical link set $iface_wlan up

        print $"(ansi pb)start dhcpcd for ($iface_eth)(ansi reset)"
        # add "export PATH=$PATH:/sbin:/usr/sbin" to .bashrc if dhcpcd not found
        sudo ip netns exec physical dhcpcd -b $iface_eth
        # sudo ip netns exec physical dhcpcd -b $iface_wlan
        # sudo ip netns exec physical wpa_supplicant -B -c/etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i$iface_wlan

        print $"(ansi pb)setting wg0 up(ansi reset)"
        sudo ip link set wg0 up
        sudo ip route add default dev wg0
    }

    export def down [
      iface_eth: string = "eno1",
      iface_wlan: string = "wlp2s0",
    ] {
        print $"(ansi pb)killing processes(ansi reset)"
        try { killall wpa_supplicant dhcpcd }

        print $"(ansi pb)removing eth from physical netns(ansi reset)"
        try { sudo ip -n physical link set $iface_eth down }
        try { sudo ip -n physical link set $iface_eth netns 1 }

        print $"(ansi pb)removing wlan from physical netns(ansi reset)"
        try { sudo ip -n physical link set $iface_wlan down }
        try { sudo ip netns exec physical iw phy phy0 set netns 1 }

        print $"(ansi pb)delete wg0(ansi reset)"
        try { sudo ip link del wg0 }

        print $"(ansi pb)removing physical netns(ansi reset)"
        try { sudo ip netns del physical }

        print $"(ansi pb)start dhcpcd for ($iface_eth)(ansi reset)"
        sudo dhcpcd -b $iface_eth
        # dhcpcd -b $iface_wlan
        # wpa_supplicant -B -c/etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i$iface_wlan
    }

    # run command bypassing vpn (goes directly to physical device)
    #
    # Examples:
    #
    # curl https://ipinfo.io
    # vpn routing-all-traffic bypass curl https://ipinfo.io
    export def bypass [...command: string] {
        sudo -E ip netns exec physical sudo -E -u $"#(id -u)" -g $"#(id -g)" ...$command
    }

}

package discovery

import (
	"net"
	"strconv"
	"time"

	"seeker/internal/config"
)

// Service 在局域网内周期性 UDP 广播自身地址，便于移动端自动发现后端，
// 避免手机端硬编码/手动配置局域网 IP（换 WiFi 后能自愈）。
const (
	magic      = "SEEKER-DISCOVER"
	udpPort    = 18999
	broadcastInterval = 3 * time.Second
)

// Start 启动广播协程，向 255.255.255.255:udpPort 周期性发送 "magic|ip:port"。
// 会广播本机所有非回环 IPv4 地址（含 WiFi 局域网地址、USB 共享网络的链路本地
// 169.254.x.x 地址等），这样真机无论是同一 WiFi 还是通过 USB 网络共享连接 Mac，
// 都能自动发现到正确的后端地址，无需手动配置。
func Start(cfg *config.Config) {
	go func() {
		conn, err := net.ListenPacket("udp", ":0")
		if err != nil {
			return
		}
		defer conn.Close()

		// 计算各子网广播地址（含 WiFi 子网与 USB 链路本地 169.254.255.255），
		// 确保真机无论在同一 WiFi 还是 USB 网络共享下都能收到广播。
		broadcastAddrs := broadcastUDPAddrs(udpPort)

		ticker := time.NewTicker(broadcastInterval)
		defer ticker.Stop()

		send := func() {
			for _, ip := range localIPv4Addrs() {
				msg := magic + "|" + ip + ":" + cfg.Server.Port
				for _, baddr := range broadcastAddrs {
					_, _ = conn.WriteTo([]byte(msg), baddr)
				}
			}
		}
		send() // 立即广播一次
		for range ticker.C {
			send()
		}
	}()
}

// localIPv4Addrs 返回本机所有非回环、已启用的 IPv4 地址。
// 用于局域网/USB 自动发现：覆盖 WiFi 局域网地址与 USB 共享网络的链路本地地址。
func localIPv4Addrs() []string {
	var out []string
	ifaces, err := net.Interfaces()
	if err != nil {
		return out
	}
	for _, iface := range ifaces {
		// 跳过未启用或回环接口
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			var ip net.IP
			switch v := a.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil || ip.IsLoopback() {
				continue
			}
			if ipv4 := ip.To4(); ipv4 != nil {
				out = append(out, ipv4.String())
			}
		}
	}
	if len(out) == 0 {
		out = append(out, "127.0.0.1")
	}
	return out
}

// broadcastUDPAddrs 根据各接口的子网计算广播地址（如 10.254.95.255、
// 169.254.255.255），使后端广播能覆盖 USB 网络共享的链路本地子网，
// 而不仅是全局 255.255.255.255（后者在链路本地网络常被丢弃）。
func broadcastUDPAddrs(port int) []net.Addr {
	var addrs []net.Addr
	seen := map[string]bool{}
	ifaces, err := net.Interfaces()
	if err != nil {
		return addrs
	}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagBroadcast == 0 {
			continue
		}
		ias, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, a := range ias {
			ipNet, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			ip4 := ipNet.IP.To4()
			if ip4 == nil || ipNet.IP.IsLoopback() {
				continue
			}
			// 计算广播地址 = 网络地址 | ~掩码
			mask := ipNet.Mask
			broadcast := make(net.IP, len(ip4))
			for i := range ip4 {
				broadcast[i] = ip4[i] | ^mask[i]
			}
			addrStr := broadcast.String() + ":" + strconv.Itoa(port)
			if seen[addrStr] {
				continue
			}
			seen[addrStr] = true
			if udpAddr, err := net.ResolveUDPAddr("udp", addrStr); err == nil {
				addrs = append(addrs, udpAddr)
			}
		}
	}
	// 兜底：全局广播
	if global, err := net.ResolveUDPAddr("udp", "255.255.255.255:"+strconv.Itoa(port)); err == nil {
		addrs = append(addrs, global)
	}
	return addrs
}

from scapy.all import ARP, sniff

def detect_arp_spoof(pkt):
    if ARP in pkt and pkt.op == 2:  # ARP Response
        print(f"Possible MITM Attack! IP {pkt[ARP].psrc} has conflicting MAC {pkt.hwsrc}")

# Start sniffing for ARP packets
sniff(prn=detect_arp_spoof, store=0)

seen = {}

def detect_arp_spoof(pkt):
    if ARP in pkt and pkt.op == 2:
        ip = pkt[ARP].psrc
        mac = pkt[ARP].hwsrc
        if ip in seen and seen[ip] != mac:
            print(f"⚠️ ARP Spoofing Detected! {ip} changed MAC from {seen[ip]} to {mac}")
        else:
            seen[ip] = mac

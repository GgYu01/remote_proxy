import json
import os
import uuid

def load_env_file(filepath):
    config = {}
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    key, _, value = line.partition('=')
                    config[key.strip()] = value.strip()
    return config

def main():
    config = load_env_file('config.env')
    
    # Defaults
    base_port = int(config.get('BASE_PORT', 10000))
    user = config.get('PROXY_USER', 'admin')
    password = config.get('PROXY_PASS', 'password')
    vmess_uuid = config.get('VMESS_UUID') or str(uuid.uuid4())
    ss_method = config.get('SS_METHOD', 'chacha20-ietf-poly1305')
    ss_pass = config.get('SS_PASSWORD', 'secret')
    
    print(f"Generating config with Base Port: {base_port}")
    
    sb_config = {
        "log": {
            "level": "info",
            "timestamp": True
        },
        "dns": {
            "servers": [
                {"tag": "google", "address": "8.8.8.8"},
                {"tag": "local", "address": "local"}
            ],
            "strategy": "ipv4_only"
        },
        "inbounds": [
            # 1. SOCKS5 (Local/Debug)
            {
                "type": "socks",
                "tag": "socks-in",
                "listen": "::",
                "listen_port": base_port,
                "users": [{"username": user, "password": password}]
            },
            # 2. HTTP (Local/Debug)
            {
                "type": "http",
                "tag": "http-in",
                "listen": "::",
                "listen_port": base_port + 1,
                "users": [{"username": user, "password": password}]
            },
            # 3. Shadowsocks (Low Mem, High Speed)
            {
                "type": "shadowsocks",
                "tag": "ss-in",
                "listen": "::",
                "listen_port": base_port + 2,
                "method": ss_method,
                "password": ss_pass
            },
            # 4. VLESS (High Efficiency, Low Overhead) - REPLACES VMess as Primary
            {
                "type": "vless",
                "tag": "vless-in",
                "listen": "::",
                "listen_port": base_port + 3,
                "users": [{"uuid": vmess_uuid, "flow": ""}]
            },
            # 5. Trojan (HTTPS Camouflage, Stability)
            {
                "type": "trojan",
                "tag": "trojan-in",
                "listen": "::",
                "listen_port": base_port + 4,
                "users": [{"password": password}]
            }
        ],
        "outbounds": [
            {
                "type": "direct", 
                "tag": "direct",
                # Stealth: Use system stack to mimic standard OS traffic
                "domain_strategy": "ipv4_only" 
            },
            {"type": "block", "tag": "block"}
        ]
    }
    
    with open('singbox.json', 'w') as f:
        json.dump(sb_config, f, indent=2)
    
    print("[OK] singbox.json generated successfully.")

if __name__ == '__main__':
    main()

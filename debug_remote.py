import paramiko
import time
import sys

HOST = "154.83.94.182"
USER = "root"
PASS = "G6HARGj!La8NsKZGdY"

def run_cmd(ssh, cmd):
    print(f">>> Executing: {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='ignore').strip()
    err = stderr.read().decode('utf-8', errors='ignore').strip()
    # Use ASCII logging to avoid Windows console crash
    if out: 
        try:
            print(f"STDOUT:\n{out}")
        except UnicodeEncodeError:
            print(f"STDOUT (ascii):\n{out.encode('ascii', 'ignore').decode()}")
    if err: 
        try:
            print(f"STDERR:\n{err}")
        except UnicodeEncodeError:
            print(f"STDERR (ascii):\n{err.encode('ascii', 'ignore').decode()}")
    return exit_status, out, err

def main():
    print(f"Connecting to {HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS)
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)

    print("Connected.")

    # 1. Sync Code (assuming repo exists, user said they ran install.sh)
    # We might need to stash local changes if any
    run_cmd(ssh, "cd ~/remote_proxy && git config --global --add safe.directory /root/remote_proxy && git fetch && git reset --hard origin/master")

    # 2. Run Deploy Script to reproduce failure
    run_cmd(ssh, "chmod +x ~/remote_proxy/scripts/*.sh")
    run_cmd(ssh, "cd ~/remote_proxy && ./scripts/deploy.sh")
    
    # 3. Manual Generator Diagnosis
    print("\n--- DIAGNOSING QUADLET ---")
    # Check if file exists
    run_cmd(ssh, "ls -l /etc/containers/systemd/remote-proxy.container")
    
    print("\n--- CHECKING FILE CONTENT ---")
    run_cmd(ssh, "cat /etc/containers/systemd/remote-proxy.container")

    print("\n--- CHECKING CONFIG ---")
    run_cmd(ssh, "cat ~/remote_proxy/config.env")
    run_cmd(ssh, "ls -l /root/remote_proxy/singbox.json")

    print("\nRunning Podman Quadlet Dryrun...")
    # Try the modern debug command
    run_cmd(ssh, "podman quadlet -dryrun")
    
    # Also check if the generator works with the correct env var (if older/different)
    # run_cmd(ssh, "export PODMAN_SYSTEMD_LOG_LEVEL=debug; /usr/lib/systemd/system-generators/podman-system-generator ...")
    
    # Check if service generated
    run_cmd(ssh, "ls -l /run/systemd/generator/remote-proxy.service")
    
    # Check logs
    run_cmd(ssh, "journalctl -t podman-system-generator -n 50 --no-pager")

    ssh.close()

if __name__ == "__main__":
    main()

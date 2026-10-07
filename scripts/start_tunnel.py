import subprocess
import re
import time
import sys
import os

def start_tunnel():
    print("=======================================================")
    print("VETRI: STARTING CLOUDFLARE TUNNEL (OPTION C)")
    print("=======================================================")
    
    cloudflared_bin = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cloudflared.exe"))
    if not os.path.exists(cloudflared_bin):
        print(f"Error: {cloudflared_bin} not found!")
        sys.exit(1)

    print("Spawning Cloudflare quick tunnel to http://localhost:8000 ...")
    cmd = [cloudflared_bin, "tunnel", "--url", "http://localhost:8000"]
    
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    tunnel_url = None
    url_pattern = re.compile(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com")

    for line in iter(proc.stdout.readline, ''):
        print(line, end="")
        match = url_pattern.search(line)
        if match:
            tunnel_url = match.group(0)
            print("\n" + "="*60)
            print("🚀 PUBLIC LIVE SMARTPHONE LINK GENERATED:")
            print(f"   {tunnel_url}")
            print("="*60 + "\n")
            print("Open this URL on your phone's browser (Chrome / Safari / etc.)")
            print("You can also tap 'Add to Home Screen' to launch it as an installed app!")
            break

    # Keep tunnel alive
    try:
        proc.wait()
    except KeyboardInterrupt:
        print("\nStopping tunnel...")
        proc.terminate()

if __name__ == "__main__":
    start_tunnel()

#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Set up Node.js 18.x from NodeSource and install it
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install necessary packages (ffmpeg, python3-pip, npm will be installed with nodejs)
sudo apt install -y ffmpeg python3-pip

# Verify ffmpeg installation
ffprobe --version

# Install whisper-ctranslate2 using pip
sudo pip3 install whisper-ctranslate2

# Add PeerTube runner user (skip if it already exists)
if id "prunner" &>/dev/null; then
    echo "User prunner already exists."
else
    sudo useradd -m -d /srv/prunner -s /bin/bash prunner
    echo "User prunner created."
fi

# Get the hostname and remove 'peertube-' prefix
full_hostname=$(hostname)
runner_name=${full_hostname#peertube-}  # Remove 'peertube-' prefix

# Create necessary directories for PeerTube Runner configuration
sudo mkdir -p /srv/prunner/.config/peertube-runner-nodejs/default
sudo chown -R prunner:prunner /srv/prunner/.config

# Install PeerTube runner globally via npm
sudo npm install -g @peertube/peertube-runner

# Create systemd service for prunner with correct configuration
sudo tee /etc/systemd/system/prunner.service > /dev/null <<EOL
[Unit]
Description=PeerTube runner daemon
After=network.target

[Service]
Type=simple
Environment=NODE_ENV=production
User=prunner
Group=prunner
ExecStart=peertube-runner server
WorkingDirectory=/srv/prunner
SyslogIdentifier=prunner
Restart=always

# Some security directives
ProtectSystem=full
PrivateDevices=false
NoNewPrivileges=true
ProtectHome=false
CapabilityBoundingSet=~CAP_SYS_ADMIN

[Install]
WantedBy=multi-user.target
EOL

# Append the provided SSH key to authorized_keys
sudo tee -a /home/cloud/.ssh/authorized_keys > /dev/null <<EOL
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWh26GAn1N437O27i7G1WR+SBmNfqpYRPMaBWg9Jy+vV1xa5aSdRtV4J1EJZUgxAkJJ9aeT6xzYY6k+L6bbLmzjyeCmbC3ohtdamiX57v8SFZ18qLpX/GJVvU2JkXg483SXq8VZUJ1IlqwQ/xB+9px07rN3M9tD47ouYe1OxLhsebtFEZ+OjMgNdEcXpyHqIeYpvC4NK9c8IzjIRam2QfSysTOKVnV14BfItGGSVNUy7reB+QF/N7SzHKP8G+KrtXKumGPSXZdzQByOin4mcwF5Aa4czAskdlFwDfDx9wFR44m8dQKyNnGMfpMpb/34/V7m9yB3qC5G7ktyzL08Z7tMjVJFYnONei0CwP2R1UortOr9ZDmGIS7fpZZCvHwLZ3R1YXI8F8H/g5eZyxKCOhjAxZ3bdl8wmVLNQ0K2paWW1iWVF+b1rjP3xzmlJVWLbymLI2iJFKvOVpV1XTMZC2KIw36tZS0lPH33RyrWRICqF2cZuutYuAnCibdbfekwac= cloud@peertube-greyhive
EOL

# Reload systemd, enable and start the prunner service
sudo systemctl daemon-reload
sudo systemctl enable prunner.service
sudo systemctl restart prunner.service
sudo -u prunner peertube-runner register --url https://greyhive.americancloud.dev --registration-token ptrrt-c3463302-e899-46b4-ae0e-bf401f10d092 --runner-name $runner_name
sleep 2
sudo -u prunner sed -i 's/concurrency = [0-9]\+/concurrency = 4/' /srv/prunner/.config/peertube-runner-nodejs/default/config.toml

# Check installed versions of node and npm
#node -v
#npm -v

# Set the correct permissions for the authorized_keys file
#sudo chmod 600 /home/cloud/.ssh/authorized_keys
#sudo chown -R cloud:cloud /home/cloud/.ssh

# Optionally show logs and verify processes (uncomment as needed)
# sudo journalctl -u prunner.service
# ps aux | grep prunner

sudo reboot

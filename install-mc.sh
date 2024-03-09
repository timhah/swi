#!/bin/bash

source /etc/os-release

if [[ $ID == "debian" || $ID == "ubuntu" ]]; then
    JAVAPKG="openjdk-11-jdk"

    if [[ $ID == "debian" && $VERSION_ID -ne 10 ]]; then
        JAVAPKG="openjdk-17-jdk"
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt install -y $JAVAPKG wget screen
elif [[ $ID == "centos" ]]; then
    yum -y update
    yum -y install java-11-openjdk-headless wget screen
else
    echo "Unsupported OS!"
    exit 1
fi

adduser --disabled-password --gecos "" minecraft
cd /home/minecraft
mkdir default
wget -qO default/server.jar https://launcher.mojang.com/v1/objects/1b557e7b033b583cd9f66746b7a9ab1ec1673ced/server.jar
echo "eula=true" > default/eula.txt
chown -R minecraft:minecraft .

cat << SYSTEMD > /etc/systemd/system/minecraft@.service
[Unit]
Description=Minecraft Server %i
After=network.target

[Service]
WorkingDirectory=/home/minecraft/%i
PrivateUsers=true
# Users Database is not available for within the unit, only root and minecraft is available, everybody else is nobody
User=minecraft
Group=minecraft
ProtectSystem=full
# Read only mapping of /usr /boot and /etc
ProtectHome=false
# /home, /root and /run/user seem to be empty from within the unit. It is recommended to enable this setting for all long-running services (in particular network-facing ones).
ProtectKernelTunables=true
# /proc/sys, /sys, /proc/sysrq-trigger, /proc/latency_stats, /proc/acpi, /proc/timer_stats, /proc/fs and /proc/irq will be read-only within the unit. It is recommended to turn this on for most services.
# Implies MountFlags=slave
ProtectKernelModules=true
# Block module system calls, also /usr/lib/modules. It is recommended to turn this on for most services that do not need special file systems or extra kernel modules to work
# Implies NoNewPrivileges=yes
ProtectControlGroups=true
# It is hence recommended to turn this on for most services.
# Implies MountAPIVFS=yes

ExecStart=/bin/sh -c '/usr/bin/screen -dmS mc-%i /usr/bin/java -server -Xms1024M -Xmx1024M -XX:+UseG1GC -XX:ParallelGCThreads=2 -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -jar server.jar nogui'

ExecReload=/usr/bin/screen -p 0 -S mc-%i -X eval 'stuff "reload"\\015'

ExecStop=/usr/bin/screen -p 0 -S mc-%i -X eval 'stuff "say SERVER SHUTTING DOWN. Saving map..."\\015'
ExecStop=/usr/bin/screen -p 0 -S mc-%i -X eval 'stuff "save-all"\\015'
ExecStop=/usr/bin/screen -p 0 -S mc-%i -X eval 'stuff "stop"\\015'
ExecStop=/bin/sleep 10

Restart=on-failure
RestartSec=60s

RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl enable minecraft@default
systemctl start minecraft@default

exit 0

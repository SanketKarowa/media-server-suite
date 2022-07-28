#!/bin/bash
set -e

function line()
{
  echo "-----------------------------------------------------------------"
}

echo "------------  SCRIPT RUN STARTED -----------------------"

path=/mnt/ext-ssd/downloads
base=/home/pi/docker
ssd_uuid=aa1c7418-b69d-d801-a018-7418b69dd801

mkdir -p /mnt/ext-ssd/downloads
mkdir -p /home/pi/docker

if [ `which docker | wc -l` -ne 1 ]
then
   curl -fsSL https://get.docker.com -o ${base}/get-docker.sh
   chmod +x ${base}/get-docker.sh
   ${base}/get-docker.sh
   line
fi
if [ `which git | wc -l` -ne 1 ]; then apt install -y git; line; fi

echo "UUID=${ssd_uuid} /mnt/ext-ssd  ext4  defaults 0 2" | tee -a /etc/fstab

line
wget -qO $base/start.sh "https://raw.githubusercontent.com/SanketKarowa/media-server-suite/master/start.sh"
chmod 777 $base/start.sh

{ crontab -l -u root; echo '@reboot '${base}/start.sh; } | crontab -u root -

line

git clone -b dev https://github.com/sachinOraon/QBittorrentBot.git $base/qbot
cd $base/qbot
sed -i 's/AUTHORIZED_IDS = \[\]/AUTHORIZED_IDS = \[227723943,1072139158\]/' $base/qbot/config.py
docker build -t qbot:base .

line

docker run -d \
    --name aria2-pro \
    --log-opt max-size=1m \
    -e PUID=1000 \
    -e PGID=1000 \
    -e UMASK_SET=000 \
    -e RPC_SECRET=scaria \
    -e RPC_PORT=6800 \
    -p 8050:6800 \
    -e LISTEN_PORT=6888 \
    -p 6888:6888 \
    -p 6888:6888/udp \
    -v aria2-config:/config \
    --mount type=bind,source=${path},target=/downloads \
    p3terx/aria2-pro

line

docker run -d \
    --name=qbot \
    --net=host \
    -u 0:0 \
    --mount type=bind,source=${base}/qbot,target=/usr/src/app \
    --mount type=bind,source=${path},target=/mnt/downloads \
    -e qbIp=127.0.0.1 \
    -e qbPort=8020 \
    -e qbUser=admin \
    -e qbPsw=adminadmin \
    -e TG-KEY=5071868206:AAFjgODtWnRWzO96gt4Bsg1O2rJIU6AgI2Y \
    -e API-ID=7824626 \
    -e API-HASH=3bec5e5ae5cc077e2bd9730c14b88e07 \
    -e ARIA_IP=127.0.0.1 \
    -e ARIA_PORT=8050 \
    -e ARIA_RPC_TOKEN=scaria \
    qbot:base

line

docker run -d \
--name=h5ai \
--label com.centurylinklabs.watchtower.enable=true \
-p 8030:80 \
--mount type=bind,source=${path},target=/h5ai  \
-v h5ai_config:/config \
-e PUID=1000 \
-e PGID=1000 \
-e TZ=Asia/Kolkata \
awesometic/h5ai:latest

line

touch $base/filebrowser.db
touch $base/settings.json
chmod 777 $base/filebrowser.db $base/settings.json
echo -e '{\n  "port": 80,\n  "baseURL": "",\n  "address": "",\n  "log": "stdout",\n  "database": "/database/filebrowser.db",\n  "root": "/srv",\n  "noauth": true\n}' > $base/settings.json

docker run -d \
--name filebrowser \
--label com.centurylinklabs.watchtower.enable=true \
-e PUID=1000 \
-e PGID=1000 \
-p 8040:80 \
--mount type=bind,source=${path},target=/srv \
--mount type=bind,source=${base}/filebrowser.db,target=/database/filebrowser.db \
--mount type=bind,source=${base}/settings.json,target=/config/settings.json  \
filebrowser/filebrowser:s6

line

docker run -d \
--name=qbittorrent \
--label com.centurylinklabs.watchtower.enable=true \
-e PUID=1000 \
-e PGID=1000 \
-e TZ=Asia/Kolkata \
-e WEBUI_PORT=8080 \
-p 6881:6881 \
-p 6881:6881/udp \
-p 8020:8080 \
-v qbittorrent_config:/config \
--mount type=bind,source=${path},target=/downloads \
lscr.io/linuxserver/qbittorrent:latest

line

docker run -d \
--name portainer \
--label com.centurylinklabs.watchtower.enable=true \
--restart=unless-stopped \
-u 0:0 \
-p 8000:8000 -p 8011:9443 -p 8010:9000 \
--mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer-ce:latest

line

touch $base/ngrok.yml
chmod 777 $base/ngrok.yml
echo -e 'version: 2\nauthtoken: ENTER_AUTOKEN_HERE\nregion: in\nconsole_ui: false\nlog_level: info\nlog_format: logfmt\nlog: stdout\nweb_addr: localhost:4040\ntunnels:\n  portainer:\n    addr: 8010\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  qbittorrent:\n    addr: 8020\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  h5ai:\n    addr: 8030\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  filebrowser:\n    addr: 8040\n    schemes:\n      - http\n    inspect: false\n    proto: http' > $base/ngrok.yml

touch $base/ngrok2.yml
chmod 777 $base/ngrok2.yml
echo -e 'version: 2\nauthtoken: ENTER_AUTOKEN_HERE\nregion: in\nconsole_ui: false\nlog_level: info\nlog_format: logfmt\nlog: stdout\nweb_addr: localhost:4050\ntunnels:\n  ssh:\n    addr: 22\n    inspect: false\n    proto: tcp' > $base/ngrok2.yml

docker run -d \
--name=ngrok \
--restart=unless-stopped \
--net=host \
--label com.centurylinklabs.watchtower.enable=true \
--mount type=bind,source=${base}/ngrok.yml,target=/etc/ngrok.yml \
-e NGROK_CONFIG=/etc/ngrok.yml \
-e PUID=1000 \
-e PGID=1000 \
ngrok/ngrok:alpine start --all

line

docker run -d \
--name=ngrok2 \
--restart=unless-stopped \
--net=host \
--label com.centurylinklabs.watchtower.enable=true \
--mount type=bind,source=$base/ngrok2.yml,target=/etc/ngrok2.yml \
-e NGROK_CONFIG=/etc/ngrok2.yml \
-e PUID=1000 \
-e PGID=1000 \
ngrok/ngrok:alpine start --all

line

docker run -d \
    --name watchtower \
    --restart=unless-stopped \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    -e WATCHTOWER_CLEANUP=true \
    -e WATCHTOWER_REMOVE_VOLUMES=true \
    -e WATCHTOWER_INCLUDE_RESTARTING=true \
    -e WATCHTOWER_INCLUDE_STOPPED=true \
    -e WATCHTOWER_REVIVE_STOPPED=true \
    -e WATCHTOWER_ROLLING_RESTART=true \
    -e WATCHTOWER_LABEL_ENABLE=true \
    -u 0:0 \
    containrrr/watchtower:latest

line
echo "------------  SCRIPT RUN COMPLETED -----------------------\nPlease reboot"

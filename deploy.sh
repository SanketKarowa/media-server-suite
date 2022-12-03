#!/bin/bash
set -e

function line()
{
  echo "-----------------------------------------------------------------"
}

echo "------------  SCRIPT RUN STARTED -----------------------"

MNT_PATH=/mnt/ext-ssd
DL_PATH=$MNT_PATH/downloads
BASE_PATH=/home/pi/docker
DEV_UUID=aa1c7418-b69d-d801-a018-7418b69dd801
DEV_FSTYPE=ext4
TG_BOT_TOKEN=enter_bot_token
TG_API=enter_api
TG_HASH=enter_hash
NG_TOKEN1=enter_ngrok_token1
NG_TOKEN2=enter_ngrok_token2

mkdir -p $DL_PATH
mkdir -p $BASE_PATH

if [ `which docker | wc -l` -ne 1 ]
then
   curl -fsSL https://get.docker.com -o ${BASE_PATH}/get-docker.sh
   chmod +x ${BASE_PATH}/get-docker.sh
   ${BASE_PATH}/get-docker.sh
   line
fi
if [ `which git | wc -l` -ne 1 ]; then apt install -y git; line; fi

echo "UUID=${DEV_UUID}  ${MNT_PATH}  ${DEV_FSTYPE}  defaults 0 2" | tee -a /etc/fstab

line
wget -qO $BASE_PATH/start.sh "https://raw.githubusercontent.com/SanketKarowa/media-server-suite/master/start.sh"
chmod 777 $BASE_PATH/start.sh

BC=`crontab -u root -l | wc -l`
echo '@reboot '${BASE_PATH}/start.sh | crontab -u root -

line

git clone -b dev https://github.com/sachinOraon/QBittorrentBot.git $BASE_PATH/qbot
cd $BASE_PATH/qbot
sed -i 's/AUTHORIZED_IDS = \[\]/AUTHORIZED_IDS = \[227723943,1072139158\]/' $BASE_PATH/qbot/config.py
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
    --mount type=bind,source=${DL_PATH},target=/downloads \
    p3terx/aria2-pro

line

docker run -d \
    --name=qbot \
    --net=host \
    -u 0:0 \
    --mount type=bind,source=${BASE_PATH}/qbot,target=/usr/src/app \
    --mount type=bind,source=${DL_PATH},target=/mnt/downloads \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    -e DOWNLOAD_PATH=${DL_PATH} \
    -e qbIp=127.0.0.1 \
    -e qbPort=8020 \
    -e qbUser=admin \
    -e qbPsw=adminadmin \
    -e TG-KEY=${TG_BOT_TOKEN} \
    -e API-ID=${TG_API} \
    -e API-HASH=${TG_HASH} \
    -e ARIA_IP=127.0.0.1 \
    -e ARIA_PORT=8050 \
    -e ARIA_RPC_TOKEN=scaria \
    qbot:base

line

docker run -d \
--name=h5ai \
--label com.centurylinklabs.watchtower.enable=true \
-p 8030:80 \
--mount type=bind,source=${DL_PATH},target=/h5ai  \
-v h5ai_config:/config \
-e PUID=1000 \
-e PGID=1000 \
-e TZ=Asia/Kolkata \
awesometic/h5ai:latest

line

touch $BASE_PATH/filebrowser.db
touch $BASE_PATH/settings.json
chmod 777 $BASE_PATH/filebrowser.db $BASE_PATH/settings.json
echo -e '{\n  "port": 80,\n  "baseURL": "",\n  "address": "",\n  "log": "stdout",\n  "database": "/database/filebrowser.db",\n  "root": "/srv",\n  "noauth": true\n}' > $BASE_PATH/settings.json

docker run -d \
--name filebrowser \
--label com.centurylinklabs.watchtower.enable=true \
-e PUID=1000 \
-e PGID=1000 \
-p 8040:80 \
--mount type=bind,source=${DL_PATH},target=/srv \
--mount type=bind,source=${BASE_PATH}/filebrowser.db,target=/database/filebrowser.db \
--mount type=bind,source=${BASE_PATH}/settings.json,target=/config/settings.json  \
filebrowser/filebrowser:s6

line

wget -qO ${BASE_PATH}/qBittorrent.conf "https://raw.githubusercontent.com/SanketKarowa/media-server-suite/master/volumes/qbittorrent/config/qBittorrent.conf"
chmod 777 ${BASE_PATH}/qBittorrent.conf

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
--mount type=bind,source=${BASE_PATH}/qBittorrent.conf,target=/config/qBittorrent/qBittorrent.conf \
--mount type=bind,source=${DL_PATH},target=/downloads \
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

touch $BASE_PATH/ngrok.yml
chmod 777 $BASE_PATH/ngrok.yml
echo -e 'version: 2\nauthtoken: '${NG_TOKEN1}'\nregion: in\nconsole_ui: false\nlog_level: info\nlog_format: logfmt\nlog: stdout\nweb_addr: localhost:4040\ntunnels:\n  portainer:\n    addr: 8010\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  qbittorrent:\n    addr: 8020\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  h5ai:\n    addr: 8030\n    schemes:\n      - http\n    inspect: false\n    proto: http\n  filebrowser:\n    addr: 8040\n    schemes:\n      - http\n    inspect: false\n    proto: http' > $BASE_PATH/ngrok.yml

touch $BASE_PATH/ngrok2.yml
chmod 777 $BASE_PATH/ngrok2.yml
echo -e 'version: 2\nauthtoken: '${NG_TOKEN2}'\nregion: in\nconsole_ui: false\nlog_level: info\nlog_format: logfmt\nlog: stdout\nweb_addr: localhost:4050\ntunnels:\n  ssh:\n    addr: 22\n    inspect: false\n    proto: tcp' > $BASE_PATH/ngrok2.yml

docker run -d \
--name=ngrok \
--restart=unless-stopped \
--net=host \
--label com.centurylinklabs.watchtower.enable=true \
--mount type=bind,source=${BASE_PATH}/ngrok.yml,target=/etc/ngrok.yml \
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
--mount type=bind,source=$BASE_PATH/ngrok2.yml,target=/etc/ngrok2.yml \
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
    -e WATCHTOWER_POLL_INTERVAL=14400 \
    -u 0:0 \
    containrrr/watchtower:latest

line
if [ `crontab -u root -l | wc -l` -eq $BC ]; then echo -e "Unable to add entry in crontab, add this manually:\n"; echo '@reboot '${BASE_PATH}/start.sh; line; fi
echo -e "------------  SCRIPT RUN COMPLETED -----------------------\nPlease modify ${BASE_PATH}/start.sh if needed and then REBOOT"
line

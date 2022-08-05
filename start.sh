#!/bin/bash
set -e

LOG_FILE=/home/pi/docker/log.txt
DEV_PATH=/dev/sda1
CONTAINERS=( filebrowser qbittorrent h5ai aria2-pro qbot )

echo $(date "+%F %T")': Starting docker start script' >> $LOG_FILE
for i in {1..5}
do
  if [ `lsblk ${DEV_PATH} --output MOUNTPOINT | wc -l` -eq 2 ]
  then
    echo `date "+%F %T"`': mount point for '${DEV_PATH}' found, starting containers' >> $LOG_FILE
    if [ `systemctl is-active docker.service` == 'active' ]
    then
       for container in "${CONTAINERS[@]}"
       do
           docker start ${container}
           if [ `docker ps --filter "status=running" --filter "name=${container}" -q | wc -l` -eq 1 ]; then echo `date "+%F %T"`': '${container}' started successfully' >> $LOG_FILE; fi
       done
       break
    else
      echo `date "+%F %T"`': docker service not active, Retrying' >> $LOG_FILE
    fi
  else
    echo `date "+%F %T"`': mount point for '${DEV_PATH}' NOT found, Retrying' >> $LOG_FILE
  fi
  sleep 10
done
echo `date "+%F %T"`': Completed docker start script' >> $LOG_FILE

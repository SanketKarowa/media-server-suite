#!/bin/bash
set -e
echo $(date "+%F %T")': Starting docker start script' >> /home/pi/docker/log.txt
for i in {1..5}
do
  if [ `lsblk /dev/sda1 --output MOUNTPOINT | wc -l` -eq 2 ]
  then
    echo `date "+%F %T"`': /dev/sda1 mount point found, starting containers' >> /home/pi/docker/log.txt
    if [ `systemctl is-active docker.service` == 'active' ]
    then
       docker start filebrowser qbittorrent h5ai aria2-pro qbot
       if [ `docker ps --filter "status=running" --filter "name=h5ai" --filter "name=filebrowser" --filter "name=qbittorrent" --filter "name=aria2-pro" --filter "name=qbot" -q | wc -l` -eq 5 ]
       then
         echo `date "+%F %T"`': Containers started successfully' >> /home/pi/docker/log.txt
         break
       fi
    else
      echo `date "+%F %T"`': docker service not active, Retrying' >> /home/pi/docker/log.txt
    fi
  else
    echo `date "+%F %T"`': /dev/sda1 not found, Retrying' >> /home/pi/docker/log.txt
  fi
  sleep 10
done
echo `date "+%F %T"`': Completed docker start script' >> /home/pi/docker/log.txt

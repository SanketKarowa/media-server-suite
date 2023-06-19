"""
Script to reboot the system every midnight or if it's offline for more than 10 mins
Steps to setup:
1. Create a reboot.sh file with following contents:
   #!/bin/sh
   echo b > /sysrq-trigger
2. Create a requirements.txt file with following contents:
   apscheduler
   requests
3. Create a Dockerfile with following contents:
   FROM python:3.9-slim-bullseye
   COPY pi-reboot.py /usr/src/main.py
   COPY reboot.sh /usr/src/reboot.sh
   COPY requirements.txt /usr/src/requirements.txt
   RUN chmod +x /usr/src/reboot.sh
   RUN python -m pip install --no-cache-dir -r /usr/src/requirements.txt
   ENTRYPOINT ["python", "-u", "/usr/src/main.py"]
4. Build the image: docker build -t pi-reboot:latest -f Dockerfile .
5. Finally, run the container using this command:
   docker run -d --restart=unless-stopped --name=pi-reboot --privileged --cap-add=ALL -v /proc/sysrq-trigger:/sysrq-trigger pi-reboot:latest
"""

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.combining import OrTrigger
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
import pytz
import logging
import subprocess
import requests
import json

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)
LAST_ONLINE_AT = None
TEST_API = "https://ipapi.co/json"


def reboot() -> None:
    try:
        subprocess.run(args=["/bin/sh", "/usr/src/reboot.sh"], check=True)
    except subprocess.CalledProcessError:
        logger.warning("Failed to reboot")


def check_and_reboot() -> None:
    global LAST_ONLINE_AT
    current_time = datetime.now(pytz.timezone('Asia/Kolkata'))
    if current_time.hour == 0 and current_time.minute == 0:
        logger.info("It's midnight so rebooting...")
        reboot()
    logger.info("Getting IP info")
    try:
        req = requests.get(url=TEST_API)
        if req.ok:
            req_data = json.loads(req.text)
            logger.info(f"IP: {req_data.get('ip')} [{req_data.get('city')}, {req_data.get('region')},"
                        f"{req_data.get('country_name')}]")
            LAST_ONLINE_AT = current_time
        else:
            logger.warning(f"Failed to get response from {TEST_API}")
        req.close()
    except (requests.exceptions.RequestException, json.JSONDecodeError) as e:
        logger.error(f"Failed to send request [{e.__class__.__name__}]")
    if LAST_ONLINE_AT is not None and (current_time - LAST_ONLINE_AT).total_seconds() >= 600:
        logger.warning("System seems offline for 10 mins, rebooting...")
        reboot()


if __name__ == "__main__":
    scheduler = BlockingScheduler()
    trigger = OrTrigger([IntervalTrigger(minutes=10, timezone='Asia/Kolkata'),
                         CronTrigger(hour=0, minute=0, second=0, timezone='Asia/Kolkata')])
    scheduler.add_job(func=check_and_reboot, trigger=trigger)
    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        logger.info("Exiting the program")
        scheduler.shutdown()

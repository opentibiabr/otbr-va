#!/bin/bash

N=5
DEFAULT_MAP="${DEFAULT_MAP:-otbr}"

echo ""
echo ""
echo "########################################################################"

/bin/bash /otbr/system/va-check-update.sh
/bin/bash /otbr/system/server-build.sh
/bin/bash /otbr/system/server-check-update.sh

echo "######################## STARTING UP SERVICES ##########################"
echo "Starting crontab..."
service cron start
echo ""

echo "Starting PHP-FPM..."
service php8.1-fpm start
pgrep -x php-fpm8.1 >/dev/null && echo "* Starting PHP-FPM        [ OK ]" || echo "PHP-FPM could not start!"
echo ""

echo "Starting Nginx..."
service nginx start

sleep $N

echo "########################################################################"
echo "###################### STARTING UP CANARY SERVER #######################"
echo "########################################################################"
if [ -f /otbr/system/canary ]; then
	echo "Updating OTBR Canary distro..."
	rm /otbr/server/canary
	cp -p /otbr/system/canary /otbr/server/canary
	mv /otbr/system/canary /otbr/system/canary.old
	echo "OTBR Canary distro updated with success!"
fi

if [ "$DEFAULT_MAP" == "otbr" ]; then
	if [ -f /otbr/server/data/world/world.zip ]; then
		UPDATE_MAP="$(curl -L -sI https://www.dropbox.com/s/nmc8w82one8mmp9/world.zip?dl=1 | grep -i Content-Length | awk 'a=$2/617  {print $2}')"
		REMOTE_MAP="$(echo $UPDATE_MAP | grep -o -E '[0-9]+')"
		LOCAL_MAP="$(ls -nl /otbr/server/data/world/world.zip | awk '{print $5}')"

		if [ "$LOCAL_MAP" != "$REMOTE_MAP" ]; then
			echo "Updating map..."
			rm /otbr/server/data/world/world.zip
			if [ -f /otbr/server/data/world/canary.otbm ]; then
				rm /otbr/server/data/world/canary.otbm
			fi
			wget -q -O /otbr/server/data/world/world.zip https://www.dropbox.com/s/nmc8w82one8mmp9/world.zip?dl=1
			echo "Map updated with success!"
		fi
	else
		wget -q -O /otbr/server/data/world/world.zip https://www.dropbox.com/s/nmc8w82one8mmp9/world.zip?dl=1
		echo "Map downloaded with success!"
	fi
fi

ulimit -c unlimited
set -o pipefail
cd /otbr/server ; gdb -ex run --batch -return-child-result --args su otadmin -c ./canary

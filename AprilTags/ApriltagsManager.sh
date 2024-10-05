#! /bin/bash

if [ $# -ne 1 ]; then
    echo "only run with one argument"
    exit 1
fi

if [ ! -f '/apps/AprilTags/Backend/ws_server' ]; then
    echo "missing backend"
    exit 2
elif [ ! -f '/apps/AprilTags/Web/app.py' ]; then
    echo "missing webend"
    exit 2
fi

function killIfRunning() {
    PID=`libAprilTags.sh pid $1`
    if [ $PID -ne 0 ]; then
        kill -2 $PID
    fi
}

#open source for args
source args

if [[ $1 == "start" ]]; then
    # check for lock
    if [ -f "/apps/AprilTags/servicerunning" ]; then
        echo "service is already running"
        echo "HINT: if you think the service is not running, then run 'AprilTags.sh --validate lockfile'"
        # now check if it is allowed to remove the lockfile..
        if [[ $autormlockfile == "true" ]]; then
        	# check for if the services are fine
        	status=$(AprilTags.sh -v -V lockfile)
        	lockfilestatus=$(echo $status | awk -F ";" '{print $1}' | awk -F "=" '{print $2}')
        	if [[ $lockfilestatus == "false" ]]; then
        		# the lockfile is gone, and nothing is wrong
        		echo "removed old lockfile"
        	else
        		echo "the service is still running... exiting"
        		echo "Specific status: ${lockfilestatus}"
        		exit 4
        	fi
        else
        	# either unable to remove the lock or it is running already
        	exit 4
        fi
    fi

    # to fix some odd pathing things
    cd /apps/AprilTags

    touch /apps/AprilTags/servicerunning

    # abs path BECAUSE of the proc getting commands
    /apps/AprilTags/Backend/ws_server $backend &
    
    source /apps/AprilTags/venv/bin/activate;
    python /apps/AprilTags/Web/app.py $frontend &
    exit

elif [[ $1 == "stop" ]]; then
    rm servicerunning
    # and add the rest of it
    killIfRunning '/apps/AprilTags/Backend/ws_server'
    killIfRunning '/apps/AprilTags/Web/app.py'

else
    echo "input ${1} not understood"
    exit 3
fi

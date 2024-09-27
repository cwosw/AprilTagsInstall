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

if [[ $1 == "start" ]]; then
    # check for lock
    if [ -f "servicerunning" ]; then
        echo "service is already running"
        echo "HINT: if you think the service is not running, then run 'AprilTags.sh --validate lockfile'"
        exit 4
    fi

    # to fix some odd pathing things
    cd /apps/AprilTags

    touch servicerunning
    # get args
    source args

    # abs path BECAUSE of the proc getting commands
    /apps/AprilTags/Backend/ws_server $backend &
    
    source Web/venv/bin/activate;
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
#! /bin/bash

function help() {
    echo "#### AprilTags Helper ####"
    echo "-h to print this menu"
    echo "-v to print verbose"
    echo "--validate or -V {option} to validate something"
    echo "--update or -u to update the running frontend/backend from the cuda root"
    echo "ex. -V lockfile"
    echo
    echo "if you try to run two different commands in one command, one might exit before the other"
    echo "if that happens, just seperate the commands, mk?"
    exit 0
}

if [ $# -eq 0 ]; then
    # print help
    help
fi

function ensureRoot() {
    if [ $EUID -ne 0 ]; then
        echo "The script you are trying to run requires root access, and this does not have it"
        echo "please rerun this script with root!"
        exit 4
    fi
}

# print if verbose is on
function printV() {
    if [[ $verbose == "t" ]]; then
        echo $1
    fi
}

# arg parser
while [[ $# -gt 0 ]]; do
  case $1 in
    -v)
      verbose="t"
      shift # past argument
      ;;
    -h)
      help
      ;;
    -V|--validate)
      if [ ! -z ${valitem+x} ]; then
        echo "an item has already been set to be validated, this script can not handle two"
        exit 2
      elif [ ! -n $2 ]; then
        echo "no argument specified after validate arg"
        exit 3
      fi
      valitem="$2"
      shift # past argument
      shift # past value
      ;;
    -u|--update)
      #simply sets a thing to say it should update lol
      ensureRoot
      update="t"
      shift # past arguement
      ;;
    *|-*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# validation checks
if [ ! -z ${valitem+x} ]; then
    printV "validating arg $valitem..."
    if [[ $valitem == "lockfile" ]]; then
        # check for the existance of the lock
        frontPID=$(libAprilTags.sh pid "/apps/AprilTags/Web/app.py")
        backPID=$(libAprilTags.sh pid "/apps/AprilTags/Backend/ws_server")
        printV "FrontendPID is $frontPID and the backendPID is $backPID. (zero is not running)"
        if [ -f /apps/AprilTags/servicerunning ]; then
            # lockfile is there, are the services running?
            printV "lockfile present, checking if backend and frontend are being run"
            if [ $frontPID -ne 0 ] && [ $backPID -ne 0 ]; then
                echo "lockfile=true;servicesrunning=2;"
                printV "Both services appear to be actively running and stable."
            elif ( [ $frontPID -ne 0 ] && [ $backPID -eq 0 ] ) || ( [ $frontPID -eq 0 ] && [ $backPID -ne 0 ] ); then
            	echo "lockfile=true;servicesrunning=1;"
                printV "One service has stopped and the lockfile still remains. It is advised to restart the service."
            else
                rm /apps/AprilTags/servicerunning
                if [ $? -ne 0 ]; then
                    echo "lockfile=rm;servicesrunning=0;"
                    printV "Lockfile found with no services running, it could not be deleted, feel free to delete it."
                else
                    echo "lockfile=false;servicesrunning=0;"
                    printV "Lockfile found with no services running, it is now deleted."
                fi
            fi
        else
            # lockfile missing, check if anything is runing
            printV "lockfile is not there"
            if [ $frontPID -eq 0 ] && [ $backPID -eq 0 ]; then
                echo "lockfile=false;servicesrunning=0;"
                printV "The AprilTags service is offline and the lockfile is not there."
            else
                printV "The lockfile is missing and at least one of the services is running."
                touch /apps/AprilTags/servicerunning
                if [ $? -ne 0 ]; then
                    echo "lockfile=add;servicesrunning=1+;"
                    printV "The lockfile couldn't be created. please make it, or stop the processes!"
                    printV "I have not made an easy way to do this yet, so go to the ApriltagsManager.sh script and run it with 'stop'"
                elif ( [ $frontPID -ne 0 ] && [ $backPID -eq 0 ] ) || ( [ $frontPID -eq 0 ] && [ $backPID -ne 0 ] ); then
                    echo "lockfile=true;servicesrunning=1;"
                    printV "Only one of the two services is running, it is advised to restart the service."
                else
                    echo "lockfile=true;servicesrunning=2;"
                    printV "Both services are online, the lockfile is now in place."
                fi
            fi
        fi
    else
        printV "Unknown option. Please specify the correct option"
        exit 11
    fi
# update checks
# my best recreation of the hierarchy of the processes that I need to keep track of
# codesource
# > build/ws_server (copy/check)
# > build/app/app.py (copy/check)
# > build/app/* (copy over)
elif [ $update == "t" ]; then
    # validate that we are inside of the project root
    # note, below will run inside of the directory that the command is being called in
    if [ ! -f build/ws_server ] || [ ! -f app/app.py ]; then
        printV "This is not the root of the repo, exiting.."
        printV "HINT: This can be an issue using sudo -i, meaning you need to use the script absolute path without the -i in sudo"
        exit 21
    fi

    # disable the service to make sure stuff is ok
    systemctl stop AprilTagsPipeline.service
    # just as a check, make sure that the lockfile is also gone
    rm /apps/AprilTags/servicerunning

    # make sure that the dirs exist. why did I not do this before
    if [ ! -d /apps/AprilTags/Backend ]; then
    	mkdir /apps/AprilTags/Backend
    fi
    if [ ! -d /apps/AprilTags/Web ]; then
    	mkdir /apps/AprilTags/Web
    fi
    if [ -d /apps/AprilTags/venv ]; then
    	rm -rf /apps/AprilTags/venv
    fi

    # note, this copy process could be done wrong, but I really don't know if it is wrong. please check if it is wrong
    printV "copying files..."
    
    printV "copying backend..."
    cp -R build/* /apps/AprilTags/Backend/
    
    printV "copying frontend..."
    cp -R app/* /apps/AprilTags/Web/
    
    # remove the existing data dir if it exists then replace it
    if [ -d /apps/AprilTags/data ]; then
    	rm -rf data
    fi
    if [ -d data ]; then
    	cp -R data/ /apps/AprilTags/data/
    fi
    
    printV "doing the venv stuffs"
    python -m venv /apps/AprilTags/venv
    # removing the new venv stuff by hand
    rm -rf /apps/AprilTags/venv/include /apps/AprilTags/venv/lib /apps/AprilTags/venv/pyvenv.cfg
    # remove stuff from the build venv that is not wanted
    mv /apps/AprilTags/Web/venv /apps/AprilTags/tmpvenv
    rm -rf /apps/AprilTags/tmpvenv/bin
    # delete the lib64 symlink
    rm /apps/AprilTags/tmpvenv/lib64
    # merge the two
    mv /apps/AprilTags/tmpvenv/* /apps/AprilTags/venv/
    rm -d /apps/AprilTags/tmpvenv
    
    printV "The files were sucessfully coppied"

    # restart the service
    systemctl start AprilTagsPipeline.service

# end of the args and stuffs
fi

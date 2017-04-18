#!/bin/bash

# Source the config
if [ -e '/etc/aggie/config' ]
then
  . /etc/aggie/config
else
  logger -s -p daemon.info -t "aggie" "Missing config file in /etc/aggie/config"
  exit 1
fi

# Check/create the pid file to keep cron from spinning up multiple jobs
PIDFILE=/var/run/aggie
if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    logger -s -p daemon.info -t "aggie" "Process already running"
    exit 1
  else
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      logger -s -p daemon.info -t "aggie" "Could not create PID file"
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    logger -s -p daemon.info -t "aggie" "Could not create PID file"
    exit 1
  fi
fi


# Run the sync script
logger -p daemon.info -t "aggie" "Starting aggie sync"
su aggie -c "/opt/aggie/bin/aggie command Elixir.Aggie ship_logs"
logger -p daemon.info -t "aggie" "Aggie sync complete"

# Make sure to remove the pid file
rm $PIDFILE


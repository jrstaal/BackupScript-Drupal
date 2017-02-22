#!/bin/bash

# Backupscript

currentdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define settings file
CONFIGFILE="$currentdir/settings.ini"
NOW=$(date +"%Y-%m-%d_%H:%M:%S")
# Read and parse config file
eval $(sed '/:/!d;/^ *#/d;s/:/ /;' < "$CONFIGFILE" | while read -r key val
do
  if [ -n "${key}" ]; then
    str="$key='$val'"
    echo "$str"
  fi
done
)

# Set full path to log
LOGFILE="/var/log/drupal/dbbackup-$SITENAME.log"

# Function to log to file
log_message() {
  if  [ ! "$2" ]; then
    LEVEL="NOTICE";
  else
    LEVEL="$2";
  fi
  TIMEDATE=`date`
  echo [$TIMEDATE] [$LEVEL] $1 >> $LOGFILE
}

# Function to display current status in dimmed font
status_message() {
  echo
  log_message "$1"
  echo -e "$1..."
}

# Function to show error message and exit
exit_error() {
  echo
  log_message "$1" "ERROR"
  echo -e "$(tput setaf 1)$1 $(tput sgr0)"
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  echo -e "$(tput setaf 1)Aborting Backup $(tput sgr0)"
  log_message "Backup Failed" "ERROR"
  echo
  exit 1
}

# Check if logfile exists
if [ ! -f "$LOGFILE" ]; then
  # Fix access to logfile (sudo??)
  status_message "Trying to fix access to \"$LOGFILE\""
  touch $LOGFILE
  if [ "$BACKUPUSER" ]; then
   chown $BACKUPUSER $LOGFILE
  fi
  chmod 775 $LOGFILE
  if [ ! -f "$LOGFILE" ]; then
    exit_error "Unable to open \"$LOGFILE\"!" "Run this script once with a sudo enabled user or root to set correct permissions on the logfile."
  fi
fi

# Check Backup user
if [ "$BACKUPUSER" ]; then
  if  [ ! "$BACKUPUSER" = "$USER" ]; then
    exit_error "Wrong user: $USER" "Deployscript must be run as user \"$BACKUPUSER\". Try: sudo su \"$BACKUPUSER\" ./backup.sh"
    # sudo su $BACKUPUSER
    # echo
  fi
fi

# Make folder with date of backup
#mkdir $BACKUPPATH/$NOW

# Dump database into SQL file
if [ $DATABASEBACKUP = "YES" ]; then
status_message "** Performing DatabaseBackup \"$DBNAME\" from \"$DBHOST\" **"
	if ! PGPASSWORD="$DBPASSWORD" /usr/pgsql-9.3/bin/pg_dump -h $DBHOST -U $DBUSER $DBNAME | gzip -9 > $BACKUPPATH/$SITENAME.sql.gz; then
	exit_error "Database backup failed, aborting!"
	fi
fi

# Backup files dir
if [ $FILESBACKUP = "YES" ]; then
status_message "** Performing FilesBackup from \"$WEBROOT/$DRUPALSITEDIR\" **"
	if ! tar czf $BACKUPPATH/$SITENAME.filesbackup.tar.gz -C $WEBROOT/$DRUPALSITEDIR .; then
	exit_error "Files backup failed, aborting!"
	fi
fi


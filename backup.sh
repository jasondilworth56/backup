#!/usr/bin/env bash

# Ensure that all possible binary paths are checked
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#Directory the script is in (for later use)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Provides the 'log' command to simultaneously log to
# STDOUT and the log file with a single command
# NOTE: Use "" rather than \n unless you want a COMPLETELY blank line (no timestamp)
log() {
    echo -e "$(date -u +%Y-%m-%d-%H%M)" "$1" >> "${LOGFILE}"
    if [ "$2" != "noecho" ]; then
        echo -e "$1"
    fi
}


### LOAD IN CONFIG ###

# Prepare "new" settings that might not be in backup.cfg
SCPLIMIT=0

# Default config location
CONFIG="${SCRIPTDIR}"/backup.cfg

if [ "$1" == "--config" ]; then
    # Get config from specified file
    CONFIG="$2"
elif [ $# != 0 ]; then
    # Invalid arguments
    echo "Usage: $0 [--config filename]"
    exit
fi

# Check config file exists
if [ ! -e "${CONFIG}" ]; then
    echo "Couldn't find config file: ${CONFIG}"
    exit
fi

# Load in config
CONFIG=$( realpath "${CONFIG}" )
source "${CONFIG}"

### END OF CONFIG ###

### CHECKS ###

# This section checks for all of the binaries used in the backup
BINARIES=( cat cd command date dirname echo find pwd realpath rm tar )

# Iterate over the list of binaries, and if one isn't found, abort
for BINARY in "${BINARIES[@]}"; do
    if [ ! "$(command -v "$BINARY")" ]; then
        log "$BINARY is not installed. Install it and try again"
        exit
    fi
done

# Check if the backup folders exist and are writeable
if [ ! -w "${LOCALDIR}" ]; then
    log "${LOCALDIR} either doesn't exist or isn't writable"
    log "Either fix or replace the LOCALDIR setting"
    exit
elif [ ! -w "${TEMPDIR}" ]; then
    log "${TEMPDIR} either doesn't exist or isn't writable"
    log "Either fix or replace the TEMPDIR setting"
    exit
fi

BACKUPDATE=$(date -u +%Y-%m-%d-%H%M)
STARTTIME=$(date +%s)
TARFILE="${LOCALDIR}""$(hostname)"-"${BACKUPDATE}".tgz
SQLFILE="${TEMPDIR}mysql_${BACKUPDATE}.sql"

cd "${LOCALDIR}" || exit

### END OF CHECKS ###

### TAR BACKUP ###

log "Starting tar backup dated ${BACKUPDATE}"
# Prepare tar command
TARCMD="-zcf ${TARFILE} ${BACKUP[*]}"

# Check if there are any exclusions
TARCMD="--exclude ${TARFILE} ${TARCMD}":
if [[ "x${EXCLUDE[@]}" != "x" ]]; then
    # Add exclusions to front of command
    for i in "${EXCLUDE[@]}"; do
        TARCMD="--exclude $i ${TARCMD}"
    done
fi

# Run tar
tar ${TARCMD}

BACKUPSIZE=$(du -h "${TARFILE}".enc | cut -f1)
log "Tar backup complete. Filesize: ${BACKUPSIZE}"; log ""

### END OF TAR BACKUP ###

### BACKUP DELETION ##

log "Checking for LOCAL backups to delete..."
bash "${SCRIPTDIR}"/deleteoldbackups.sh --config "${CONFIG}"
log ""

### END OF BACKUP DELETION ###

ENDTIME=$(date +%s)
DURATION=$((ENDTIME - STARTTIME))
log "All done. Backup and transfer completed in ${DURATION} seconds\n"

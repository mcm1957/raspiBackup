#!/bin/bash

# Just some code to get familiar with remote ssh and rsync daemon

source ~/.ssh/rsyncServer.creds
#will define
#SSH_HOST=
#SSH_USER=
#SSH_KEY_FILE=

#DAEMON_HOST=
#DAEMON_MODULE="Test-Backup" # points to /disks/raid1/test
#DAEMON_USER=
#DAEMON_PASSWORD=

readonly TARGET_HOST="TARGET_HOST" # ssh and daemon
readonly TARGET_USER="TARGET_USER" # ssh and daemon
readonly TARGET_KEY="TARGET_KEY" # ssh
readonly TARGET_PASSWORD="TARGET_PASSWORD" # daemon

readonly TARGET_TYPE="TARGET_TYPE"
readonly TARGET_TYPE_DAEMON="TARGET_TYPE_DAEMON"
readonly TARGET_TYPE_SSH="TARGET_TYPE_SSH"
readonly TARGET_TYPE_LOCAL="TARGET_TYPE_LOCAL"

readonly TARGET_DIRECTION_TO="TARGET_DIRECTION_TO"	# from local to remote
readonly TARGET_DIRECTION_FROM="TARGET_DIRECTION_FROM" # from remote to local

declare -A sshTarget
sshTarget[$TARGET_TYPE]="$TARGET_TYPE_SSH"
sshTarget[$TARGET_HOST]="$SSH_HOST"
sshTarget[$TARGET_USER]="$SSH_USER"
sshTarget[$TARGET_KEY]="$SSH_KEY_FILE"

declare -A localTarget
localTarget[$TARGET_TYPE]="$TARGET_TYPE_LOCAL"

declare -A rsyncTarget
rsyncTarget[$TARGET_TYPE]="$TARGET_TYPE_DAEMON"
rsyncTarget[$TARGET_HOST]="$DAEMON_HOST"
rsyncTarget[$TARGET_USER]="$DAEMON_USER"
rsyncTarget[$TARGET_PASSWORD]="$DAEMON_PASSWORD"

RSYNC_OPTIONS="-arAvp --delete"

LOGFILE="./rsyncServer.log"

rm -f $LOGFILE

if (( $# < 1 )); then
	echo "Missing directory to sync"
	exit -1
fi

TARGET_DIR="/disks/raid1/test"
SOURCE_DIR="$1"

function checkrc() {
	if (( $1 != 0 )); then
		echo "Error $1"
		exit 1
	fi
}

# invoke command either local or remote via ssh
function invokeCommand() { # target command

	local rc reply

	local -n target=$1

	echo "-> $1: $2" >> $LOGFILE

	case ${target[$TARGET_TYPE]} in

		$TARGET_TYPE_LOCAL)
			echo "Targethost: $(hostname)" &>> $LOGFILE
			reply="$($2)"
			rc=$?
			echo "<- %rc: $reply" &>> $LOGFILE
			;;

		$TARGET_TYPE_SSH)
			echo "Targethost: ${target[$TARGET_HOST]}" &>> $LOGFILE
			reply="$(ssh "${target[$TARGET_HOST]}" "$2" 2>&1)"
			rc=$?
			echo "<- $rc: $reply" &>> $LOGFILE
			;;

		*) echo "Unknown target ${target[$TARGET_TYPE]}"
			exit -1
			;;

	esac

	return $rc
}

function invokeRsync() { # target direction from to

	local rc reply direction localDir remoteDir command

	local -n target=$1

	shift
	direction="$1"
	localDir="$2"
	remoteDir="$3"

	echo "-> $1: $2 $3 " >> $LOGFILE

	case ${target[$TARGET_TYPE]} in

		$TARGET_TYPE_LOCAL)
			echo "Targethost: $(hostname)" &>> $LOGFILE
			reply="$(rsync $RSYNC_OPTIONS $localDir $remoteDir)"
			rc=$?
			echo "<- $reply" &>> $LOGFILE
			;;

		$TARGET_TYPE_SSH)
			echo "Targethost: ${target[$TARGET_HOST]}" &>> $LOGFILE
			if [[ $direction == $TARGET_DIRECTION_TO ]]; then
				reply="$(rsync $RSYNC_OPTIONS -e "ssh -i ${target[$TARGET_KEY]}" $localDir ${target[$TARGET_USER]}@${target[$TARGET_HOST]}:/$remoteDir)"
			else
				reply="$(rsync $RSYNC_OPTIONS -e "ssh -i ${target[$TARGET_KEY]}" ${target[$TARGET_USER]}@${target[$TARGET_HOST]}:/$remoteDir $localDir)"
			fi
			rc=$?
			echo "$rc: $reply" >> $LOGFILE
			;;

		$TARGET_TYPE_DAEMON)
			set -x
			echo "Targethost: ${target[$TARGET_HOST]}" &>> $LOGFILE
			export RSYNC_PASSWORD="${target[$TARGET_PASSWORD]}"
			if [[ $direction == $TARGET_DIRECTION_TO ]]; then
				reply="$(rsync $RSYNC_OPTIONS $localDir rsync://"${target[$TARGET_USER]}"@${target[$TARGET_HOST]}:/$remoteDir)" # remoteDir is actually the rsync server module
			else
				reply="$(rsync $RSYNC_OPTIONS rsync://"${target[$TARGET_USER]}"@${target[$TARGET_HOST]}:/$remoteDir $localDir)"
			fi
			rc=$?
			echo "$rc; $reply" >> $LOGFILE
			;;

		*) echo "Unknown target ${target[$TARGET_TYPE]}"
			exit -1
			;;
	esac

	return $rc
}

function testSSH() {

	declare t=(sshTarget localTarget)

	for (( target=0; target<2; target++ )); do

		echo -e "\n@@@ ls -la" &>>$LOGFILE
		invokeCommand ${t[$target]} "ls -la ${TARGET_DIR}"
		checkrc $?

	done

	echo "+========================"
	cat $LOGFILE
	echo "-========================"

	rm $LOGFILE

}

function testRsync() {

	declare t=(localTarget sshTarget rsyncTarget)

	for (( target=2; target<3; target++ )); do

		TARGET_DIR_SPEC="$TARGET_DIR"
		(( $target == 2 )) && TARGET_DIR_SPEC="$DAEMON_MODULE"

		invokeRsync ${t[$target]} $TARGET_DIRECTION_TO "$SOURCE_DIR" "$TARGET_DIR_SPEC"
		checkrc $?

	done

	echo "+========================"
	cat $LOGFILE
	echo "-========================"

	rm $LOGFILE
}

testRsync

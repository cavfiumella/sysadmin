#!/bin/bash
#
# Check LXC containers connectivity 
#

SERVICE=snap.lxd.daemon.service # lxd service
WAIT_TIME=60 # containers restart waiting time


# check is instance exists / is valid
exists() {
	if [[ $# -lt 1 ]]; then
		echo Container name is needed! 1>&2
		return 1
	fi

	container="$1"

	lxc exec "$container" -- echo > /dev/null
	return
}


# check container connectivity
is_online() {
	if [[ $# -lt 1 ]]; then
		echo Container name is needed! 1>&2
		return 1
	fi

	container="$1"
	
	lxc exec "$container" -- systemctl is-active network-online.target > /dev/null
	return $?
}


# check connection of multiple containers
healthcheck() {

	containers="$@"

	for container in "$containers"; do
		is_online "$container"
		if [[ $? -ne 0 ]]; then
			return 1
                fi
        done

        return 0
}


# print connectivity status of passed containers
print_status() {
	if [[ $# -eq 0 ]]; then
		return 0
	fi
	
	containers="$@"

	echo Connected containers:

	for container in "$containers"; do
		echo -n "  $container: "

		is_connected "$container"
		if [[ $? -eq 0 ]]; then
			echo yes
		else
			echo no
		fi
	done

	return 0
}


main() {
	if [[ $# -lt 1 ]]; then
        	echo At least one container name is needed! 1>&2
	        return 1
	fi

	containers="$@"

	# check if instances exist
	for container in "$containers"; do
		exists "$container"
		if [[ $? -ne 0 ]]; then
			return 1
		fi
	done

	# restart lxd service
	healthcheck "$containers"
	if [[ $? -ne 0 ]]; then
		echo Healthcheck failed!

		echo Restarting LXD daemon...
        	systemctl restart "$SERVICE"

		echo Waiting $WAIT_TIME...
        	sleep "$WAIT_TIME"
	else
		echo All containers are connected.
        	return 0
	fi

	# healthcheck after restart
	healthcheck "$containers"
	if [[ $? -ne 0 ]]; then
        	echo Containers recovery failed! 1>&2
		print_status 1>&2 
		return 1
	fi

	echo Recovery successful.
	return 0
}


main "$@"
exit $?

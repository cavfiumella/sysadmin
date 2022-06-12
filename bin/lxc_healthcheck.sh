#!/bin/bash

print_help() {
	echo 'Check LXC container connectivity.'
	echo
	echo 'Usage:'
	echo "  `basename $BASH_SOURCE` [-h|--help] <instance>"
	echo
	echo 'Args:'
	echo '  instance      instance to check'
	echo
	echo 'Options:'
	echo '  -h --help     print usage and help'
	echo '  -S --service  LXD daemon service (default: snap.lxd.daemon.service)'
	echo '  -T --timeout  timeout in seconds for daemon restart (default: 60)'

	return 0
}




# check is instance exists / is valid
exists() {
	if [[ $# -lt 1 ]]; then
		echo Container name is needed! 1>&2
		return 1
	fi

	container="$1"

	lxc exec "$container" -- echo > /dev/null
	return $?
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


main() {

	service=snap.lxd.daemon.service
	timeout=60
	args=()

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				print_help
				return 0
				;;
			-S|--service)
				service="$2"
				shift
				shift
				;;
			-T|--timeout)
				timeout="$2"
				shift
				shift
				;;
			-*|--*)
				echo Unknonw option $1 1>&2
				echo
				print_help
				return 1
				;;
			*)
				args+=("$1")
				shift
				;;
		esac
	done

	if [[ ${#args[@]} -lt 1 ]]; then
        	echo Container name is needed! 1>&2
	        return 1
	fi

	container="${args[0]}"

	exists "$container"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	is_online "$container"
	if [[ $? -ne 0 ]]; then
		echo $container is not connected!

		echo Restarting LXD daemon...
        	systemctl restart "$service"

		echo Waiting $timeout...
        	sleep "$timeout"
	else
		echo All containers are connected.
        	return 0
	fi

	# healthcheck after restart
	is_online "$container"
	if [[ $? -ne 0 ]]; then
        	echo Connectivity recovery for instance $container failed! 1>&2
		return 1
	fi

	echo Recovery successful.
	return 0
}


main "$@"
exit $?

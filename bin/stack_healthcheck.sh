#!/bin/bash

print_help() {
	echo 'Check Docker stacks services running state.'
	echo
	echo 'Usage:'
	echo "  `basename $BASH_SOURCE` [-h|--help] [-D|--dry-run] <stack>"
	echo
	echo 'Args:'
	echo '  stack          Docker stack to check'
	echo
	echo 'Options:'
	echo '  -h --help      print usage and help'

	return 0
}


# check stack exists
exists() {
	if [[ $# -lt 1 ]]; then
		echo Stack name is needed! 1>&2
		return 1
	fi

	stack="$1"

	header="`docker stack ls | head -n1`"
	test -n "`docker stack ls | grep -v "$header" | grep "$stack "`"
	return $?
}


# check stack services are running
is_running() {
	if [[ $# -lt 1 ]]; then
		echo Stack name is needed! 1>&2
		return 1
	fi

	stack="$1"
	
	test -z "`docker stack services "$stack" | grep '0/'`"
	return $?
}


main() {

	args=()

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				print_help
				return 0
				;;
			-*|--*)
				echo Unknown option $1. 1>&2
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
		echo Stack name is needed!
		return 1
	fi

	stack="${args[0]}"

	exists "$stack"
	if [[ $? -ne 0 ]]; then
		echo Stack $stack does not exist! 1>&2
		return 1
	fi

	is_running "$stack"
	if [[ $? -ne 0 ]]; then
		echo Some service is not running! 1>&2
		echo Stack $stack services: 1>&2
		docker stack services "$stack" 1>&2

		return 1
	fi
	
	echo All services are running.
	return 0
}


main "$@"
exit $?

#!/bin/bash
#
# Check docker stacks' services are all running
#


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

	stacks="$@"

	for stack in "$stacks"; do
		exists "$stack"
		if [[ $? -ne 0 ]]; then
			echo Stack $stack not found! 1>&2
			return 1
		fi
	done

	for stack in "$stacks"; do
		is_running "$stack"
		if [[ $? -ne 0 ]]; then
			echo Stack $stack is not running! 1>&2
			echo Stack services: 1>&2
			docker stack services "$stack" 1>&2

			return 1
		fi
	done
	
	echo All stacks are running.
	return 0
}


main "$@"
exit $?

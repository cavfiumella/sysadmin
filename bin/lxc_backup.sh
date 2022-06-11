#!/bin/bash
#
# Backup LXC container locally
#

main() {
	if [[ $# -lt 1 ]]; then
		echo Container name is needed! 1>&2
		return 1
	fi
	
	container="$1"
	backup="${2:-$container.tar.gz}"

	lxc stop "$container" \
		&& lxc export "$container" "$backup" --instance-only \
		&& lxc start "$container"

	return $?
}


main "$@"
exit $?

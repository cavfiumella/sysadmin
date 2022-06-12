#!/bin/bash

print_help() {
	echo 'Backup LXC container locally.'
	echo
	echo 'Usage:'
	echo "  `basename $BASH_SOURCE` [-h|--help] <instance> [backup]"
	echo
	echo 'Args:'
	echo '  instance      instance to backup'
	echo '  backup        backup file (default: instance_name.tar.gz)'
	echo
	echo 'Options:'
	echo '  -h --help     print usage and help'
	echo '  -D --dry-run  print commands without executing them'

	return 0
}


main() {

	dry=false
	args=()

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				print_help
				return 0
				;;
			-D|--dry-run)
				dry=true
				shift
				;;
			-*|--*)
				echo Unknown option $1 1>&2
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

	container=''
	backup=''

	if [[ ${#args[@]} -lt 1 ]]; then
		echo Instance name is needed! 1>&2
		return 1
	elif [[ ${#args[@]} -lt 2 ]]; then
		container="${args[0]}"
		backup="${args[0]}.tar.gz"
	else
		container="${args[0]}"
		backup="${args[1]}"
	fi

	cmd="lxc stop '$container'"

	if [[ $dry = true ]]; then
		echo $cmd
	else
		eval $cmd
	fi

	if [[ $? -ne 0 ]]; then
		echo Error during instance stop. 1>&2
		return 1
	fi

	cmd="lxc export '$container' '$backup' --instance-only"

	if [[ $dry = true ]]; then
		echo $cmd
	else
		eval $cmd
	fi

	if [[ $? -ne 0 ]]; then
		echo Error during instance backup. 1>&2
		return 1
	fi

	cmd="lxc start '$container'"
	
	if [[ $dry = true ]]; then
		echo $cmd
	else
		eval $cmd
	fi

	if [[ $? -ne 0 ]]; then
		echo Error during instance restart. 1>&2
		return 1
	fi

	return 0
}


main "$@"
exit $?

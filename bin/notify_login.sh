#!/bin/bash

set -e


print_help() {
	echo 'Notify logins by email.'
	echo 'To use this script for ssh logins add the following line to /etc/pam.d/sshd:'
	echo '  session optional pam_exec.so /path/to/notify_login.sh from@email.com to@email.com'
	echo
	echo 'Usage:'
	echo "  `basename $BASH_SOURCE` [-h|--help] [-D|--dry-run] [from] <to>"
	echo
	echo 'Args:'
	echo '  from          sender address'
	echo '  to            recipient address'
	echo
	echo 'Options:'
	echo '  -h --help     print usage and help'
	echo '  -D --dry-run  print email without sending it'

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

	from=''
	to=''

	if [[ ${#args[@]} -lt 1 ]]; then
		echo Recipient address is needed! 1>&2
		return 1
	elif [[ ${#args[@]} -lt 2 ]]; then
		to="${args[0]}"
	else
		from="${args[0]}"
		to="${args[1]}"
	fi

	if [ "$PAM_TYPE" != "close_session" ]; then
		host="`hostname`"
   		subject="SSH Login: $PAM_USER from $PAM_RHOST on $host"
	    	message=''

		if [[ -n $from ]]; then
			message="${message}From: $from \n"
		fi

		message="${message}To: $to \n"
		message="${message}Subject: $subject \n"
		message="${message}\n`env`\n"

		if [[ $dry = true ]]; then
			echo -e "$message"
		else
			echo -e "$message" | sendmail -t
		fi
	fi

	return 0
}


main "$@"
exit $?

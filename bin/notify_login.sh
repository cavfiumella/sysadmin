#!/bin/bash
#
# Notify logins by email
# Add the following line to your /etc/pam.d/sshd:
#
#   session optional pam_exec.so seteuid /path/to/script.sh from@email.com to@email.com
#

main() {
	if [[ $# -lt 2 ]]; then
		echo Sender and recipient emails are needed! 1>&2
	fi

	from="$1"
	to="$2"

	if [ "$PAM_TYPE" != "close_session" ]; then
		host="`hostname`"
   		subject="SSH Login: $PAM_USER from $PAM_RHOST on $host"
	    	message="`env`"

		echo -e "From: $from \nTo: $to \nSubject: $subject \n\n$message" | sendmail -t
	fi

	return 0
}


main "$@"
exit $?

#!/bin/bash

set -e

DEBIAN_FRONTEND=noninteractive


print_help() {
  echo 'Configure hostname, timezone, ssh, fail2ban, firewalld and multi-factor authentication.'
  echo
  echo 'Usage:  ./configure.sh'

  echo 'Options:'
  echo '  -h | --help    print usage and help'
  echo

  return 0
}


add_interfaces() {
  if [ $# -lt 2 ]; then
    echo 'Zone name and one interface at least are needed!' 1>&2
    return 1
  fi

  zone="$1"
  shift
  interfaces="$@"

  for interface in "$interfaces"; do
    firewall-cmd --permanent --zone "$zone" --add-interface "$interface" > /dev/null
  done
 
  return 0
}


main() {
  while [ $# -ne 0 ]; do
    case "$1" in
      -h | --help)
        print_help
        return 0
        ;;
      *)
        shift
        ;;
    esac
  done

  if [ `id -u` -ne 0 ]; then
    echo 'You must be root!' 1>&2
    return 1
  fi

  echo -n "Hostname [localhost]: "
  read host
  hostnamectl hostname "$host"
  
  echo -n "Timezone [UTC]: "
  read tz
  if [ -z "$tz" ]; then tz=UTC; fi
  timedatectl set-ntp true
  timedatectl set-timezone "$tz"
  
  echo -e '\nUpdating repositories...\n'
  
  apt update -y > /dev/null

  echo -e '\nInstalling packages...\n'

  apt install -y openssh-server \
    fail2ban \
    firewalld \
    libpam-google-authenticator

  echo -e '\nConfiguring ssh...\n'
  
  echo 'PermitRootLogin no' \
    > /etc/ssh/sshd_config.d/login.conf
  echo 'PasswordAuthentication no' \
    >> /etc/ssh/sshd_config.d/login.conf

  systemctl enable --now ssh

  echo -e '\nConfiguring fail2ban...\n'

  systemctl enable --now fail2ban

  echo -e '\nConfiguring firewalld...\n'

  systemctl enable --now firewalld

  echo -en '\nWhich firewall zones should allow ssh? '
  read -a zones

  for zone in "$zones"; do
    firewall-cmd --add-service ssh --permanent --zone "$zone" > /dev/null
  done
 
  for zone in "$zones"; do
    echo -n "Which interfaces should be in firewall zone $zone? "
    read -a interfaces
    add_interfaces "$zone" "$interfaces"
  done

  firewall-cmd --reload > /dev/null
  if [ $? -ne 0 ]; then return $?; fi

  echo -n 'Do you want to configure MFA for ssh? [Yn] '
  read answer

  if [ "$answer" != 'y' ] && [ "$answer" != 'Y' ] && [ -n "$answer" ]; then
    return 0
  fi
 
  echo -n 'Which user should have MFA configured? '
  read user
  sudo -u "$user" google-authenticator
  if [ $? -ne 0 ]; then return $?; fi

  echo 'KbdInteractiveAuthentication yes' \
    > /etc/ssh/sshd_config.d/mfa.conf
  echo 'AuthenticationMethods publickey,keyboard-interactive' \
    >> /etc/ssh/sshd_config.d/mfa.conf

  echo 'auth required pam_google_authenticator.so' \
    >> /etc/pam.d/sshd

  systemctl restart ssh

  echo -e '\nConfiguration completed.'
  return 0
}

main "$@"
exit $?

#!/bin/bash


print_help() {
  echo 'Check if a service is running and restart it if it is not active but it is enabled.'
  echo
  echo "Usage:  $SOURCE [-h|--help] <service>"
  echo
  echo 'Args:'
  echo '  service        systemd unit to check'
  echo
  echo 'Options:'
  echo '  -h | --help    print this message'

  return 0
}


main() {

  args=()

  while [ $# -ne 0 ]; do
    case "$1" in
      -h | --help)
        print_help
        return 0
        ;;
      -* | --*)
        echo 'Unknown option!' 1>&2
        print_help
        return 1
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [ ${#args[@]} -lt 1 ]; then
    echo 'You must specify a service unit!' 1>&2
    return 1
  fi

  service=${args[0]}

  systemctl is-enabled "$service" >/dev/null

  if [ $? -ne 0 ]; then
    echo "$service is not enabled." 1>&2
    return 0
  fi

  systemctl is-active "$service" >/dev/null

  if [ $? -eq 0 ]; then
    return 0
  fi

  echo "$service is not running!"
  echo "Restarting $service..."
  
  systemctl restart "$service"
  sleep 5

  systemctl is-active "$service" >/dev/null

  if [ $? -ne 0 ]; then
    echo "Unable to restart $service!" 1>&2
    return 1
  fi

  return 0
}


main "$@"
exit $?

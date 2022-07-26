#!/bin/bash

print_help() {
  echo 'Ping host to check is alive.'
  echo
  echo "Usage:  $SOURCE [options] <ping target>"
  echo
  echo 'Arguments:'
  echo '  target         ping target'
  echo
  echo 'Options:'
  echo '  -h | --help    print usage and help'

  return 0
}


main() {
  args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        print_help
        return 0
        ;;
      -* | --*)
        echo "Unrecognized option $1!" 1>&2
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
    echo 'Ping target is mandatory!' 1>&2
    return 1
  fi

  host="${args[0]}"

  ping -c1 "$host" &>/dev/null

  if [ $? -ne 0 ]; then
    echo "$host is down!" 1>&2
    return 1
  fi

  return 0
}


main "$@"
exit $?

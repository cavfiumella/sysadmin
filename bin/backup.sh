#!/bin/bash

set -e


print_help() {
  echo 'Duplicity backup.'
  echo
  echo 'Usage: '
  echo "  `basename $BASH_SOURCE` [-h|--help] [-k|--key KEY] [-F|--full-if-older-than TIME] [-R|--remove-older-than TIME] [-E|--exclude PATH] [-D|--dry-run] [-q|--quiet] <src> <dst>"
  echo
  echo 'Args:'
  echo '  src                                path to backup'
  echo '  dst                                target collection for backup'
  echo
  echo 'Options:'
  echo '  -h --help                          print usage and help'
  echo '  -k --key KEY                       GPG key ID for encryption'
  echo '  -F --full-if-older-than TIME       execute a full backup only if the last one is older than TIME (time formats given by duplicity)'
  echo '  -R --remove-older-than TIME        remove backups older than TIME (time formats given by duplicity)'
  echo '  -C                                 cleanup at the end'
  echo '  -E --exclude                       exclude a path from backup (can be specified multiple times)'
  echo '  --include-filelist                 look at duplicity man'
  echo '  -D --dry-run                       print commands without executing'
  echo '  -q --quiet                         do not print progress and statistics at the end'

  return 0
}


main() {

  key=''
  full=''
  remove=''
  cleanup=''
  exclude=()
  include_filelist=''
  dry=false
  quiet=false
  args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        print_help
        return 0
        ;;
      -k|--key)
        key="$2"
        shift
        shift
        ;;
      -F|--full-if-older-than)
        full="$2"
        shift
        shift
        ;;
      -R|--remove-older-than)
        remove="$2"
        shift
        shift
        ;;
      -C|--cleanup)
        cleanup=true
        shift
        ;;
      -E|--exclude)
        exclude+=("$2")
        shift
        shift
        ;;
      --include-filelist)
        include_filelist="$2"
        shift
        shift
        ;;
      -D|--dry-run)
        dry=true
        shift
        ;;
      -q|--quiet)
        quiet=true
        shift
        ;;
      -*|--*)
        echo Uknown option $1 1>&2
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

  if [[ ${#args[@]} -lt 2 ]]; then
    echo Source and target are needed! 1>&2
    return 1
  fi

  src="${args[0]}"
  dst="${args[1]}"

  # backup
  cmd='duplicity incr'
  cmd="$cmd --asynchronous-upload --s3-use-multiprocessing"

  if [[ -n $key ]]; then
    cmd="$cmd --encrypt-key '$key'"
  else
    cmd="$cmd --no-encrypt"
  fi

  if [[ -n $full ]]; then
    cmd="$cmd --full-if-older-than '$full'"
  fi

  for path in "${exclude[@]}"; do
    if [ -n "$path" ]; then
      cmd="$cmd --exclude '$path'"
    fi
  done

  if [[ -n $include_filelist ]]; then
    cmd="$cmd --include-filelist '$include_filelist'"
  fi

  if [[ $quiet = true ]]; then
    cmd="$cmd --no-print-statistics"
  else
    cmd="$cmd --progress"
  fi

  cmd="$cmd '$src' '$dst'"

  if [[ $dry = true ]]; then
    echo $cmd
  else
    eval $cmd
  fi

  # remove older backups
  if [[ -z $remove ]]; then
    return 0
  fi

  cmd="duplicity remove-older-than '$remove' --force '$dst'"

  if [[ $dry = true ]]; then
    echo $cmd
  else
    eval $cmd
  fi

  # cleanup
  if [[ -z $cleanup ]]; then
    return 0
  fi

  cmd="duplicity cleanup --force '$dst'"

  if [[ $dry = true ]]; then
    echo $cmd
  else
    eval $cmd
  fi

  return 0
}


main "$@"
exit $?

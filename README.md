# Sysadmin scripts

This is a personal collection of scripts for system administration.

Each script has a `-h|--help` option that prints description, usage, positional
arguments and options help.

## Scripts
- `backup.sh`: backup files using `duplicity`, this is a wrapper that uses less options;
- `lxc_backup.sh`: local backup of a LXC instance;
- `lxc_healthcheck.sh`: LXC instance connectivity check;
- `notify_login.sh`: logins email notifier, useful for `sshd`;
- `stack_healthcheck.sh`: Docker stack's services running state check;
- `zone_guard.py`: logger for devices connected on interfaces and sources of a Firewalld zone.

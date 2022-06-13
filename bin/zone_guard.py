#!/bin/env python3

from argparse import ArgumentParser
import shlex
from subprocess import Popen, PIPE, SubprocessError
import sys
from typing import Optional
from warnings import warn
from time import sleep
import logging
import json
import signal


_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
_JSON_INDENT = 4
_LOG_LEVEL = logging.INFO
_LOG_FORMAT = '[{asctime}] {levelname} - {message}'

logging.basicConfig(format = _LOG_FORMAT, datefmt = _DATE_FORMAT, style='{', level = _LOG_LEVEL)
logging.captureWarnings(True)

def signal_handler(sig, stack):
    '''SIGINT handler for a smooth exit.'''
    
    logging.info('SIGINT received. Exiting...')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)


def execute(cmd: str, /) -> str:
    '''Execute a cmd.

    Parameters:
    - cmd.

    Return:
    stdout
    '''
    
    logging.debug(f'Executing `{cmd}`.')

    cmd = str(cmd)

    p = Popen(shlex.split(cmd), stdout=PIPE, stderr=PIPE)
    out, err = p.communicate()

    out = out.decode().strip('\n')
    err = err.decode().strip('\n')

    logging.debug(f'Subprocess: stdout: "{out}", stderr: "{err}".')

    if p.returncode != 0:
        raise SubprocessError(err)

    return out


class host:
    '''Host.'''

    _hostname: Optional[str] = None
    _inet: Optional[str] = None


    def __init__(self, hostname: str, inet: str, /):
        
        logging.debug(f'Host init: hostname = "{hostname}", inet = "{inet}".')

        hostname = str(hostname)
        inet = str(inet)
        
        self._hostname = hostname
        self._inet = inet


    def to_dict(self) -> dict:
        '''Reurn {'Hostname': hostname, 'IP address': inet}.'''

        df = {
            'Hostname': self._hostname,
            'IP address': self._inet
        }

        logging.debug(f"Host to dict: {json.dumps(df, indent = _JSON_INDENT)}.")

        return df


class _network:
    '''Base class for firewalld zone sources and interfaces.'''

    _inet: Optional[str] = None
    _hosts: list = []


    def __init__(self, inet: str, /):
       
        logging.debug(f'Network init: inet = "{inet}"')

        inet = str(inet)        
        
        self._inet = inet


    def scan_hosts(self, /) -> tuple:
        '''Scan inet (it could be a subnet or one IP address) with nmap.

        Return:
        (new hosts, lost hosts) with new and lost hosts given as [host1, ...].
        '''

        logging.debug(f'Network "{self._inet}" scan hosts.')

        inet = self._inet

        out = execute(f'nmap -sn "{inet}"')
        hosts = []

        for line in out.split('\n'):
            if 'scan report' in line:
                hostname = line.split()[-2]
                host_inet = line.split()[-1].strip('()')

                if hostname == 'for':
                    hostname = None

                hosts += [ host(hostname, host_inet) ]

        logging.debug(f'Hosts: {json.dumps([h.to_dict() for h in hosts], indent = _JSON_INDENT)}')
        
        lost_hosts = []
        new_hosts = []
       
        df_old = [h.to_dict() for h in self._hosts]
        df_new = [h.to_dict() for h in hosts]

        for i, h in enumerate(df_old):
            if h not in df_new:
                lost_hosts += [self._hosts[i]]

        for i, h in enumerate(df_new):
            if h not in df_old:
                new_hosts += [hosts[i]]

        self._hosts = hosts

        logging.debug(f'Lost hosts: {json.dumps([h.to_dict() for h in lost_hosts], indent = _JSON_INDENT)}')
        logging.debug(f'New hosts: {json.dumps([h.to_dict() for h in new_hosts], indent = _JSON_INDENT)}')

        return lost_hosts, new_hosts


class interface(_network):
    '''Network interface.'''
    
    _dev: Optional[str] = None


    def __init__(self, dev: str, /):
        
        logging.debug(f'Interface init: dev = "{dev}".')

        dev = str(dev)
        
        self._dev = dev
        _network.__init__(self, self._get_inet())


    def _get_inet(self) -> Optional[str]:
        '''Get interface IP address.'''

        dev = self._dev
        inet = None

        # if interface does not exist just return None
        try:
            out = execute(f'ip addr show dev "{dev}"')
        except SubprocessError:
            pass
        else:
            for line in out.split('\n'):
                if 'inet ' in line:
                    inet = line.split()[1]
                    break

        logging.debug(f'Interface "{dev}" has inet "{inet}".')
        
        return inet


    def update(self):
        '''Update interface inet.'''

        logging.debug(f'Update interface "{self._dev}" inet.')
        
        self._inet = self._get_inet()


    def scan_hosts(self) -> tuple:
        '''Call self.update() and return _network.scan_hosts(self).'''

        self.update()
        return _network.scan_hosts(self)


    def to_dict(self) -> dict:
        '''Return {'Device': dev, 'IP address': inet, 'Hosts': [host1, ...]}.'''

        df = {
            'Device': self._dev,
            'IP address': self._inet,
            'Hosts': [h.to_dict() for h in self._hosts]
        }

        logging.debug(f'Interface to dict: {json.dumps(df, indent = _JSON_INDENT)}')

        return df


class source(_network):
    '''Network source.'''
   
    def __init__(self, inet: str, /):
        
        logging.debug(f'Source init: inet = "{inet}"')

        inet = str(inet)
        
        _network.__init__(self, inet)


    def to_dict(self) -> dict:
        '''Return {'IP address': inet, 'Hosts': [host1, ...]}.'''

        df = {
            'IP address': self._inet,
            'Hosts': [h.to_dict() for h in self._hosts]
        }

        logging.debug(f'Source to dict: {json.dumps(df, indent = _JSON_INDENT)}')

        return df


class zone:
    '''Firewalld zone.'''

    _name: Optional[str] = None
    _interfaces: list = []
    _sources: list = []


    def __init__(self, name: str, /):
        
        logging.debug(f'Zone init: name = "{name}".')

        name = str(name)

        self._name = name
        self.update()


    def _get_values(self, field: str, /) -> list:
        '''Get values of a certain field of a firewalld zone (e.g. interfaces, sources, ...).

        Parameters:
        - field.

        Return:
        field values.
        '''

        zone = self._name
        field = str(field)

        for line in execute(f'firewall-cmd --info-zone "{zone}"').split('\n'):
            if field in line:
                values = line.split(':')[-1].split()
                logging.debug(f'Zone "{zone}" {field}: {values}')
                
                return values

        raise ValueError(f'{field} is not a firewalld zone field')


    def update(self):
        '''Update zone interfaces and sources.'''
        
        logging.debug(f'Update zone "{self._name}".')

        self._interfaces = [interface(dev) for dev in self._get_values('interfaces')]
        self._sources = [source(inet) for inet in self._get_values('sources')]


    def scan_hosts(self) -> list:
        '''Scan hosts on zone's interfaces and sources.

        Return:
        list of interfaces and sources as
        [ {'Device': dev, 'IP address': inet, New hosts: [host1.to_dict(), ...], 'Lost hosts': [host1.to_dict(), ...]} , ... ].
        '''

        logging.debug(f'Zone "{self._name}" scan hosts.')

        self.update()
        diff = []

        for x in self._interfaces + self._sources:
            lost_hosts, new_hosts = x.scan_hosts()
            
            df = x.to_dict()
            df.pop('Hosts')
            df['Lost hosts'] = [h.to_dict() for h in lost_hosts]
            df['New hosts'] = [h.to_dict() for h in new_hosts]

            diff += [df]

        logging.debug(f'Zone hosts diff: {json.dumps(diff, indent=_JSON_INDENT)}')

        return diff


    def to_dict(self) -> dict:
        '''Return {'Name': name, 'Interfaces': [interface1.to_dict(), ...], 'Sources': [source1.to_dict(), ...]}'''

        df = {
            'Name': self._name,
            'Interfaces': [I.to_dict() for I in self._interfaces],
            'Sources': [S.to_dict() for S in self._sources]
        }

        logging.debug(f'Zone to dict: {json.dumps(df, indent = _JSON_INDENT)}')

        return df


def main(zones: list, timeout: int = 10) -> int:
    '''Monitor and log new connections and disconnections of hosts on interfaces and subnets sources of the given firewalld zones.

    Parameters:
    - zones;
    - timeout: timeout between successive networks scansions.

    Return:
    exit code'''
   
    logging.debug(f'Main args: zones = {zones}, timeout = {timeout}.')

    if type(zones) != list:
        raise TypeError(f'zones must be a list: {zones}')

    if timeout != int(timeout):
        warn(f'timeout should be integer, using timeout = {int(timeout)}')

    timeout = int(timeout)
    logging.debug(f'Timeout: {timeout}')

    zones = [zone(name) for name in zones]

    while True:
        
        for z in zones:
            
            logging.debug('Scanning networks...')
            df = z.scan_hosts()
           
            if len(df) == 0:
                logging.debug('No changes from previous scan.')
                continue

            for x in df:
                net = x['IP address']
                if 'Device' in x: net += ' (' + x["Device"] + ')'

                for h in x['New hosts']:
                    logging.info(f'NEW  HOST {h["Hostname"]} ({h["IP address"]}) in {net}.')

                for h in x['Lost hosts']:
                    logging.info(f'LOST HOST {h["Hostname"]} ({h["IP address"]}) in {net}.')

        logging.debug(f'Sleep {timeout} seconds.')
        sleep(timeout)


if __name__ == '__main__':
    
    if execute('whoami') != 'root':
        print('Who are you? You are not root!', file=sys.stderr)
        sys.exit(1)

    zones = execute('firewall-cmd --get-zones').split()
    
    parser = ArgumentParser(description='Monitor device connected to interfaces and sources of a Firewalld zone.')
    parser.add_argument('-t', '--timeout', default=10, type=int, help='timeout in seconds between successive networks scansions (default: 10)')
    parser.add_argument('-D', '--debug', action='store_true', help='debug mode')
    parser.add_argument(
        'zones', metavar='zone', action='append', choices=zones,
        help='Firewalld zones to scan (multiple zones can be given)'
    )
    
    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    logging.debug(f'Available zones: {zones}.')
    logging.debug(f'Args: {args}')

    try:
        sys.exit(main(args.zones, args.timeout))
    except SubprocessError as ex:
        print(ex.args[0], file=sys.stderr)
        sys.exit(1)

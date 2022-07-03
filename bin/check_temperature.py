#!/bin/env python3

import logging
from argparse import ArgumentParser
from subprocess import Popen, DEVNULL, PIPE, SubprocessError
import json
import sys


def main(warn_thresh: float = 1.0) -> int:
  '''Check devices temperatures and return exit code.'''

  warn_thresh = float(warn_thresh)
  logging.debug(f'Main args: warn_thresh = {warn_thresh}.')

  logging.debug('Opening subprocess to read sensors temperatures.')
  p = Popen(['sensors', '-jA'], stdout=PIPE, stderr=PIPE)
  out, err = tuple(map(lambda s: s.decode(), p.communicate()))

  logging.debug(f'returncode: {p.returncode}')
  logging.debug(f'stdout: {out}')
  logging.debug(f'stderr: {err}')

  if p.returncode != 0:
    raise SubprocessError(err)

  sensors: dict = json.loads(out)

  for sensor in sensors.keys():
    logging.debug(f'Checking sensor {sensor}.')

    temperatures = list(sensors[sensor].keys())
    logging.debug(f'Sensor temperatures: {temperatures}.')

    for temperature in temperatures:
      logging.debug(f'Checking temperature {temperature}.')

      t = None
      t_crit = None

      values: dict = sensors[sensor][temperature]
      logging.debug(f'Temperature values: {values}.')

      for label, value in values.items():
        ex = RuntimeError('multiple values found for one temperature')

        if label == f'{temperature}_input':
          logging.debug(f'Inp. temp. found: {value} (prev. {t}).')
          if t != None: raise ex
          t: float = value
        elif label == f'{temperature}_crit':
          logging.debug(f'Crit. temp. found: {value} (prev. {t_crit}).')
          if t_crit != None: raise ex
          t_crit: float = value

      if t == None or t_crit == None:
        print(f'Unable to check temp. of sensor {sensor}!', file=sys.stderr)
        continue

      if t >= t_crit:
        print(
          f'Critical temperature for sensor {sensor}! {t:.0f} °C '
          f'(crit. {t_crit:.0f} °C)',
          file = sys.stderr
        )
      elif t >= warn_thresh * t_crit:
        print(
          f'Temperature above warning level for sensor {sensor}. {t:.0f} °C '
          f'(crit. {t_crit:.0f} °C, warn. {warn_thresh:%})',
          file = sys.stderr
        )

  return 0


if __name__ == '__main__':
  parser = ArgumentParser(
    description='Check devices temperatures using `lm-sensors`. '
      'When a temperature exceeds the critical level or the warning level set '
      'a message is printed on stderr.'
  )
  parser.add_argument('-D', '--debug', action='store_true', default=False)
  parser.add_argument(
    '-w', '--warning', default=1, type=float,
    help='warning level (e.g. 0.5 to warn when temperature is bigger than '
      '`0.5 * critical level`)'
  )

  args = parser.parse_args()

  if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

  logging.debug(f'CLI args: {args}')

  sys.exit(main(args.warning))

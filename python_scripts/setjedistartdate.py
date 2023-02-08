import numpy as np
import os, sys
import getopt

from dateutil.rrule import *
from dateutil.parser import *
from datetime import *
from datetime import timedelta

#=========================================================================
def advancedate(year, month, day, hour, intv):
  st = datetime(year, month, day, hour, 0, 0)
  dt = timedelta(hours=intv)
  ct = st - dt

  ts = ct.strftime("%Y-%m-%dT%H:00:00Z")

 #print('st = ', st)
 #print('dt = ', dt)
 #print('ct = ', ct)
 #print('ts = ', ts)

  return ts

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  output = 0

  year = 2020
  month = 1
  day = 2
  hour = 0
  intv = 6

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'output=', 'year=', 'month=',
                                                'day=', 'hour=', 'intv='])
  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--year'):
      year = int(a)
    elif o in ('--month'):
      month = int(a)
    elif o in ('--day'):
      day = int(a)
    elif o in ('--hour'):
      hour = int(a)
    elif o in ('--intv'):
      intv = int(a)
    else:
      assert False, 'unhandled option'

  tstr = advancedate(year, month, day, hour, intv)
  print(tstr)


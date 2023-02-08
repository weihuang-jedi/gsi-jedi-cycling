import numpy as np
import os, sys
import getopt

from dateutil.rrule import *
from dateutil.parser import *
from datetime import *
from datetime import timedelta

from pygw.template import Template
from pygw.yaml_file import YAMLFile

#=========================================================================
class GenerateConfig():
  def __init__(self, debug=0, template='config.template',
               year=2020, month=1, day=1, hour=0):
    self.debug = debug
    self.yaml_in = template
    self.yaml_out = 'config.yaml'
    self.year = year
    self.month = month
    self.day = day
    self.hour = hour
    self.st = datetime(self.year, self.month, self.day, self.hour, 0, 0)
    self.ymdh = '%d%2.2d%2.2d%2.2d' %(self.year, self.month, self.day, self.hour)
 
  def advancedate(self, intval):
    dt = timedelta(hours=intval)
    ct = self.st + dt

    ts = ct.strftime("%Y-%m-%dT%H:00:00Z")

   #print('st = ', st)
   #print('dt = ', dt)
   #print('ct = ', ct)
   #print('ts = ', ts)

    return ts

  def genYAML(self):
    yaml_file = YAMLFile(path=self.yaml_in)
    print('yaml_file = ', yaml_file)
    yaml_file['executable options']['ATM_WINDOW_BEGIN'] = self.advancedate(-3)
    yaml_file['executable options']['BKG_ISOTIME'] = self.advancedate(0)
    yaml_file['executable options']['YYYYMMDDHH'] = self.ymdh
    yaml_file.save(self.yaml_out)

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  template = 'config.template'
  year = 2020
  month = 1
  day = 2
  hour = 0
  intv = 6

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'template=', 'year=', 'month=',
                                                'day=', 'hour=', 'intv='])
  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--template'):
      template = a
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

 #-------------------------------------------------------------------------------
  gc = GenerateConfig(debug=debug, template=template,
                      year=year, month=month, day=day, hour=hour)
  gc.genYAML()
  tstr = gc.advancedate(intv)
  print(tstr)


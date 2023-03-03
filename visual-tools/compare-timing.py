import getopt
import os, sys
import subprocess
import time
import datetime

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from dateutil.rrule import *
from dateutil.parser import *
from datetime import *
from datetime import timedelta

import tkinter
import matplotlib
matplotlib.use('TkAgg')
#------------------------------------------------------------------------------------
def advancedate(ints, intv):
  year = int(ints[0:4])
  month = int(ints[4:6])
  day = int(ints[6:8])
  hour = int(ints[8:10])

  st = datetime(year, month, day, hour, 0, 0)
  dt = timedelta(hours=intv)
  ct = st + dt

 #ts = ct.strftime("%Y-%m-%dT%H:00:00Z")
  ts = ct.strftime("%Y%m%d%H")

 #print('st = ', st)
 #print('dt = ', dt)
 #print('ct = ', ct)
 #print('ts = ', ts)

  return ts

#------------------------------------------------------------------------------------
""" Profiler """
class Profiler:
  """ Constructor """
  def __init__(self, debug=0, firstdir=None, seconddir=None, output=0, linear=0,
               casename='JEDI', sym1='sym1', sym2='sym2'):
    """ Initialize class attributes """
    self.debug = debug
    self.firstdir = firstdir
    self.seconddir = seconddir
    self.sym1 = sym1
    self.sym2 = sym2
    self.output = output
    self.linear = linear
    self.casename = casename

    if(not os.path.exists(casename)):
     #mode
     #mode = 0o722
     #os.makedirs(casename, mode)
      os.makedirs(casename)

    self.shortest_time = 0.1

    self.colorlist = ['red', 'green', 'cyan', 'blue', 'magenta',
                      'firebrick', 'lime']
    self.linestyle = ['solid', 'solid', 'solid', 'solid', 'solid',
                      'dashed', 'dashed']
    self.function_list = ['sum(oops::GetValues)',
                          'sum(oops::ObsError)',
                          'sum(oops::ObsFilter)',
                          'sum(oops::ObsSpace)',
                          'sum(oops::ObsVector)',
                          'sum(oops::ObsOperator)',
                          'sum(oops::VariableChange)']
    self.sumfunction_list = ['oops::GetValues',
                             'oops::ObsError',
                             'oops::ObsFilter',
                             'oops::ObsSpace',
                             'oops::ObsVector',
                             'oops::ObsOperator',
                             'oops::VariableChange']
    self.stats = {}
    self.stats[sym1] = {}
    self.stats[sym2] = {}

    self.tstr = []
      
  def set_linear(self, linear=1):
    self.linear = linear

  def set_output(self, output=1):
    self.output = output

  def process(self, startdate='2020010100', enddate='2020010100', interval=6):
    datestr = startdate
    while (datestr != enddate):
      self.tstr.append(datestr)

      firstfile = '%s/%s/log.solver.out' %(self.firstdir, datestr)
      secondfile = '%s/%s/log.solver.out' %(self.seconddir, datestr)

      self.stats[self.sym1][datestr] = self.process_file(firstfile)
      self.stats[self.sym2][datestr] = self.process_file(secondfile)
      datestr = advancedate(datestr, interval)

  def process_file(self, flnm):
    stats = {}
    stats['file'] = flnm
    if(os.path.exists(flnm)):
      if(self.debug):
        print('Processing file: %s' %(flnm))
      pass
    else:
      print('Filename ' + flnm + ' does not exit. Stop')
      sys.exit(-1)

    object = 0
    general = 0
    parallel = 0

    stats['object'] = {}
    stats['general'] = {}
    stats['parallel'] = {}
    
    with open(flnm) as fp:
      lines = fp.readlines()
     #line = fp.readline()
      num_lines = len(lines)
     #print('Total number of lines: ', num_lines)

      nl = 0
      while(nl < num_lines):
        line = lines[nl]
        nl += 1
        if(line.find('OOPS_STATS ') < 0):
          continue

       #print('Line %d: %s' %(nl, line))

        if(line.find('- Object counts -') > 0):
          object += 1
          if(object > 1):
            object = 0
        if(line.find('- Timing Statistics -') > 0):
          general += 1
          if(general > 1):
            general = 0
        if(line.find('- Parallel Timing Statistics ') > 0):
          parallel += 1
          if(parallel > 1):
            parallel = 0
          
        fstr = line[11:].strip()
       #print('\t%s' %(fstr))
       #print('object: %d, general: %d, parallel: %d' %(object, general, parallel))

        if(fstr.find('::') > 0):
          while(fstr.find('  ') > 0):
            fstr = fstr.replace('  ', ' ')
          if(general):
            name, tvec = self.time_stats(fstr)
            stats['general'][name] = tvec
          elif(parallel):
            name, tvec = self.parallel_time_stats(fstr)
            stats['parallel'][name] = tvec
          elif(object):
            name, ivec = self.object_stats(fstr)
            stats['object'][name] = ivec
        else:
          if(fstr.find('Run end ') >= 0):
            tvec = self.runtimeNmemory(fstr)
            stats['runtime'] = tvec
           #print('tvec = ', tvec)
    return stats
  
  def object_stats(self, tstr):
    item = tstr.split(': ')
   #print(item)
    name = item[0].strip()
    tlist = item[1].split(' ')
    tvec = [int(tlist[0]), int(tlist[1])]
    return name, tvec

  def time_stats(self, tstr):
    item = tstr.split(': ')
   #print(item)
    name = item[0].strip()
    tlist = item[1].split(' ')
    ivec = [float(tlist[0]), int(tlist[1])]
    return name, ivec

  def parallel_time_stats(self, tstr):
    item = tstr.split(': ')
   #print(item)
    name = item[0].strip()
    tlist = item[1].split(' ')
    tvec = np.zeros((len(tlist)), dtype=float)
    for n in range(len(tlist)):
      tvec[n] = float(tlist[n])

   #print('name: ', name)
   #print('tvec: ', tvec)
    return name, tvec

  def runtimeNmemory(self, tstr):
    item = tstr.split(', ')
   #print(item)
    tlist = item[0].split(' ')
    runtime = float(tlist[-2])
    tlist = item[1].split(' ')
    totalmem = float(tlist[-2])
    tlist = item[2].split(' ')
    minmem = float(tlist[-2])
    tlist = item[3].split(' ')
    maxmem = float(tlist[-2])
    tvec = [runtime, totalmem, minmem, maxmem]
   #print(tvec)
    return tvec

  def plot(self):
    nf = len(self.tstr)
    y1 = np.zeros((nf), dtype=float)
    y2 = np.zeros((nf), dtype=float)
    name = 'runtime'
    for k in range(nf):
      y1[k] = self.stats[self.sym1][self.tstr[k]][name][0]/60.0
      y2[k] = self.stats[self.sym2][self.tstr[k]][name][0]/60.0

    print('y1 = ', y1)
    print('y2 = ', y2)

    self.plotit(y1, y2, 'runtime')

    fact = 0.001/60.0
    type = 'parallel'
    name = 'oops::ObsSpace::ObsSpace'
    for k in range(nf):
      y1[k] = self.stats[self.sym1][self.tstr[k]][type][name][2]*fact
      y2[k] = self.stats[self.sym2][self.tstr[k]][type][name][2]*fact

    print('y1 = ', y1)
    print('y2 = ', y2)

    self.plotit(y1, y2, 'ObsSpace')

    type = 'parallel'
    name = 'oops::GETKFSolver::measurementUpdate'
    for k in range(nf):
      y1[k] = self.stats[self.sym1][self.tstr[k]][type][name][2]*fact
      y2[k] = self.stats[self.sym2][self.tstr[k]][type][name][2]*fact

    print('y1 = ', y1)
    print('y2 = ', y2)

    self.plotit(y1, y2, 'measurementUpdate')

  def plotit(self, y1, y2, name):
    try:
      plt.close('all')
      plt.clf()
      plt.cla()
    except Exception:
      pass

    title = '%s Timing' %(name)

    nf = len(y1)
    x = np.zeros((nf), dtype=float)
    xlabels = []
    for k in range(nf):
      x[k] = k
      xlabels.append(self.tstr[k])

    pmin = 1.0/128.0
    pmax = 0.001*np.max(y1)/60.0
    ylabels = []
    yp = []
    pcur = pmin/2.0
    while(pcur < pmax):
      pcur *= 4.0
      lbl = '%6.2f' %(pcur)
      ylabels.append(lbl)
      yp.append(pcur)
     #print('yp = ', yp)
    pmax = pcur

    fig = plt.figure()
    ax = plt.subplot()

    if(self.linear):
      plt.xscale('linear')
    else:
      plt.xscale('linear')
     #plt.yscale('log', base=10)
      plt.xscale('log', base=2)
      plt.yscale('log', base=2)
     #plt.yscale('log', basey=2)

    plt.xticks(x, xlabels)
    plt.xticks(x, xlabels, rotation=45)
   #plt.yticks(yp, ylabels)

    txtname = '%s/timing_%s.csv' %(self.casename, name)
    OPF = open(txtname, 'w')
    header = '%10s, %12s, %12s' %('Date', self.sym1, self.sym2)
    OPF.write(header+'\n')

    for k in range(nf):
      txtinfo = '%s, %12.2f, %12.2f' %(self.tstr[k], y1[k], y2[k])
      OPF.write(txtinfo+'\n')
    OPF.close()

    ax.plot(x, y1, color=self.colorlist[0], linewidth=2,
            linestyle=self.linestyle[0], alpha=0.9)
    ax.plot(x, y2, color=self.colorlist[1], linewidth=2,
            linestyle=self.linestyle[1], alpha=0.9)

    plt.grid()

   #Same limits for everybody!
   #print('pmin: %f, pmax: %f' %(pmin, pmax))

    plt.xlim(x[0], x[-1])
   #plt.ylim(pmin, pmax)
 
   #general title
    title = 'Timing of %s (in minutes)' %(name)
   #plt.suptitle(title, fontsize=13, fontweight=0, color='black', style='italic', y=1.02)
    plt.suptitle(title, fontsize=16, fontweight=1, color='black')

   #Create a big subplot
    bs = fig.add_subplot(111, frameon=False)
   #plt.subplots_adjust(bottom=0.2, right=0.70, top=0.8)
   #plt.subplots_adjust(bottom=0.2, right=0.675, top=0.8)
    plt.subplots_adjust(bottom=0.2, right=0.65, top=0.8)
   #plt.subplots_adjust(bottom=0.2, right=0.5, top=0.8)

   #hide tick and tick label of the big axes
    plt.tick_params(labelcolor='none', top='off', bottom='off', left='off', right='off')

   #bs.set_xlabel('Date', labelpad=10) # Use argument `labelpad` to move label downwards.
    bs.set_ylabel('Time (minutes)', labelpad=20)

   #Create the legend
   #fig.legend(ax, labels=[self.sym1, self.sym2],
   #           loc="center right",   # Position of legend
   #           fontsize=6,
   #           borderpad=1.2,
   #           handlelength=1.5)

   #Adjust the scaling factor to fit your legend text completely outside the plot
   #(smaller value results in more space being made for the legend)

    if(self.linear):
      imgname = '%s/lin_timing_%s.png' %(self.casename, name)
    else:
      imgname = '%s/log_timing_%s.png' %(self.casename, name)

    if(self.output):
      plt.savefig(imgname)
    else:
      plt.show()

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  firstdir = '/work2/noaa/da/weihuang/cycling/jedi_C96_lgetkf_sondesonly'
  seconddir = '/work2/noaa/da/weihuang/cycling/sepreint.jedi_C96_lgetkf_sondesonly'
  startdate = '2020010200'
  enddate = '2020010306'
  output = 0
  linear = 1
  interval = 6
  casename = 'Sepreinit'
  sym1 = 'SRIO'
  sym2 = 'Orig'

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'firstdir=', 'seconddir=',
                                                'startdate=', 'enddate=', 'interval=',
                                                'sym1=', 'sym2=',
                                                'output=', 'linear=', 'casename='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--firstdir'):
      firstdir = a
    elif o in ('--seconddir'):
      seconddir = a
    elif o in ('--startdate'):
      startdate = a
    elif o in ('--enddate'):
      enddate = a
    elif o in ('--casename'):
      casename = a
    elif o in ('--sym1'):
      sym1 = a
    elif o in ('--sym2'):
      sym2 = a
    elif o in ('--interval'):
      interval = int(a)
    elif o in ('--output'):
      output = int(a)
    elif o in ('--linear'):
      linear = int(a)
    else:
      assert False, 'unhandled option'

  pr = Profiler(debug=debug, firstdir=firstdir, seconddir=seconddir,
                sym1=sym1, sym2=sym2,
                output=output, linear=linear, casename=casename)
 #pr.set_linear(linear=linear)
 #pr.set_output(output=output)

  pr.process(startdate=startdate, enddate=enddate, interval=interval)
  pr.plot()


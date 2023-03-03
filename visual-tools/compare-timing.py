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
      
  def set_linear(self, linear=1):
    self.linear = linear

  def set_output(self, output=1):
    self.output = output

  def process(self, startdate='2020010100', enddate='2020010100', interval=6):
    datestr = startdate
    while (datestr != enddate):
      firstfile = '%s/%s/log.solver.out' %(self.firstdir, datestr)
      secondfile = '%s/%s/log.solver.out' %(self.seconddir, datestr)

      self.stats[sym1][datestr] = self.process_file(firstfile)
      self.stats[sym2][datestr] = self.process_file(secondfile)
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

        print('Line %d: %s' %(nl, line))

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
        print('\t%s' %(fstr))

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
      tvec = float(tlist[n])
    return name, tvec

  def plot(self):
    try:
      plt.close('all')
      plt.clf()
      plt.cla()
    except Exception:
      pass

    title = '%s Timing' %(self.casename)

    nf = len(self.filelist)
    x = np.zeros((nf), dtype=float)
    y = np.zeros((nf), dtype=float)
    z = np.zeros((nf), dtype=float)
    xlabels = []
    for k in range(nf):
      x[k] = k
      lbl = '%d' %(k)
      xlabels.append(lbl)

    pmin = 1.0/128.0
    pmax = 256.0
    ylabels = []
    yp = []
    pcur = pmin/2.0
    while(pcur < pmax):
      pcur *= 4.0
      lbl = '%6.2f' %(pcur)
      ylabels.append(lbl)
      yp.append(pcur)
     #print('yp = ', yp)

    fig = plt.figure()
    ax = plt.subplot()

    if(self.linear):
      plt.xscale('linear')
    else:
     #plt.xscale('log', base=2)
     #plt.yscale('log', base=10)
      plt.xscale('log', base=2)
      plt.yscale('log', base=2)
     #plt.xscale('log', basex=2)
     #plt.yscale('log', basey=2)
      plt.xticks(x, xlabels)
     #plt.xticks(x, xlabels, rotation ='vertical')
      plt.yticks(yp, ylabels)

    pmin = 1.0e20
    pmax = 0.0

    txtname = '%s/timing_sum.csv' %(self.casename)
    OPF = open(txtname, 'w')
    header = '%40s' %('Function Name')
    for k in range(nf):
      header = '%s, %s' %(header, self.filelist[k])
    OPF.write(header+'\n')

    for i in range(len(self.function_list)):
     #print('self.function_list[%d] = %s' %(i, self.function_list[i]))
     #print('self.statstime[i] = ', self.statstime[i])
      txtinfo = '%40s' %(self.function_list[i])
      npnts = 0
      for k in range(nf):
        y[k] = 0.001*self.statstime[i][k]/60.0
        if(pmin > y[k]):
          pmin = y[k]
        if(pmax < y[k]):
          pmax = y[k]
        txtinfo = '%s, %12.2f' %(txtinfo, y[k])
        if(y[k] > self.shortest_time):
          npnts += 1
      OPF.write(txtinfo+'\n')
     #print('x = ', x[0:npnts])
     #print('y = ', y[0:npnts])
     #print('self.colorlist[%d] = %s' %(i, self.colorlist[i]))
     #print('self.linestyle[%d] = %s' %(i, self.linestyle[i]))
      if(npnts > 1):
        ax.plot(x[0:npnts], y[0:npnts], color=self.colorlist[i], linewidth=2,
                linestyle=self.linestyle[i], alpha=0.9)
    OPF.close()

    if(self.linear == 0):
      for i in range(len(self.sumfunction_list)):
        npnts = 0
        for k in range(nf):
          z[k] = 0.001*self.statstime[i][0]/60.0
          if(z[k] > self.shortest_time):
            npnts += 1
       #https://matplotlib.org/stable/gallery/lines_bars_and_markers/linestyles.html
        if(npnts > 1):
          ax.plot(x[0:npnts], z[0:npnts], color='black', linewidth=1, alpha=0.5, linestyle='dotted')

    plt.grid()

   #Same limits for everybody!
    print('pmin: %f, pmax: %f' %(pmin, pmax))

   #if(pmin < self.shortest_time):
   #  pmin = self.shortest_time
   #if(pmax < 10000.0):
   #  pmax = 10000.0

    pmin = 1.0/128.0
    pmax = 256.0
   
    plt.xlim(x[0], x[-1])
    plt.ylim(pmin, pmax)
 
   #general title
   #title = '%s Timing (in minutes), min: %8.2f, max: %8.2f' %(self.casename, pmin, pmax)
    title = '%s Timing (in minutes)' %(self.casename)
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

    bs.set_xlabel('Node', labelpad=10) # Use argument `labelpad` to move label downwards.
    bs.set_ylabel('Time (minutes)', labelpad=20)

   #Create the legend
    fig.legend(ax, labels=self.function_list,
           loc="center right",   # Position of legend
           fontsize=6,
           borderpad=1.2,
           handlelength=1.5
           )

#          borderpad=1.2,
#          labelspacing=1.2,
#          handlelength=1.5

   #Adjust the scaling factor to fit your legend text completely outside the plot
   #(smaller value results in more space being made for the legend)

    if(self.linear):
      imgname = '%s/lin_timing_sum.png' %(self.casename)
    else:
      imgname = '%s/log_timing_sum.png' %(self.casename)

    if(self.output):
      plt.savefig(imgname)
    else:
      plt.show()

    for name in self.sumfunction_list:
      self.plot_obs(name)

  def plot_obs(self, obsname):
    try:
      plt.close('all')
      plt.clf()
      plt.cla()
    except Exception:
      pass

    item = obsname.split('::')
    varname = item[1]

    print('obsname = ', obsname)
    print('varname = ', varname)

    print('keys of self.sumstats = ',  self.sumstats.keys())

    stats = self.sumstats[obsname]
    names = self.sumnames[obsname]

    print('keys of stats = ', stats.keys())
    print('names = ', names)

    title = 'Timing of %s' %(varname)

    nf = len(self.filelist)
    x = np.zeros((nf), dtype=float)
    y = np.zeros((nf), dtype=float)
    z = np.zeros((nf), dtype=float)
    xlabels = []
    for k in range(nf):
      x[k] = k
      lbl = '%d' %(k)
      xlabels.append(lbl)

    pmin = 1.0/128.0
    pmax = 0.001*np.max(stats['sum'])/60.0
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
     #plt.xscale('log', base=2)
     #plt.yscale('log', base=10)
      plt.xscale('log', base=2)
      plt.yscale('log', base=2)
     #plt.xscale('log', basex=2)
     #plt.yscale('log', basey=2)
      plt.xticks(x, xlabels)
     #plt.xticks(x, xlabels, rotation ='vertical')
      plt.yticks(yp, ylabels)

    txtname = '%s/timing_%s.csv' %(self.casename, varname)
    OPF = open(txtname, 'w')
    header = '%40s' %('Function Name')
    for k in range(nf):
      header = '%s, %s' %(header, self.filelist[k])
    OPF.write(header+'\n')

    legneds = names
    i = 0
    for key in legneds:
      txtinfo = '%40s' %(key)
      npnts = 0
      for k in range(nf):
        y[k] = 0.001*stats[key][k]/60.0
        txtinfo = '%s, %12.2f' %(txtinfo, y[k])
        if(y[k] > self.shortest_time):
          npnts += 1
      OPF.write(txtinfo+'\n')
      if(npnts > 1):
        ax.plot(x[0:npnts], y[0:npnts], color=self.colorlist[i], linewidth=2,
                linestyle=self.linestyle[i], alpha=0.9)
      i += 1
    OPF.close()

    if(self.linear == 0):
      i = 0
      for key in stats.keys():
        npnts = 0
        for k in range(nf):
          z[k] = 0.001*stats[key][0]/60.0
          if(z[k] > self.shortest_time):
            npnts += 1
       #https://matplotlib.org/stable/gallery/lines_bars_and_markers/linestyles.html
        if(npnts > 1):
          ax.plot(x[0:npnts], z[0:npnts], color='black', linewidth=1, alpha=0.5, linestyle='dotted')
        i += 1

    plt.grid()

   #Same limits for everybody!
   #print('pmin: %f, pmax: %f' %(pmin, pmax))

    plt.xlim(x[0], x[-1])
    plt.ylim(pmin, pmax)
 
   #general title
   #title = '%s Timing (in minutes), min: %8.2f, max: %8.2f' %(self.casename, pmin, pmax)
    title = 'Timing of %s (in minutes)' %(obsname)
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

    bs.set_xlabel('Node', labelpad=10) # Use argument `labelpad` to move label downwards.
    bs.set_ylabel('Time (minutes)', labelpad=20)

   #Create the legend
    fig.legend(ax, labels=legneds,
               loc="center right",   # Position of legend
               fontsize=6,
               borderpad=1.2,
               handlelength=1.5)

#          borderpad=1.2,
#          labelspacing=1.2,
#          handlelength=1.5

   #Adjust the scaling factor to fit your legend text completely outside the plot
   #(smaller value results in more space being made for the legend)

    if(self.linear):
      imgname = '%s/lin_timing_%s.png' %(self.casename, varname)
    else:
      imgname = '%s/log_timing_%s.png' %(self.casename, varname)

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
  enddate = '2020010206'
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
 #pr.plot()


import getopt
import os, sys
import numpy as np

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from mpl_toolkits.axes_grid1 import make_axes_locatable

from datetime import *
from datetime import timedelta
from matplotlib import rcParams
from scipy import stats

import netCDF4 as nc4

#=========================================================================
def ttest(data1, data2, inflate=False):
    # calculate means
    mean1 = data1.mean(axis=0); mean2 = data2.mean(axis=0)
    # number of paired samples
    n = data1.shape[0]
    # sum squared difference between observations
    d1 = ((data1-data2)**2).sum(axis=0)
    # sum difference between observations
    d2 = (data1-data2).sum(axis=0)
    # standard deviation of the difference between means
    sd = np.sqrt((d1 - (d2**2 / n)) / (n - 1))
    # standard error of the difference between the means
    inflation = 1.0
    if inflate:
        # inflation to represent autocorrelation (see Geer 2016 appendix, Wilks 2006)
        x = data1-data2
        r1 = np.empty(data1.shape[1])
        r2 = np.empty(data1.shape[1])
        for i in range(data1.shape[1]):
            r1[i] = np.corrcoef(x[:-1,i], x[1:,i],rowvar=False)[0,1]
            r2[i] = np.corrcoef(x[:-2,i], x[2:,i],rowvar=False)[0,1]
        #r2 = r1 # AR(1)
        phi1 = r1*(1.-r2)/(1.-r1**2)
        phi2 = (r2-r1**2)/(1.-r1**2)
        rho1  = phi1/(1.-phi2)
        rho2 = phi2 + phi1**2/(1.-phi2)
        inflation = np.sqrt((1.-rho1*phi1-rho2*phi2)/(1.-phi1-phi2)**2)
        inflation = np.where(inflation < 1.0, 1.0, inflation)
    sed = inflation*sd / np.sqrt(n)
    # calculate the t statistic
    t_stat = (mean1 - mean2) / sed
    # return the p-values
    return 1.-(1.-stats.t.cdf(abs(t_stat), n-1)) * 2.0 # two sided

#=========================================================================
def ttest2(data1,data2):
    t, p = stats.ttest_rel(data1,data2)
    return 1.-p

#=========================================================================
def hour2date(hour):
  st = datetime(1970, 1, 1, 0, 0, 0)
  dt = timedelta(hours=hour)
  ct = st + dt

  date = ct.strftime("%Y-%m-%d:%H")

 #print('st = ', st)
 #print('ct = ', ct)
 #print('dt = ', dt)
 #print('date = ', date)

  return date

#=========================================================================
def read_stats(filename):
  fin = open(filename,'r')
  lines = fin.readlines()
  fin.close()

  mystats = {}

 #fin.write('# %s %s %s %s-%s\n' % (datapath,self.runid,self.hem,self.sdate,self.edate))
  item = lines[0].strip().split(' ')
 #print('item = ', item)
  mystats['datapath'] = item[1]
  mystats['runid'] = item[2]
  mystats['hem'] = item[3]
  dateitem = item[4].split('-')
  mystats['sdate'] = dateitem[0]
  mystats['edate'] = dateitem[1]

 #fin.write('# press wind_count wind_rms temp_count temp_rms temp_bias humid_rmsx1000 humid_biasx1000\n')
  item = lines[1].strip().split(' ')
  mystats['stats_name'] = item[1:]
 #print("stats['stats_name'] = ", mystats['stats_name'])

 #fin.write('# 1000-0 %10i %7.4f %10i %7.4f %7.4f %10i %7.4f %7.4f\n' % (count_wind.sum(), rms_wind.mean(), count_temp.sum(), rms_temp.mean(), bias_temp.mean(), count_humid.sum(), 1000*rms_humid.mean(), 1000*bias_humid.mean()))
  sumline = lines[2]
  while(sumline.find('  ') >= 0):
    sumline = sumline.replace('  ', ' ')
  item = sumline.strip().split(' ')
 #print('item = ', item)
  mystats['count_wind_sum'] = float(item[2])
  mystats['rms_wind_mean'] = float(item[3])
  mystats['count_temp_sum'] = float(item[4])
  mystats['rms_temp_mean'] = float(item[5])
  mystats['bias_temp_mean'] = float(item[6])
  mystats['count_humid_sum'] = float(item[7])
  mystats['rms_humid_mean'] = float(item[8])
  mystats['bias_humid_mean'] = float(item[9])

  mystats['p'] = []
  mystats['count_wind'] = []
  mystats['rms_wind'] = []
  mystats['count_temp'] = []
  mystats['rms_temp'] = []
  mystats['bias_temp'] = []
  mystats['count_humid'] = []
  mystats['rms_humid'] = []
  mystats['bias_humid'] = []
  for n in range(3, len(lines)):
    line = lines[n].strip()
    while(line.find('  ') >= 0):
      line = line.replace('  ', ' ')
    item = line.strip().split(' ')
    if(item[0] != '#'):
      mystats['p'].append(float(item[0]))
      mystats['count_wind'].append(float(item[1]))
      mystats['rms_wind'].append(float(item[2]))
      mystats['count_temp'].append(float(item[3]))
      mystats['rms_temp'].append(float(item[4]))
      mystats['bias_temp'].append(float(item[5]))
      mystats['count_humid'].append(float(item[6]))
      mystats['rms_humid'].append(float(item[7]))
      mystats['bias_humid'].append(float(item[8]))
    else:
      mystats['rms_wind_mean'] = float(item[1])
      mystats['rms_temp_mean'] = float(item[2])
      mystats['rms_humid_mean'] = float(item[3])

 #print('mystats = ', mystats)
  return mystats

#=========================================================================
def plot_lines(plevs, frtrms, sndrms, header='temp', output=0, lbl1='UNKOWN1', lbl2='UNKOWN2'):
  try:
    plt.close('all')
    plt.clf()
    plt.cla()
  except Exception:
    pass

  title = header + ' RMS'

 #print('plevs = ', plevs)
 #print('frtrms = ', frtrms)
 #print('sndrms = ', sndrms)

  print('\n')
  print('Variable name: ', header)
  print('pressure   frtrms    sndrms')
  k = len(plevs)
  for n in range(len(plevs)):
    k -= 1
    print('%4.0f %7.4f %7.4f' %(plevs[k], frtrms[k], sndrms[k]))

  pmin = 0.0
 #pmin = np.min(sndrms)
 #gmin = np.min(frtrms)
 #if(pmin > gmin):
 #  pmin = gmin

  pmax = np.max(sndrms)
  gmax = np.max(frtrms)
  if(pmax < gmax):
    pmax = gmax
  vmax = 0.0
 
  x = [0]
  xlabels = ['0']
  k = 0
  while(vmax < pmax):
    k += 1
    vmax += 1.0
    lbl = '%d' %(k)
    xlabels.append(lbl)
    x.append(k)

  y = np.linspace(0,1000,11)
  ylabels = []
  for v in y:
    lbl = '%d' %(1000-v)
    ylabels.append(lbl)

  fig = plt.figure()
  ax = plt.subplot()

  k = 0
  yp = []
  xd = []
  for pres in plevs:
    yp.append(1000-pres)
    jmg = sndrms[k] - frtrms[k]
    xd.append(jmg)
    k += 1

  ax.plot(frtrms, yp, color='blue', linewidth=2, alpha=0.9)
  ax.plot(sndrms, yp, color='red', linewidth=2, alpha=0.9)

  plt.xscale('linear')
 #plt.xscale('log', base=2)
 #plt.yscale('log', base=2)
 #plt.yscale('log', base=10)
  plt.xticks(x, xlabels)
 #plt.xticks(x, xlabels, rotation ='vertical')
  plt.yticks(y, ylabels)

 #ax.plot(xd, yp, color='cyan', linewidth=2, alpha=0.9)

  plt.grid()

 #Same limits for everybody!
 #print('pmin: %f, pmax: %f' %(pmin, pmax))
  plt.xlim(0, vmax)
  plt.ylim(0, 1000)
 
 #general title
  title = '%s and %s %s rms' %(lbl1, lbl2, header)
  plt.suptitle(title, fontsize=16, fontweight=1, color='black')

 #Create a big subplot
  bs = fig.add_subplot(111, frameon=False)
  plt.subplots_adjust(bottom=0.2, right=0.70, top=0.8)

 #hide tick and tick label of the big axes
  plt.tick_params(labelcolor='none', top='off', bottom='off', left='off', right='off')

  bs.set_xlabel('(m/s)', labelpad=10)
  bs.set_ylabel('Pressure (hPa)', labelpad=20)

  labels = [lbl1, lbl2]

 #Create the legend
  fig.legend(ax, labels=labels,
         loc="center right",   # Position of legend
         fontsize=8,
         borderpad=1.2,
         labelspacing=1.2,
         handlelength=1.5
         )

 #Adjust the scaling factor to fit your legend text completely outside the plot
 #(smaller value results in more space being made for the legend)

  imgname = '%s_rms.png' %(header)

  if(output):
    plt.savefig(imgname)
  else:
    plt.show()

#=========================================================================
class Plot_JEDI_GSI_Diag():
  def __init__(self, debug=0, output=0):
    self.debug = debug
    self.output = output

    self.set_default()

  def plot_contour(self, times, plevs, data=[]):
    try:
      plt.close('all')
      plt.clf()
      plt.cla()
    except Exception:
      pass

    nrows = 1
    ncols = len(data)

    y = []
    for pres in plevs:
      y.append(1000-pres)

    ylp = np.linspace(0,1000,11)
    yt = []
    ylabels = []
    for pv in ylp:
      lbl = '%d' %(1000-pv)
      yt.append(pv)
      ylabels.append(lbl)

    x = (times - times[0])/24.0
    xv = 0
    xt = [0]
    xlabels = [0]
    while(xv < x[-1]):
     #xv += 1
      xv += 2
      lbl = '%d' %(xv)
      xlabels.append(lbl)
      xt.append(xv)

    fig, axs = plt.subplots(nrows=nrows,ncols=ncols,
                            figsize=(11,8.5))
 
   #axs is a 2 dimensional array of `GeoAxes`. Flatten it into a 1-D array
    axs=axs.flatten()

    for i in range(len(axs)):
     #axs[i].set_global()

      pvar = data[i]

     #print('Plot No. ', i)
     #print('\tpvar.shape = ', pvar.shape)

      vmin = np.min(pvar)
      vmax = np.max(pvar)

      if(i < 2):
       #self.cmapname = 'coolwarm'
       #self.cmapname = 'rainbow'
        self.cmapname = 'jet'
        self.clevs = np.arange(0.0, 10.1, 0.1)
        self.cblevs = np.arange(0.0, 11.0, 1.0)
      else:
        self.cmapname = 'bwr'
       #self.clevs = np.arange(-2.0, 2.1, 0.1)
       #self.cblevs = np.arange(-2.0, 3.0, 1.0)
        self.clevs = np.arange(-0.5, 0.52, 0.02)
        self.cblevs = np.arange(-0.5, 0.6, 0.2)
       #self.clevs = np.arange(-0.1, 0.11, 0.01)
       #self.cblevs = np.arange(-0.1, 0.15, 0.05)

      xm, ym = np.meshgrid(x, y)
      cs=axs[i].contourf(xm, ym, pvar,
                         levels=self.clevs, extend=self.extend,
                         alpha=self.alpha, cmap=self.cmapname)

      title = '%s min: %5.2f, max: %5.2f' %(self.runname[i], vmin, vmax)
      axs[i].set_title(title)

     #axs[i].set_xlabel('Hours', fontsize=10)
      axs[i].set_xlabel('Days', fontsize=10)
      if(i < 1):
        axs[i].set_ylabel('hPa', fontsize=10)

      axs[i].set_xticks(xt, xlabels)
      axs[i].set_yticks(yt, ylabels)

     #minor_ticks_top=np.linspace(0,60,13)
     #minor_ticks_top=np.linspace(-60,0,13)
     #axs[i].set_yticks(minor_ticks_top,minor=True)

     #Draw the colorbar
      cbar=plt.colorbar(cs, ax=axs[i], pad=self.pad,
                        ticks=self.cblevs,
                        orientation='horizontal')

     #cbar.set_label(self.label, rotation=90)
      cbar.set_label(self.label)

   #Add a big title at the top
    hour = float(times[0])
    date = hour2date(hour)
    title = '%s start from %s' %(self.title, date)
    plt.suptitle(title)

    fig.canvas.draw()
   #plt.tight_layout()

    if(self.output):
      if(self.imagename is None):
        imagename = 'sample.png'
      else:
        imagename = self.imagename
      plt.savefig(imagename)
      plt.close()
    else:
      plt.show()

  def plot_mean_rms(self, stats1=None, stats2=None, lbl1=None, lbl2=None, title=None, region=None):
    try:
      plt.close('all')
      plt.clf()
      plt.cla()
    except Exception:
      pass

    color1 = 'r'
    color2 = 'b'
    linewidth1 = 1.0
    linewidth2 = 1.0

    obtypes = 'Vertical integrated RMS'

    rcParams['figure.subplot.left'] = 0.1 
    rcParams['figure.subplot.top'] = 0.85 
    rcParams['legend.fontsize']=12

    dates = stats1['dates']
    dates_txt = '%s-%s' % (dates[0],dates[-1])
    levels = stats1['levels']
    wind_fits1 = stats1['wind_fits']
    wind_fits2 = stats2['wind_fits']

    times = stats1['times']
    print('times=', times)
    hour0 = times[0]
    days = (times - hour0)/24.0
    tmin = 0
    tmax = days[-1]

    fig = plt.figure(figsize=(8,6))
    plt.subplot(1,2,1)
    wind_fits1mean = wind_fits1.mean(axis=1)
    wind_fits2mean = wind_fits2.mean(axis=1)

    print('Wind rms min: %f6.2, max: %6.2f' %(np.min(wind_fits1mean), np.max(wind_fits1mean)))

    plt.plot(days,wind_fits1mean,color=color1,linewidth=linewidth1,marker='o',label=lbl1)
    plt.plot(days,wind_fits2mean,color=color2,linewidth=linewidth2,marker='o',label=lbl2)
    plt.ylabel('RMS (mps)')
    plt.title('%s: %s' % (obtypes+' V',region))
    plt.xlabel('Days')
    plt.axis('tight')
    plt.xlim(tmin, tmax)
   #plt.ylim(3.75, 4.75)
   #plt.ylim(3.25, 5.25)
    plt.ylim(3.75, 4.75)
    plt.grid(True)

    temp_fits1 = stats1['temp_fits']
    temp_fits2 = stats2['temp_fits']

    plt.subplot(1,2,2)
    temp_fits1mean = np.sqrt(temp_fits1).mean(axis=1)
    temp_fits2mean = np.sqrt(temp_fits2).mean(axis=1) 

    print('Temp rms min: %f6.2, max: %6.2f' %(np.min(temp_fits1mean), np.max(temp_fits1mean)))

    plt.plot(days,temp_fits1mean,color=color1,linewidth=linewidth1,marker='o',label=lbl1)
    plt.plot(days,temp_fits2mean,color=color2,linewidth=linewidth2,marker='o',label=lbl2)
    plt.xlabel('Days')
    plt.title('%s: %s' % (obtypes+' T',region))
    plt.axis('tight')
    plt.xlim(tmin, tmax)
   #plt.ylim(1.5, 2.25)
   #plt.ylim(1.0, 2.00)
    plt.ylim(1.75, 2.25)
    plt.grid(True)
    plt.legend(loc=0)

    plt.figtext(0.5,0.93,'%s RMS O-F (%s)' % (title,dates_txt),horizontalalignment='center',fontsize=14)
   #plt.savefig('mean_rms_%s_%s.png' % (title,region))
   #plt.close()

   #plt.show()

    if(self.output):
      imagename = 'mean_rms_%s_%s.png' % (title,region)
      plt.savefig(imagename)
      plt.close()
    else:
      plt.show()

  def set_default(self):
    self.imagename = 'sample.png'

    self.runname = ['UNKNOWN1', 'UNKNOWN2', 'UNKNOWN2 - UNKNOWN1']

   #cmapname = coolwarm, bwr, rainbow, jet, seismic
   #self.cmapname = 'bwr'
   #self.cmapname = 'coolwarm'
   #self.cmapname = 'rainbow'
    self.cmapname = 'jet'

    self.clevs = np.arange(-0.2, 0.21, 0.01)
    self.cblevs = np.arange(-0.2, 0.3, 0.1)

    self.extend = 'both'
    self.alpha = 0.5
    self.pad = 0.1
    self.orientation = 'horizontal'
    self.size = 'large'
    self.weight = 'bold'
    self.labelsize = 'medium'

    self.label = 'Unit (C)'
    self.title = 'Temperature Increment'

    self.levtop = 125
    self.levbot = 925 # plot limits
    self.sigthresh = 0.99       # significance threshold (p-value)

  def set_label(self, label='Unit (C)'):
    self.label = label

  def set_title(self, title='Temperature Increment'):
    self.title = title

  def set_clevs(self, clevs=[]):
    self.clevs = clevs

  def set_cblevs(self, cblevs=[]):
    self.cblevs = cblevs

  def set_imagename(self, imagename):
    self.imagename = imagename

  def set_cmapname(self, cmapname):
    self.cmapname = cmapname

  def get_stats(self, expt=None):
    nc_expt = nc4.Dataset(expt+'.nc','r')

    mystats = {}
    mystats['levels'] = nc_expt['plevs'][:]
    mystats['levels_up'] = nc_expt['plevs_up'][:]
    mystats['levels_down'] = nc_expt['plevs_down'][:]
    times = nc_expt['times'][:]
    mystats['times'] = times
   #print(times)

   #dates = [dateutils.hrstodate(time) for time in times] 
    dates = [hour2date(time) for time in times] 
    mystats['dates'] = dates

    mystats['wind_counts'] = nc_expt['wind_obcounts'][:]
    mystats['temp_counts'] = nc_expt['temp_obcounts'][:]
    mystats['temp_fits'] = nc_expt['omf_rmstemp'][:]
    mystats['temp_bias'] = nc_expt['omf_biastemp'][:]
    mystats['wind_fits']  = nc_expt['omf_rmswind'][:]

   #print(wind_fits.mean(axis=0))
   #raise SystemExit

    nc_expt.close()

    return mystats

  def set_runname(self, lbl1='UNKNOWN1', lbl2='UNKNOWN2'):
    self.runname[0] = lbl1
    self.runname[1] = lbl2
    self.runname[2] = '%s - %s' %(lbl2, lbl1)

  def plot(self, stats1=None, stats2=None, lbl1=None, lbl2=None, title=None, region=None):
    color1 = 'r'
    color2 = 'b'
    linewidth1 = 1.0
    linewidth2 = 1.0

    obtypes = 'All Insitu'

    rcParams['figure.subplot.left'] = 0.1 
    rcParams['figure.subplot.top'] = 0.85 
    rcParams['legend.fontsize']=12

    dates = stats1['dates']
    dates_txt = '%s-%s' % (dates[0],dates[-1])
    levels = stats1['levels']
    levels_up = stats1['levels_up']
    levels_down = stats1['levels_down']
    wind_fits1 = stats1['wind_fits']
    wind_fits2 = stats2['wind_fits']

    fig = plt.figure(figsize=(8,6))
    plt.subplot(1,2,1)
    wind_fits1mean = wind_fits1.mean(axis=0)
    wind_fits2mean = wind_fits2.mean(axis=0)
    wind_fits_pval = ttest(wind_fits1,wind_fits2,inflate=True)
    sig = wind_fits_pval >= self.sigthresh

    print('Wind rms min: %f6.2, max: %6.2f' %(np.min(wind_fits1mean), np.max(wind_fits1mean)))

    plt.plot(wind_fits1mean,levels,color=color1,linewidth=linewidth1,marker='o',label=lbl1)
    plt.plot(wind_fits2mean,levels,color=color2,linewidth=linewidth2,marker='o',label=lbl2)
    for n in range(len(levels)):
      if sig[n]:
        plt.axhspan(levels_up[n], levels_down[n], facecolor='lightgoldenrodyellow')
    plt.ylabel('pressure (hPa)')
    plt.title('%s: %s' % (obtypes+' V',region))
    plt.xlabel('RMS (mps)')
    plt.axis('tight')
   #if int(dates[1][4:6]) > 10 or int(dates[2][4:6]) < 4:
   #  plt.xlim(2.5,4.0)
   #else:
   #  plt.xlim(2.2,3.4)
   #  #plt.xlim(2.2,3.4)
   #Wind rms min: 3.0864446.2, max:   6.84
   #plt.xlim(3.25,5.5)
    plt.xlim(3.25,5.75)
    plt.ylim(self.levbot,self.levtop)
    plt.grid(True)

    temp_fits1 = stats1['temp_fits']
    temp_fits2 = stats2['temp_fits']

    plt.subplot(1,2,2)
    temp_fits1mean = np.sqrt(temp_fits1).mean(axis=0)
    temp_fits2mean = np.sqrt(temp_fits2).mean(axis=0) 
    temp_fits_pval = ttest(temp_fits1,temp_fits2,inflate=True)
    sig = temp_fits_pval >= self.sigthresh

    print('Temp rms min: %f6.2, max: %6.2f' %(np.min(temp_fits1mean), np.max(temp_fits1mean)))

    plt.plot(temp_fits1mean,levels,color=color1,linewidth=linewidth1,marker='o',label=lbl1)
    plt.plot(temp_fits2mean,levels,color=color2,linewidth=linewidth2,marker='o',label=lbl2)
    for n in range(len(levels)):
      if sig[n]:
        plt.axhspan(levels_up[n], levels_down[n], facecolor='lightgoldenrodyellow')
    plt.xlabel('RMS (K)')
    plt.title('%s: %s' % (obtypes+' T',region))
    plt.axis('tight')
   #plt.xlim(0.5,1.4)
   #plt.xlim(0.75,2.25)       
   #Temp rms min: 1.2050896.2, max:   4.07
   #plt.xlim(1.0,2.75)       
    plt.xlim(0.75,2.50)       
    plt.ylim(self.levbot,self.levtop)
    plt.grid(True)
    plt.legend(loc=0)

    plt.figtext(0.5,0.93,'%s RMS O-F (%s)' % (title,dates_txt),horizontalalignment='center',fontsize=14)
   #plt.savefig('obfits_%s_%s_%s.png' % (lbl1,lbl2,region))
   #plt.savefig('obfits_%s_%s.png' % (title,region))

   #plt.show()

    if(self.output):
      imagename = 'obfits_%s_%s_%s.png' % (lbl1,lbl2,region)
      plt.savefig(imagename)
      plt.close()
    else:
      plt.show()

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  output = 0
  title = 'UNKNOW2 and UNKNOW1'
  region = 'Hem'
  lbl1 = 'GSI'
  lbl2 = 'JEDI'

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'output=', 'title=',
                                                'region=', 'lbl1=', 'lbl2='])
  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--output'):
      output = int(a)
    elif o in ('--lbl1'):
      lbl1 = a
    elif o in ('--lbl2'):
      lbl2 = a
    elif o in ('--title'):
      title = a
    elif o in ('--region'):
      region = a
    else:
      assert False, 'unhandled option'

#-----------------------------------------------------------------------------------------
  pjgd = Plot_JEDI_GSI_Diag(debug=debug, output=output)

  pjgd.set_runname(lbl1=lbl1, lbl2=lbl2)

  fnam = 'stats_%s' %(lbl1)
  snam = 'stats_%s' %(lbl2)
  frt_stats = read_stats(fnam)
  snd_stats = read_stats(snam)

  p = frt_stats['p']
  frtrms = frt_stats['rms_temp']
  sndrms = snd_stats['rms_temp']

 #print('len(p) = ', len(p))
 #print('p = ', p)
 #print('len(frtrms) = ', len(frtrms))
 #print('frtrms = ', frtrms)

  plot_lines(p, frtrms, sndrms, header='temp', output=output, lbl1=lbl1, lbl2=lbl2)

  frtrms = frt_stats['rms_wind']
  sndrms = snd_stats['rms_wind']

  plot_lines(p, frtrms, sndrms, header='wind', output=output, lbl1=lbl1, lbl2=lbl2)

  frtrms = frt_stats['rms_humid']
  sndrms = snd_stats['rms_humid']

  for n in range(len(sndrms)):
    if(sndrms[n] < 0.0):
      sndrms[n] = 0.0
    if(frtrms[n] < 0.0):
      frtrms[n] = 0.0

  plot_lines(p, frtrms, sndrms, header='humidity', output=output, lbl1=lbl1, lbl2=lbl2)

#-----------------------------------------------------------------------------------------
  frtfile = '%s.nc' %(fnam)
  sndfile = '%s.nc' %(snam)

  ncfrt = nc4.Dataset(frtfile, 'r')
  ncsnd = nc4.Dataset(sndfile, 'r')

  times = ncfrt.variables['times']
  plevs = ncfrt.variables['plevs']

#-----------------------------------------------------------------------------------------
  clevs = np.arange(-1.0, 1.01, 0.01)
  cblevs = np.arange(-1.0, 1.1, 0.1)

  pjgd.set_clevs(clevs=clevs)
  pjgd.set_cblevs(cblevs=cblevs)

#-----------------------------------------------------------------------------------------
  varlist = ['omf_rmswind', 'omf_rmstemp', 'omf_rmshumid']
  unitlist = ['Unit (m/s)', 'Unit (C)', 'Unit (g/kg)']

#-----------------------------------------------------------------------------------------
  for n in range(len(varlist)):
    sndvar = ncsnd.variables[varlist[n]][:, :]
    frtvar = ncfrt.variables[varlist[n]][:, :]

    if('omf_rmshumid' == varlist[n]):
      sndvar = np.where(sndvar < 0.0, 0.0, 1.0e7*sndvar)
      frtvar = np.where(frtvar < 0.0, 0.0, 1.0e7*frtvar)

    ntime, nlev = sndvar.shape
   #print('sndvar.shape = ', sndvar.shape)
   #print('frtvar.shape = ', frtvar.shape)

    pjgd.set_label(unitlist[n])

    v0 = frtvar.transpose()
    v1 = sndvar.transpose()
   #v0 = frtvar
   #v1 = sndvar
    v2 = v1 - v0

    data = [v0, v1, v2]

    title = varlist[n]
    pjgd.set_title(title)

    print('Plotting ', title)
   #print('\tv0.shape = ', v0.shape)
   #print('\tv1.shape = ', v1.shape)
   #print('\tv2.shape = ', v2.shape)
 
   #print('\tv0.max: %f, v0.min: %f' %(np.max(v0), np.min(v0)))
   #print('\tv1.max: %f, v1.min: %f' %(np.max(v1), np.min(v1)))
   #print('\tv2.max: %f, v2.min: %f' %(np.max(v2), np.min(v2)))

    imagename = 'diag_%s.png' %(varlist[n])
    pjgd.set_imagename(imagename)

    pjgd.plot_contour(times, plevs, data=data)

#-----------------------------------------------------------------------------------------
  ncsnd.close()
  ncfrt.close()

  stats1 = pjgd.get_stats(expt=fnam)
  stats2 = pjgd.get_stats(expt=snam)

  pjgd.plot(stats1=stats1, stats2=stats2, lbl1=lbl1, lbl2=lbl2, title=title, region=region)
  pjgd.plot_mean_rms(stats1=stats1, stats2=stats2, lbl1=lbl1, lbl2=lbl2, title=title, region=region)


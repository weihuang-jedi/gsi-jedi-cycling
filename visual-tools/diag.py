import numpy as np
import os, sys
import getopt

from dateutil.rrule import *
from dateutil.parser import *
from datetime import *
from datetime import timedelta
from netCDF4 import Dataset

#=========================================================================
def get_dates(sdate, edate, intv):
  sdatestr = '%sT%s0000' %(sdate[0:8], sdate[8:10])
  edatestr = '%sT%s0000' %(edate[0:8], edate[8:10])

  hourly = list(rrule(HOURLY, interval=intv,
                dtstart=parse(sdatestr),
                until=parse(edatestr)))

 #print('hourly = ', hourly)

  dtlist = []
  for hd in hourly:
    ds = hd.strftime("%Y%m%d%H")
    dtlist.append(ds)

 #print('dtlist = ', dtlist)

  return dtlist

#=========================================================================
def cal_datetohrs(date):
  year = int(date[0:4])
  month = int(date[4:6])
  day = int(date[6:8])
  hour = int(date[8:10])
  ct = datetime(year, month, day, hour, 0, 0)
  st = datetime(1970, 1, 1, 0, 0, 0)
  dt = ct - st
  hour = dt / timedelta(hours=1)

 #print('st = ', st)
 #print('ct = ', ct)
 #print('dt = ', dt)
 #print('hour = ', hour)

  return float(hour)

#=========================================================================
class DiagObFit():
  def __init__(self, debug=0, output=0, sdate=None, edate=None,
               runid=None, hem='HS', sondesonly=True, interval=6,
               noair=False, aironly=False, latbound=30):
    msg = 'sdate edate runid hem'
    if(sdate is None or edate is None):
      print(msg)
      raise SystemExit

    self.sdate = sdate
    self.edate = edate
    self.runid = runid
    self.hem = hem

   #if sondesonly False, aircraft, pibals and surface data included also
   #self.sondesonly = False # use only 120,132,220,221,232 (sondes,pibals,drops)
    self.sondesonly = sondesonly
    self.noair = noair
    self.aironly = aironly
    self.latbound = latbound

    self.dates = get_dates(sdate, edate, interval)

    self.set_default()

 #def __del__(self):
 #  self.ncout.close()

  def set_default(self):
    self.deltap = 50.
    self.pbot = 975.
    self.nlevs = 23
    self.levs = np.zeros(self.nlevs, float)
    self.levs1 = np.zeros(self.nlevs, float)
    self.levs2 = np.zeros(self.nlevs, float)
    self.levs[0:18] = self.pbot - self.deltap*np.arange(18)
    self.levs1[0:18] = self.levs[0:18] + 0.5*self.deltap
    self.levs2[0:18] = self.levs[0:18] - 0.5*self.deltap
    self.levs1[18] = self.levs2[17]
    self.levs2[18] = 70.
    self.levs1[19] = 70.
    self.levs2[19] = 50.
    self.levs1[20] = 50.
    self.levs2[20] = 30.
    self.levs1[21] = 30.
    self.levs2[21] = 10.
    self.levs1[22] = 10.
    self.levs2[22] = 0.
    self.levs1[0] = 1200.
    self.pbins = np.zeros(self.nlevs+1,float)
    self.pbins[0:self.nlevs] = self.levs1
    self.pbins[self.nlevs] = self.levs2[-1]

    for nlev in range(18, self.nlevs):
        self.levs[nlev] = 0.5*( self.levs1[nlev]+ self.levs2[nlev])

  def process(self, datapath, outfile):
    ncout = Dataset(outfile+'.nc', 'w')

    plevs = ncout.createDimension('plevs',len(self.levs))
    times = ncout.createDimension('time',len(self.dates))
    plevs = ncout.createVariable('plevs',float,'plevs')
    plevs_up = ncout.createVariable('plevs_up',float,'plevs')
    plevs_down = ncout.createVariable('plevs_down',float,'plevs')
    plevs_up[:] = self.levs2
    plevs_down[:] = self.levs1
    plevs[:] = self.levs
    plevs.units = 'hPa'
    times = ncout.createVariable('times',np.float64,'time')
    times.units = 'hours since 1970-01-01'
    omf_wnd = ncout.createVariable('omf_rmswind',float, ('time','plevs'))
    omf_temp = ncout.createVariable('omf_rmstemp',float, ('time','plevs'))
    omf_tempb = ncout.createVariable('omf_biastemp',float, ('time','plevs'))
    temp_obcounts = ncout.createVariable('temp_obcounts',int, ('time','plevs'))
    wind_obcounts = ncout.createVariable('wind_obcounts',int, ('time','plevs'))

    omf_humid = ncout.createVariable('omf_rmshumid',float, ('time','plevs'))
    humid_obcounts = ncout.createVariable('humid_obcounts',int, ('time','plevs'))

    rms_wind = np.zeros(len(self.levs),float)
    rms_temp = np.zeros(len(self.levs),float)
    rms_humid = np.zeros(len(self.levs),float)

    bias_temp = np.zeros(len(self.levs),float)
    bias_humid = np.zeros(len(self.levs),float)

    count_temp = np.zeros(len(self.levs),int)
    count_humid = np.zeros(len(self.levs),int)
    count_wind = np.zeros(len(self.levs),int)

    rms_wind_meantot = []
    rms_temp_meantot = []
    rms_humid_meantot = []

    hours = []
    for date in self.dates:
      h = cal_datetohrs(date)
      hours.append(h)
   #times[:] = hours

    ndate = 0
    for date in self.dates:
      times[ndate] = cal_datetohrs(date)
      if self.runid != '': 
        obsfile_uv = os.path.join(datapath,'%s/diag_conv_uv_ges.%s_%s.nc4' % (date,date,runid))
        obsfile_t  = os.path.join(datapath,'%s/diag_conv_t_ges.%s_%s.nc4' % (date,date,runid))
        obsfile_q  = os.path.join(datapath,'%s/diag_conv_q_ges.%s_%s.nc4' % (date,date,runid))
      else:
        obsfile_uv = os.path.join(datapath,'%s/diag_conv_uv_ges.%s.nc4' % (date,date))
        obsfile_t  = os.path.join(datapath,'%s/diag_conv_t_ges.%s.nc4' % (date,date))
        obsfile_q  = os.path.join(datapath,'%s/diag_conv_q_ges.%s.nc4' % (date,date))

      nc_uv = Dataset(obsfile_uv)
      nc_t = Dataset(obsfile_t)
      nc_q = Dataset(obsfile_q)

      uv_code = nc_uv['Observation_Type'][:]
      t_code = nc_t['Observation_Type'][:]
      q_code = nc_q['Observation_Type'][:]
      uv_used = nc_uv['Analysis_Use_Flag'][:]
      t_used = nc_t['Analysis_Use_Flag'][:]
      q_used = nc_q['Analysis_Use_Flag'][:]
      uv_oberrinv = nc_uv['Errinv_Final'][:]
      t_oberrinv = nc_t['Errinv_Final'][:]
      q_oberrinv = nc_q['Errinv_Final'][:]
      uv_press = nc_uv['Pressure'][:]
      t_press = nc_t['Pressure'][:]
      q_press = nc_q['Pressure'][:]
      uv_lon = nc_uv['Longitude'][:]
      t_lon = nc_t['Longitude'][:]
      q_lon = nc_q['Longitude'][:]
      uv_lat = nc_uv['Latitude'][:]
      t_lat = nc_t['Latitude'][:]
      q_lat = nc_q['Latitude'][:]
      omf_u = nc_uv['u_Obs_Minus_Forecast_unadjusted'][:]
      omf_v = nc_uv['v_Obs_Minus_Forecast_unadjusted'][:]
      #omf_t = nc_t['Obs_Minus_Forecast_unadjusted'][:]
      #omf_q = nc_q['Obs_Minus_Forecast_unadjusted'][:]
      omf_t = nc_t['Obs_Minus_Forecast_adjusted'][:]
      omf_q = nc_q['Obs_Minus_Forecast_adjusted'][:]
      qsges = nc_q['Forecast_Saturation_Spec_Hum'][:]

      if self.sondesonly:
        insitu_wind = np.logical_or(uv_code == 220, # sondes
                                    uv_code == 232) # drops
        insitu_wind = np.logical_or(insitu_wind, uv_code == 221) # pibals
      elif aironly:
        insitu_wind = np.logical_and(uv_code >= 230, uv_code <= 235)
      elif noair:
        insitu_wind = np.logical_and(uv_code >= 280, uv_code <= 282) #sfc
       #sones, pibals
        insitu_wind = np.logical_or(insitu_wind,\
                      np.logical_or(uv_code == 220, uv_code == 221)) 
        insitu_wind = np.logical_or(insitu_wind, uv_code == 232) # drops
      else:
        insitu_wind = np.logical_and(uv_code >= 280, uv_code <= 282) #sfc
       # sones, pibals
        insitu_wind = np.logical_or(insitu_wind,\
                      np.logical_or(uv_code == 220, uv_code == 221)) 
       #print 'sondes,pibals',np.logical_and(uv_code >= 220, uv_code <= 221).sum()
       # aircraft, drops
        insitu_wind = np.logical_or(insitu_wind,\
                       np.logical_and(uv_code >= 230, uv_code <= 235))
       #print 'aircraft,drops',np.logical_and(uv_code >= 230, uv_code <= 235).sum()
       #print 'drops',(uv_code == 232).sum()
  
      if self.sondesonly:
        insitu_temp = np.logical_or(t_code == 120, # sondes
                                    t_code == 132) # drops
        insitu_q = np.logical_or(q_code == 120, # sondes
                                 q_code == 132) # drops
      elif aironly:
        insitu_temp = np.logical_and(t_code >= 130, t_code <= 135)
        insitu_q = np.logical_and(q_code >= 130, q_code <= 135)
      elif noair:
        insitu_temp = np.logical_or(t_code == 120, # sondes
                                    t_code == 132) # drops
        insitu_q = np.logical_or(q_code == 120, # sondes
                                 q_code == 132) # drops
        insitu_temp = np.logical_or(insitu_temp,np.logical_and(t_code >= 180, t_code <= 182)) #sfc
        insitu_q = np.logical_or(insitu_q,np.logical_and(q_code >= 180, q_code <= 182)) #sfc
      else:
        insitu_temp = np.logical_and(t_code >= 180, t_code <= 182) #sfc
        insitu_temp = np.logical_or(insitu_temp, t_code==120) # sondes
        # aircraft, drops
        insitu_temp = np.logical_or(insitu_temp,\
                      np.logical_and(t_code >= 130, t_code <= 135))
        insitu_q = np.logical_and(q_code >= 180, q_code <= 182) #sfc
        insitu_q = np.logical_or(insitu_q, q_code==120) # sondes
        # aircraft, drops
        insitu_q = np.logical_or(insitu_q,\
                   np.logical_and(q_code >= 130, q_code <= 135))

     # consider this of if used flag is 1, inverse oberr is < 1.e-5 and a valid pressure level is included
      #uv_used = np.logical_and(uv_used == 1, uv_oberrinv > 1.e-5)
      uv_used = uv_used == 1
      uv_used = np.logical_and(uv_used, np.isfinite(uv_press))
      insitu_wind = np.logical_and(insitu_wind,uv_used)
      #t_used = np.logical_and(t_used == 1, t_oberrinv > 1.e-5)
      t_used = t_used == 1
      t_used = np.logical_and(t_used, np.isfinite(t_press))
      insitu_temp = np.logical_and(insitu_temp,t_used)
      #q_used = np.logical_and(q_used == 1, q_oberrinv > 1.e-5)
      q_used = q_used == 1
      q_used = np.logical_and(q_used, np.isfinite(q_press))
      insitu_q = np.logical_and(insitu_q,q_used)

      if self.hem == 'NH':
        uv_latcond = uv_lat > self.latbound 
        t_latcond = t_lat > self.latbound 
        q_latcond = q_lat > self.latbound 
      elif self.hem == 'SH':
        uv_latcond = uv_lat < -self.latbound
        t_latcond = t_lat < -self.latbound
        q_latcond = q_lat < -self.latbound
      elif self.hem == 'TR':
        uv_latcond = np.logical_and(uv_lat <= self.latbound,uv_lat >= -self.latbound)
        t_latcond = np.logical_and(t_lat <= self.latbound,t_lat >= -self.latbound)
        q_latcond = np.logical_and(q_lat <= self.latbound,q_lat >= -self.latbound)

      if self.hem in ['NH','TR','SH']:
        indxuv = np.logical_and(insitu_wind,uv_latcond)
        indxt = np.logical_and(insitu_temp,t_latcond)
        indxq = np.logical_and(insitu_q,q_latcond)
      else:
        indxuv = insitu_wind
        indxt = insitu_temp
        indxq = insitu_q

      omf_u = omf_u[indxuv]
      omf_v = omf_v[indxuv]
      omf_t = omf_t[indxt]
      omf_q = 100.*omf_q[indxq]*qsges[indxq] # convert to g/kg?
      press_u = uv_press[indxuv]
      press_t = t_press[indxt]
      press_q = q_press[indxq]

      # compute innovation stats for temperature.
      pindx =  np.digitize(press_t,self.pbins)-1
      # check on pindx calculation
      #for n in range(len(press_t)):
      #    ip = pindx[n]
      #    p = press_t[n]
      #    if not (p < levs1[ip] and p >= levs2[ip]):
      #        print p, levs2[ip], levs1[ip]
      #        raise IndexError('wind p mismatch')

     #print('press_t = ', press_t)
     #print('pindx = ', pindx)
     #print('self.pbins = ', self.pbins)

      rms_temp += np.bincount(pindx,minlength=self.nlevs,weights=omf_t**2)
      counts, bin_edges = np.histogram(press_t,self.pbins[::-1])
      omf_temp[ndate] = np.bincount(pindx,minlength=self.nlevs,weights=omf_t**2)/counts[::-1]
      omf_tempb[ndate] = np.bincount(pindx,minlength=self.nlevs,weights=omf_t)/counts[::-1]
      temp_obcounts[ndate] = counts[::-1]
      bias_temp += np.bincount(pindx,minlength=self.nlevs,weights=omf_t)
      nobs_temp =  np.where(counts[::-1] == -1, 0, counts[::-1]).sum()
      count_temp += counts[::-1]
      rms_temp_mean = np.sqrt(np.bincount(pindx,minlength=self.nlevs,weights=omf_t**2)/counts[::-1])[0:18].mean()

     #print('indxq = ', indxq)
     #print('self.nlevs = ', self.nlevs)

      # compute innovation stats for humidity.
      if sum(indxq) > 0:
        pindx =  np.digitize(press_q,self.pbins)-1
        # check on pindx calculation
        #for n in range(len(press_q)):
        #    ip = pindx[n]
        #    p = press_q[n]
        #    if not (p < levs1[ip] and p >= levs2[ip]):
        #        print p, levs2[ip], levs1[ip]
        #        raise IndexError('wind p mismatch')
        rms_humid += np.bincount(pindx,minlength=self.nlevs,weights=omf_q**2)
        bias_humid += np.bincount(pindx,minlength=self.nlevs,weights=omf_q)
        counts, bin_edges = np.histogram(press_q,self.pbins[::-1])
        counts = np.where(counts == 0, -1, counts)
        nobs_humid =  np.where(counts[::-1] == -1, 0, counts[::-1]).sum()
        count_humid += counts[::-1]
        rms_humid_mean = np.sqrt(np.bincount(pindx,minlength=self.nlevs,weights=omf_q**2)/counts[::-1])[0:18].mean()
        omf_humid[ndate] = np.bincount(pindx,minlength=self.nlevs,weights=omf_q**2)/counts[::-1]
        humid_obcounts[ndate] = counts[::-1]
      else:
        rms_humid_mean = np.zeros(rms_temp_mean.shape, rms_temp_mean.dtype)

      # compute innovation stats for wind.
      pindx =  np.digitize(press_u,self.pbins)-1
      # check on pindx calculation
      #for n in range(len(press_u)):
      #    ip = pindx[n]
      #    p = press_u[n]
      #    if not (p < levs1[ip] and p >= levs2[ip]):
      #        print p, levs2[ip], levs1[ip]
      #        raise IndexError('wind p mismatch')
      rms_wind += np.bincount(pindx,minlength=self.nlevs,weights=np.sqrt(omf_u**2+omf_v**2))
      counts, bin_edges = np.histogram(press_u,self.pbins[::-1])
      omf_wnd[ndate] = np.bincount(pindx,minlength=self.nlevs,weights=np.sqrt(omf_u**2+omf_v**2))/counts[::-1]
      wind_obcounts[ndate] = counts[::-1]
      nobs_uv =  np.where(counts[::-1] == -1, 0, counts[::-1]).sum()
      count_wind += counts[::-1]
      rms_wind_mean = (np.bincount(pindx,minlength=self.nlevs,weights=np.sqrt(omf_u**2+omf_v**2))/counts[::-1])[0:18].mean()
      rms_wind_meantot.append(rms_wind_mean)
      rms_temp_meantot.append(rms_temp_mean)
      rms_humid_meantot.append(rms_humid_mean)
      print(date, nobs_uv, rms_wind_mean, nobs_temp, rms_temp_mean, nobs_humid, rms_humid_mean)
      ndate += 1
  
    ncout.close()

    rms_wind = rms_wind/count_wind
    rms_temp = np.sqrt(rms_temp/count_temp)
    bias_temp = bias_temp/count_temp
    rms_humid = np.sqrt(rms_humid/count_humid)
    bias_humid = bias_humid/count_humid
    rms_wind_mean = np.nanmean(np.array(rms_wind_meantot))
    rms_temp_mean = np.nanmean(np.array(rms_temp_meantot))
    rms_humid_mean = np.nanmean(np.array(rms_humid_meantot))

    fout = open(outfile,'w')
    fout.write('# %s %s %s %s-%s\n' % (datapath,self.runid,self.hem,self.sdate,self.edate))
    fout.write('# press wind_count wind_rms temp_count temp_rms temp_bias humid_rmsx1000 humid_biasx1000\n')
    fout.write('# 1000-0 %10i %7.4f %10i %7.4f %7.4f %10i %7.4f %7.4f\n' % (count_wind.sum(), rms_wind.mean(), count_temp.sum(), rms_temp.mean(), bias_temp.mean(), count_humid.sum(), 1000*rms_humid.mean(), 1000*bias_humid.mean()))
    for n,p in enumerate(self.levs):
        fout.write('%8.2f %10i %7.4f %10i %7.4f %7.4f %10i %7.4f %7.4f\n' % (p,count_wind[n],rms_wind[n],count_temp[n],rms_temp[n],bias_temp[n],count_humid[n],1000*rms_humid[n],1000*bias_humid[n]))
    fout.write('#  %7.4f %7.4f %7.4f\n' % (rms_wind_mean,rms_temp_mean,1000.*rms_humid_mean))
    fout.close()

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  output = 0

  interval = 12
  sdate = '2020010112'
  edate = '2020010218'
  dir1 = 'gsi_C96_lgetkf_sondesonly'
  dir2 = 'gdas-cycling'
  datadir = '/work2/noaa/da/weihuang/cycling'
  runid = 'ensmean'
  hem = 'NH'

  sondesonly=True,
  noair=False
  aironly=False
  latbound=30

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'output=', 'sdate=', 'edate=',
                                                'datadir=', 'runid=', 'hem=',
                                                'dir1=', 'dir2=', 'interval=',
                                                'lbl1=', 'lbl2='])
  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--output'):
      output = int(a)
    elif o in ('--sdate'):
      sdate = a
    elif o in ('--edate'):
      edate = a
    elif o in ('--datadir'):
      datadir = a
    elif o in ('--runid'):
      runid = a
    elif o in ('--hem'):
      hem = a
    elif o in ('--dir1'):
      dir1 = a
    elif o in ('--dir2'):
      dir2 = a
    elif o in ('--interval'):
      interval = int(a)
    elif o in ('--lbl1'):
      lbl1 = a
    elif o in ('--lbl2'):
      lbl2 = a
    else:
      assert False, 'unhandled option'

#-----------------------------------------------------------------------------------------

  dof = DiagObFit(debug=debug, output=output, sdate=sdate, edate=edate,
                  runid=runid, hem=hem, sondesonly=sondesonly, interval=interval,
                  noair=noair, aironly=aironly, latbound=latbound)

  lbllist = [lbl1, lbl2]
  dirlist = [dir1, dir2]
  for n in range(len(dirlist)):
    datapath = '%s/%s' %(datadir, dirlist[n])
    outfile = 'stats_%s' %(lbllist[n])
    dof.process(datapath, outfile)


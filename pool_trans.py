#=========================================================================
import getopt
import os, sys, time
import netCDF4 as nc4

from multiprocessing import Pool

#--------------------------------------------------------------------------------
def transJEDI2GSIincrements(jedifile, gsi_file, newfile, debug):
  ncjedi = nc4.Dataset(jedifile, 'r')
  nc_gsi = nc4.Dataset(gsi_file, 'r')
  nc4out = nc4.Dataset(newfile, 'w')

  if(debug):
    print('Converting file: ', jedifile)

 #-----------------------------------------------------------------------------------------
  gsibaselist = ['lon', 'lat', 'lev', 'ilev', 'hyai', 'hybi']

 #copy global attributes all at once via dictionary
 #nc4out.setncatts(nc_gsi.__dict__)
  nc4out.source='JEDI getkf increment'
  nc4out.comment = 'Converted JEDI increment to GSI increment'

 #copy dimensions
  for name, dimension in nc_gsi.dimensions.items():
   #nc4out.createDimension(name, (len(dimension) if not dimension.isunlimited() else None))
    if dimension.isunlimited():
      nc4out.createDimension(name, None)
    else:
      nc4out.createDimension(name, len(dimension))

 #copy all var in gsibaselist
  for name, variable in nc_gsi.variables.items():
    if name in gsibaselist:
      x = nc4out.createVariable(name, variable.datatype, variable.dimensions)
      nc4out.variables[name][:] = nc_gsi.variables[name][:]
     #copy variable attributes all at once via dictionary
      nc4out.variables[name].setncatts(nc_gsi.variables[name].__dict__)

 #-----------------------------------------------------------------------------------------
  jedi_varlist = ['DZ', 'delp', 'o3mr', 'sphum', 'T', 'ua', 'va']
  gsi_varlist = ['delz_inc', 'delp_inc', 'o3mr_inc',
                 'sphum_inc', 'T_inc', 'u_inc', 'v_inc']

  numvar = len(jedi_varlist)

 #copy all var in gsi_varlist
  for name, variable in nc_gsi.variables.items():
    if name in gsi_varlist:
      for n in range(numvar):
        gsivarname = gsi_varlist[n]
        if(name == gsivarname):
          jedivarname = jedi_varlist[n]
         #print('\tjedivarname: %s, gsivarname: %s ' %(jedivarname, gsivarname))

          x = nc4out.createVariable(name, variable.datatype, variable.dimensions)
          var = ncjedi.variables[jedivarname][0,:,:,:]
          nc4out.variables[name][:,:,:] = var
         #copy variable attributes all at once via dictionary
          nc4out.variables[name].setncatts(nc_gsi.variables[name].__dict__)

  ncjedi.close()
  nc_gsi.close()
  nc4out.close()

def multi_run_wrapper(args):
  transJEDI2GSIincrements(*args)

#--------------------------------------------------------------------------------
if __name__ == '__main__':
  tstart = time.time()

 #--------------------------------------------------------------------------------
  debug = 1
  poolsize = 40
  totalmembers = 80
  datestr = '2020010200'
  jedidir = '/work2/noaa/gsienkf/weihuang/gsi/jedi_C96_lgetkf_sondesonly'
  gsifile = '/work2/noaa/gsienkf/weihuang/production/run/transform/fv3_increment6.nc'

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'poolsize=', 'jedidir=',
                                                'gsifile=', 'datestr=',
                                                'poolsize=', 'totalmembers='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--gsifile'):
      gsifile = a
    elif o in ('--jedidir'):
      jedidir = a
    elif o in ('--datestr'):
      datestr = a
    elif o in ('--poolsize'):
      poolsize = int(a)
    elif o in ('--totalmembers'):
      totalmembers = int(a)
    else:
      assert False, 'unhandled option'

 #--------------------------------------------------------------------------------
  optlist = []
  ymd = datestr[0:8]
  hour = datestr[8:10]
  ensdir = '%s/%s/Data/ens' %(jedidir, datestr)
  for n in range(totalmembers):
    jedifile = '%s/mem%3.3d/getkf.increment.%s_%s0000z.nc4' %(ensdir, n+1, ymd, hour)
    newfile = '%s/mem%3.3d/fv3_increment6.nc' %(ensdir, n+1)
    opt = (jedifile, gsifile, newfile, debug)
    optlist.append(opt)

 #--------------------------------------------------------------------------------
 #print('optlist: ', optlist)
  pool = Pool(poolsize)
  pool.map(multi_run_wrapper, optlist)
  pool.close()

 #--------------------------------------------------------------------------------
  tend = time.time()

  print('pool_trans.py done in {:.4f} seconds'.format(tend-tstart))


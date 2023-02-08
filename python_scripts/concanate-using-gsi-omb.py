#=========================================================================
import os
import sys
import getopt
import netCDF4 as nc4
import time
import numpy as np

#-----------------------------------------------------------------------------------------
def average(vlist):
  buf = np.zeros_like(vlist[0])
  nmem = len(vlist)
  for n in range(1, nmem):
    buf += vlist[n]
  buf /= (nmem-1)
  return buf

#-----------------------------------------------------------------------------------------
def copy_dimension(ncin, ncout):
 #copy dimensions
  for name, dimension in ncin.dimensions.items():
   #ncout.createDimension(name, (len(dimension) if not dimension.isunlimited() else None))
    if dimension.isunlimited():
      ncout.createDimension(name, None)
    else:
      ncout.createDimension(name, len(dimension))

#-----------------------------------------------------------------------------------------
def copy_attributes(ncin, ncout):
 #copy the global attributes to the new file
  inattrs = ncin.ncattrs()
  for attr in inattrs:
    if('_FillValue' != attr):
      ncout.setncattr(attr, ncin.getncattr(attr))

#-----------------------------------------------------------------------------------------
def copy_rootvar(ncin, ncout):
 #copy all var in root group.
  for name, variable in ncin.variables.items():
    ncout.createVariable(name, variable.datatype, variable.dimensions)
   #copy variable attributes all at once via dictionary
    ncout[name].setncatts(ncin[name].__dict__)
    ncout[name][:] = ncin[name][:]

#-----------------------------------------------------------------------------------------
def copy_var_in_group(ncingroup, ncoutgroup):
  fvname = '_FillValue'
 #copy all var in group.
  for varname, variable in ncingroup.variables.items():
    if(fvname in variable.__dict__):
      fill_value = variable.getncattr(fvname)
      newvar = ncoutgroup.createVariable(varname, variable.datatype, variable.dimensions, fill_value=fill_value)
    else:
      newvar = ncoutgroup.createVariable(varname, variable.datatype, variable.dimensions)
    copy_attributes(variable, newvar)
    newvar[:] = ncingroup[varname][:]

#-----------------------------------------------------------------------------------------
def copy_grp2newname(name, n, group, ncout):
  item = name.split('_')
  item[-1] = '%d' %(n)
  newname = '_'.join(item)
  print('No %d name: %s, newname: %s' %(n, name, newname))
  ncoutgroup = ncout.createGroup(newname)
  copy_var_in_group(group, ncoutgroup)

#-----------------------------------------------------------------------------------------
def process(ncgsi, ncinlist, ncout, grplist):
  grpnamelist = []
  hofxgrps = []
  commongrps = []
  ensvarinfo = {}

 #check groups
  for grpname, group in ncinlist[0].groups.items():
    print('grpname: ', grpname)
    grpnamelist.append(grpname)
    if(grpname in grplist):
      ensvarinfo[grpname] = {}
      if(grpname == 'hofx0_1'):
        for varname, variable in group.variables.items():
         #val = group[varname][:]
          ensvarinfo[grpname][varname] = []
         #ensvarinfo[grpname][varname].append(val)
      else:
        if(grpname == 'hofx_y_mean_xb0'):
          ncoutgroup = ncout.createGroup(grpname)
          copy_var_in_group(group, ncoutgroup)

        for varname, variable in group.variables.items():
          val = group[varname][:]
          ensvarinfo[grpname][varname] = val
    else:
      if(grpname.find('hofx') < 0):
        commongrps.append(grpname)
        ncoutgroup = ncout.createGroup(grpname)
        copy_var_in_group(group, ncoutgroup)
      else:
        hofxgrps.append(grpname)

  print('len(grpnamelist) = %d, len(commongrps) = %d, len(hofxgrps) = %d' %(len(grpnamelist), len(commongrps), len(hofxgrps)))

  grpname = 'hofx0_1'
  for n in range(1, len(ncinlist)):
    ncin = ncinlist[n]
    for name in hofxgrps:
      group = ncin.groups[name]
      copy_grp2newname(name, n, group, ncout)

    group = ncin.groups[grpname]
    copy_grp2newname(grpname, n, group, ncout)

    for varname, variable in group.variables.items():
      val = group[varname][:]
      ensvarinfo[grpname][varname].append(val)

  varlist = ensvarinfo['hofx0_1'].keys()
 #print('varlist = ', varlist)
  meanvars = {}
  ncoutgroup = ncout.createGroup(grpname)
  for varname in varlist:
    meanval = average(ensvarinfo[grpname][varname])
    print('get avearge for varname = ', varname)
   #print('meanval.shape = ', meanval.shape)
   #print('meanval.size = ', meanval.size)
    meanvars[varname] = meanval

  grpname = 'ombg'
  ncingroup = ncinlist[0].groups[grpname]
  ncoutgroup = ncout.createGroup(grpname)
  fvname = '_FillValue'
 #copy all var in group.
  for varname, variable in ncingroup.variables.items():
    if(fvname in variable.__dict__):
      fill_value = variable.getncattr(fvname)
      newvar = ncoutgroup.createVariable(varname, variable.datatype, variable.dimensions, fill_value=fill_value)
    else:
      newvar = ncoutgroup.createVariable(varname, variable.datatype, variable.dimensions)
    copy_attributes(variable, newvar)

    gsihofx = ncgsi.groups['GsiHofX'][varname][:]
    gsiobsv = ncgsi.groups['ObsValue'][varname][:]

    print('\tgsihofx.max: %f, gsihofx.min: %f' %(np.max(gsihofx), np.min(gsihofx)))
    print('\tgsiobsv.max: %f, gsiobsv.min: %f' %(np.max(gsiobsv), np.min(gsiobsv)))

    val = gsiobsv - gsihofx

    print('\tombg.max: %f, ombg.min: %f' %(np.max(val), np.min(val)))
    newvar[:] = val[:]

#-----------------------------------------------------------------------------------------
def replace_var(gsifile, filelist, outfile, grplist):
  ncinlist = []
  for infile in filelist:
    if(os.path.exists(infile)):
     #print('infile: ', infile)
      ncin = nc4.Dataset(infile, 'r')
      ncinlist.append(ncin)
    else:
      print('infile: %s does not exist.' %(infile))
      sys.exit(-1)

  if(os.path.exists(outfile)):
    os.remove(outfile)
    print('outfile: ', outfile)
 #else:
 #  print('outfile: %s does not exist.' %(outfile))

  if(os.path.exists(gsifile)):
    print('gsifile: ', gsifile)
  else:
    print('gsifile: %s does not exist.' %(gsifile))
    sys.exit(-1)

  print('len(ncinlist) = ', len(ncinlist))

  ncgsi = nc4.Dataset(gsifile, 'r')
  ncout = nc4.Dataset(outfile, 'w')

 #copy global attributes all at once via dictionary
 #ncout.setncatts(ncin.__dict__)
  ncout.source='JEDI observer only ouptut, each with only one member'
  ncout.comment = 'updated variable hofx_y_mean_xb0 and ombg from all observer files'

 #copy attributes
  for name in ncinlist[0].ncattrs():
    ncout.setncattr(name, ncinlist[0].getncattr(name))

  copy_dimension(ncinlist[0], ncout)
  copy_rootvar(ncinlist[0], ncout)

  process(ncgsi, ncinlist, ncout, grplist)
 
  ncgsi.close()
  for ncin in ncinlist:
    ncin.close()
  ncout.close()

#-----------------------------------------------------------------------------------------
debug = 1
nmem = 81

run_dir = '/work2/noaa/gsienkf/weihuang/production/run/sondes/run_81.36t9n'
datestr = '2020010112'
varname = 'sondes_tsen'

#-----------------------------------------------------------------------------------------
opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'run_dir=',
                                              'datestr=', 'varname=', 'nmem='])
for o, a in opts:
  if o in ('--debug'):
    debug = int(a)
  elif o in ('--run_dir'):
    run_dir = a
  elif o in ('--datestr'):
    datestr = a
  elif o in ('--varname'):
    varname = a
  elif o in ('--nmem'):
    nmem = int(a)
  else:
    assert False, 'unhandled option'

#-----------------------------------------------------------------------------------------
grplist = ['hofx_y_mean_xb0', 'hofx0_1', 'ombg']
filelist = []
for n in range(nmem):
  flnm = '%s/observer/mem%3.3d/%s_obs_%s_0000.nc4' %(run_dir, n, varname, datestr)
  filelist.append(flnm)
gsifile = '%s/ioda_v2_data/%s_obs_%s.nc4' %(run_dir, varname, datestr)
outfile = '%s/observer/%s_obs_%s_0000.nc4' %(run_dir, varname, datestr)

replace_var(gsifile, filelist, outfile, grplist)


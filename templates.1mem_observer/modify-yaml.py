import getopt
import os, sys

#--------------------------------------------------------------------------------
def process_file(in_flnm, OF, obstype):
  obs_filters = 0
  with open(in_flnm) as fp:
    lines = fp.readlines()
    num_lines = len(lines)
    print('Total number of lines: ', num_lines)

    OF.write('  - obs space:\n')
   #OF.write('    name: abi_g16_bt_64km\n')
    OF.write('    name: %s\n' %(obstype))
    OF.write('    distribution:\n')
    OF.write('      name: RoundRobin\n')
    OF.write('    io pool:\n')
    OF.write('      max pool size: 1\n')
    OF.write('    obsdatain:\n')
    OF.write('      engine:\n')
    OF.write('        type: H5File\n')
    OF.write('        obsfile: ioda_v2_data/%s_obs_YYYYMMDDHH.nc4\n' %(obstype))
    OF.write('    obsdataout:\n')
    OF.write('      engine:\n')
    OF.write('        type: H5File\n')
    OF.write('        obsfile: obsout/%s_obs_YYYYMMDDHH.nc4\n' %(obstype))
    OF.write('        allow overwrite: true\n')

    nl = 9
   #nl = 11
    while(nl < num_lines):
      print('Line %d: %s' %(nl, lines[nl]))
      OF.write('    %s' %(lines[nl]))
      nl += 1
    OF.write('    obs localizations:\n')
    OF.write('    - localization method: Horizontal Gaspari-Cohn\n')
    OF.write('      lengthscale: 1250e3\n')
    OF.write('      max nobs: 10000\n')

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  srcdir = '/work2/noaa/gsienkf/weihuang/production2/src/fv3-bundle/ufo/ewok/skylab'
 #obstype = 'amsua_aqua'
 #obstype = 'abi_g16'
  obstype = 'amsua_metop-a'

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'srcdir=', 'obstype='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--obstype'):
      obstype = a
    else:
      assert False, 'unhandled option'

  iflnm = '%s/%s.yaml' %(srcdir, obstype)
 #iflnm = '%s/%s_bt_64km.yaml' %(srcdir, obstype)
  oflnm = '%s.obs.yaml.template.rr.observer' %(obstype)

  OF = open(oflnm, 'w')
  process_file(iflnm, OF, obstype)
  OF.write('\n')
  OF.close()


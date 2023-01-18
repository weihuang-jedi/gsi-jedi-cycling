import getopt
import os, sys

#--------------------------------------------------------------------------------
def process_file(in_flnm, OF, obstype, obskind):
  obs_filters = 0
  with open(in_flnm) as fp:
    lines = fp.readlines()
    num_lines = len(lines)
    print('Total number of lines: ', num_lines)

    no = 0
    nl = 0
    while(nl < num_lines):
      print('Line %d: %s' %(nl, lines[nl]))
      if(nl < 1):
        oline = '  - %s' %(lines[nl])
      else:
        if(lines[nl].find('obsfile: ') > 0):
          if(no < 1):
            oline = '          obsfile: ioda_v2_data/%s_%s_obs_YYYYMMDDHH.nc4\n' %(obstype, obskind)
          else:
            oline = '          obsfile: obsout/MEMSTR/%s_%s_obs_YYYYMMDDHH.nc4\n' %(obstype, obskind)
          no += 1
        else:
          if(lines[nl].find('obs filters:') > 0):
            obs_filters = 1
          if(obs_filters):
            oline = '  %s' %(lines[nl])
          else:
            oline = '    %s' %(lines[nl])
      OF.write(oline)
      nl += 1
    OF.write('    obs localizations:\n')
    OF.write('    - localization method: Horizontal Gaspari-Cohn\n')
    OF.write('      lengthscale: 1250e3\n')
    OF.write('      max nobs: 10000\n')

#--------------------------------------------------------------------------------
if __name__== '__main__':
  debug = 1
  obstype = 'aircraft'

  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'obstype='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--obstype'):
      obstype = a
    else:
      assert False, 'unhandled option'

  iflnm = 'gdas-obs-config/%s.yaml' %(obstype)
  oflnm = '%s.obs.yaml.template.rr.observer' %(obstype)

  OF = open(oflnm, 'w')
  for obskind in ['tsen', 'uv', 'q']:
    process_file(iflnm, OF, obstype, obskind)
    OF.write('\n')
  OF.close()


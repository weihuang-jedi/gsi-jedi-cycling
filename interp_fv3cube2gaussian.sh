#!/bin/sh
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh

module list

export VERBOSE=${VERBOSE:-"NO"}
hydrostatic=${hydrostatic:=".false."}
launch_level=$(echo "$LEVS/2.35" |bc)
if [ $VERBOSE = "YES" ]; then
 set -x
fi

ulimit -s unlimited

source ${datapath}/analdate.sh

# yr,mon,day,hr at middle of assim window (analysis time)
export year=`echo $analdate |cut -c 1-4`
export month=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`

source ~/intelenv
#source /work2/noaa/gsienkf/weihuang/production/util/intelenv
#module rm python/3.9.2

interpsrcdir=/work2/noaa/gsienkf/weihuang/production/run/transform/interp_fv3cube2gaussian
prefix=${year}${month}${day}.${hour}0000.

workdir=${datapath}/${analdate}

cat > input.nml << EOF
&control_param
 generate_weights = .false.
 output_flnm = "interp2gaussian_grid.nc4"
 wgt_flnm = "${interpsrcdir}/gaussian_weights.nc4"
 indirname = "${workdir}/analysis/increment"
 outdirname = "${workdir}/Data/ens"
 has_prefix = .true.
 prefix = "${prefix}"
 use_gaussian_grid = .true.
 gaussian_grid_file = "${interpsrcdir}/gaussian_grid.nc4"
 nlon = 384
 nlat = 192
 nlev = 127
 nilev = 128
 npnt = 4
 total_members = 80
 num_types = 2
 data_types = 'fv_core.res.tile', 'fv_tracer.res.tile',
/
EOF

export OMP_NUM_THREADS=1
export "PGM=${executable} getkf.yaml"
export corespernode=40
export mpitaskspernode=8
#nprocs=80 corespernode=40 mpitaskspernode=8 ${enkfscripts}/runmpi
nprocs=80
count=1
totnodes=10

srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \
  --exclusive --cpu-bind=cores --verbose ${interpsrcdir}/fv3interp.exe


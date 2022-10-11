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
source ~/.bashrc
source ~/intelenv
source ${datapath}/analdate.sh

# yr,mon,day,hr at middle of assim window (analysis time)
export year=`echo $analdate |cut -c 1-4`
export month=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`

source /work2/noaa/gsienkf/weihuang/production/util/intelenv

module rm python/3.9.2

#ioda-bundle build dir:
export blddir=/work2/noaa/gsienkf/weihuang/production/build/ioda-bundle
export PYTHONPATH=${blddir}/lib/python3.9/pyioda:$PYTHONPATH

#output dir.
output_dir=${datapath}/${analdate}/ioda_v2_data
mkdir -p ${output_dir}

#input file fir.
run_dir=${datapath}/${analdate}

temp_dir=${run_dir}/diag
mkdir -p ${temp_dir}
rm -rf ${temp_dir}/*
cd ${temp_dir}
cp ${run_dir}/diag_conv_* .
 
#Convert GSI diag 2 ioda2 format
python ${blddir}/bin/proc_gsi_ncdiag.py -o ${output_dir} ${temp_dir}

minute=0
second=0

ensdir=${run_dir}/Data/ens
incdir=${run_dir}/analysis/increment
mkdir -p ${ensdir}
cd ${ensdir}

 sed -e "s?SYEAR?${year}?g" \
     -e "s?SMONTH?${month}?g" \
     -e "s?SDAY?${day}?g" \
     -e "s?SHOUR?${hour}?g" \
     -e "s?SMINUTE?${minute}?g" \
     -e "s?SSECOND?${second}?g" \
     -e "s?EYEAR?${year}?g" \
     -e "s?EMONTH?${month}?g" \
     -e "s?EDAY?${day}?g" \
     -e "s?EHOUR?${hour}?g" \
     -e "s?EMINUTE?${minute}?g" \
     -e "s?ESECOND?${second}?g" \
     ${jeditemplatedir}/coupler.res.template > coupler.res

number_members=80
n=1
while [ $n -le $number_members ]
do
   if [ $n -lt 10 ]
   then
      member_str=mem00${n}
   elif [ $n -lt 100 ]
   then
      member_str=mem0${n}
   else
      member_str=mem${n}
   fi

   ln -sf ${run_dir}/${member_str}/INPUT ${member_str}
   cp ${ensdir}/coupler.res ${member_str}/.
   mkdir -p ${incdir}/${member_str}

   n=$(( $n + 1 ))
done

cd ..

for dir in crtm \
   fieldmetadata \
   fieldsets \
   fv3files \
   satbias \
   TauCoeff
do
   if [ ! \( -e "${dir}" \) ]
   then
      ln -sf ${jedidatadir}/$dir .
   fi
done

cd ${run_dir}

mkdir -p analysis/mean analysis/increment hofx obsout

nodes=6
NUMMEM=80
MYLAYOUT="5,8"
backgrounddatetime=${year}-${month}-${day}T${hour}:00:00Z
windowdatetime=`python ${enkfscripts}/setjedistartdate.py --year=${year} --month=${month} --day=${day} --hour=${hour} --intv=3`
echo "windowdatetime=$windowdatetime"
casename=sondes
READFROMDISK=false
UPDATEWITHGEOMETRY=false
RUNASOBSERVER=false
SAVEENSEMBLEINCREMENTS=false
MAXPOOLSIZE=1
DISTRIBUTION=' name: Halo'
HALOSIZE=' halo size: 1250e3'
yyyymmddhh=${year}${month}${day}${hour}
echo "yyyymmddhh=$yyyymmddhh"

sed -e "s?LAYOUT?${MYLAYOUT}?g" \
    -e "s?NUMBEROFMEMBERS?${NUMMEM}?g" \
    -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
    -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
    -e "s?READFROMDISK?${READFROMDISK}?g" \
    -e "s?SAVEENSEMBLEINCREMENTS?${SAVEENSEMBLEINCREMENTS}?g" \
    -e "s?UPDATEWITHGEOMETRY?${UPDATEWITHGEOMETRY}?g" \
    -e "s?RUNASOBSERVER?${RUNASOBSERVER}?g" \
    ${jeditemplatedir}/getkf.yaml.template > getkf.yaml

sed -e "s?YYYYMMDDHH?${yyyymmddhh}?g" \
    -e "s?DISTRIBUTION?${DISTRIBUTION}?g" \
    -e "s?HALOSIZE?${HALOSIZE}?g" \
    -e "s?MAXPOOLSIZE?${MAXPOOLSIZE}?" \
    ${jeditemplatedir}/${casename}.obs.yaml.template >> getkf.yaml

#export jediblddir=/work2/noaa/gsienkf/weihuang/production/build/fv3-bundle
export LD_LIBRARY_PATH=${jediblddir}/lib:$LD_LIBRARY_PATH
executable=$jediblddir/bin/fv3jedi_letkf.x

#--------------------------------------------------------------------------------------------
export OOPS_DEBUG=-11
export OOPS_TRACK=-11
#export OOPS_TRACE=1

export OMP_NUM_THREADS=1
export "PGM=${executable} getkf.yaml"
export corespernode=40
export mpitaskspernode=40
#nprocs=240 corespernode=40 mpitaskspernode=40 ${enkfscripts}/runmpi
nprocs=240
count=1
totnodes=6

srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \
  --exclusive --cpu-bind=cores --verbose $executable getkf.yaml

#if [ $? -ne 0 -o ! -s ${increment_file} ]; then
#  echo "problem creating ${increment_file}, stopping .."
#  exit 1
#fi
 
#python ${enkfscripts}/pool_trans.py \
#   --jedidir=${datapath} \
#   --datestr=${analdate} \
#   --gsifile=/work2/noaa/gsienkf/weihuang/production/run/transform/fv3_increment6.nc

#sh ${enkfscripts}/interp_fv3cube2gaussian.sh
interpsrcdir=/work2/noaa/gsienkf/weihuang/production/run/transform/interp_fv3cube2gaussian
prefix=${year}${month}${day}.${hour}0000.

workdir=${datapath}/${analdate}

cat > input.nml << EOF
&control_param
 generate_weights = .false.
 output_flnm = "fv3_increment6.nc"
 wgt_flnm = "${interpsrcdir}/gaussian_weights.nc4"
 indirname = "${workdir}/analysis/increment"
 outdirname = "${workdir}"
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

export mpitaskspernode=8
nprocs=80
totnodes=10

srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \
  --exclusive --cpu-bind=cores --verbose ${interpsrcdir}/fv3interp.exe

jedi_done=no

number_members=80
incrnumb=0
n=1
while [ $n -le $number_members ]
do
   if [ $n -lt 10 ]
   then
      member_str=mem00${n}
   elif [ $n -lt 100 ]
   then
      member_str=mem0${n}
   else
      member_str=mem${n}
   fi

   if [ -f ${run_dir}/${member_str}/INPUT/fv3_increment6.nc ]
   then
     incrnumb=$(( $incrnumb + 1 ))
   fi

   n=$(( $n + 1 ))
done

if [ $incrnumb -eq $number_members ]
then
  jedi_done=yes
fi

echo "$jedi_done" > ${run_dir}/logs/run_jedi.log


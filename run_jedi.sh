#!/bin/bash
# model was compiled with these 
echo "starting at `date`"
source $MODULESHOME/init/sh

set -x

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

#source /work2/noaa/gsienkf/weihuang/production/util/intelenv
source ~/intelenv

module rm python/3.9.2
module rm intelpython

module list

#ioda-bundle build dir:
export blddir=/scratch2/BMC/gsienkf/Wei.Huang/jedi/dev/ioda-bundle-build
export PYTHONPATH=${blddir}/lib/python3.7/pyioda:$PYTHONPATH

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
cd ${run_dir}
 
#Convert GSI diag 2 ioda2 format
python ${blddir}/bin/proc_gsi_ncdiag.py -o ${output_dir} ${temp_dir}

minute=0
second=0

ensdir=${run_dir}/Data/ens
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
casename=sondes
READFROMDISK=false
UPDATEWITHGEOMETRY=false
RUNASOBSERVER=false
SAVEENSEMBLEINCREMENTS=false
MAXPOOLSIZE=1
DISTRIBUTION=' name: Halo'
HALOSIZE=' halo size: 1250e3'
yyyymmddhh=${year}${month}${day}${hour}

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
export jediblddir=/scratch2/BMC/gsienkf/Wei.Huang/jedi/dev/build/intel
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
 
python ${enkfscripts}/pool_trans.py \
   --jedidir=${datapath} \
   --datestr=${analdate} \
   --gsifile=${enkfscripts}/fv3_increment6.nc

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


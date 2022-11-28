#!/bin/bash

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

   cp ${ensdatadir}/coupler.res ${member_str}/INPUT/.
   mkdir -p analysis/increment/${member_str}

   n=$(( $n + 1 ))
done

echo "cd ${run_dir}" >> ${run_dir}/logs/run_jedi.out

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

source ~/intelenv
export jediblddir=/work2/noaa/gsienkf/weihuang/production2/build/fv3-bundle
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

echo "srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \\" >> ${run_dir}/logs/run_jedi.out
echo "  --exclusive --cpu-bind=cores --verbose $executable getkf.yaml" >> ${run_dir}/logs/run_jedi.out
echo "srun: `which srun`" >> ${run_dir}/logs/run_jedi.out

srun -N $totnodes -n $nprocs --ntasks-per-node=$mpitaskspernode \
	$executable getkf.yaml

#srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \
#  --exclusive --cpu-bind=cores --verbose $executable getkf.yaml

#if [ $? -ne 0 -o ! -s ${increment_file} ]; then
#  echo "problem creating ${increment_file}, stopping .."
#  exit 1
#fi
 
interpsrcdir=/work2/noaa/gsienkf/weihuang/production/run/transform/interp_fv3cube2gaussian
prefix=${year}${month}${day}.${hour}0000.

workdir=${datapath}/${analdate}

echo "workdir: $workdir" >> ${run_dir}/logs/run_jedi.out

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

echo "srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \\" >> ${run_dir}/logs/run_jedi.out
echo "  --exclusive --cpu-bind=cores --verbose ${interpsrcdir}/fv3interp.exe" >> ${run_dir}/logs/run_jedi.out

srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \
  --exclusive --cpu-bind=cores --verbose ${interpsrcdir}/fv3interp.exe

#srun -N $totnodes -n $nprocs --ntasks-per-node=$mpitaskspernode \
#        ${interpsrcdir}/fv3interp.exe

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
echo "jedi_done = $jedi_done" >> ${run_dir}/logs/run_jedi.out
echo "run Jedi Ending at `date`" >> ${run_dir}/logs/run_jedi.out


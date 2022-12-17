#!/bin/sh
# model was compiled with these 
echo "run Jedi starting at `date`"
source $MODULESHOME/init/sh
source ~/intelenv

export VERBOSE=${VERBOSE:-"NO"}
hydrostatic=${hydrostatic:=".false."}
launch_level=$(echo "$LEVS/2.35" |bc)
#if [ $VERBOSE = "YES" ]; then
 set -x
#fi

source ${datapath}/analdate.sh
ulimit -s unlimited

# yr,mon,day,hr at middle of assim window (analysis time)
export year=`echo $analdate |cut -c 1-4`
export month=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`

export PROJ_LIB=/work2/noaa/gsienkf/weihuang/anaconda3/share/proj
export PYTHONPATH=/work/noaa/gsienkf/weihuang/jedi/vis_tools/xESMF/build/lib
export PYTHONPATH=/work2/noaa/gsienkf/weihuang/anaconda3/lib:$PYTHONPATH
export LD_LIBRARY_PATH=/work2/noaa/gsienkf/weihuang/anaconda3/lib:${LD_LIBRARY_PATH}
export PATH=/work2/noaa/gsienkf/weihuang/anaconda3/bin:${PATH}

#export iodablddir=/work2/noaa/gsienkf/weihuang/production2/build/ioda-bundle
export iodablddir=/work2/noaa/gsienkf/weihuang/jedi/build/ioda-bundle
export LD_LIBRARY_PATH=${iodablddir}/lib:$LD_LIBRARY_PATH
export PYTHONPATH=${iodablddir}/lib/python3.9/pyioda:$PYTHONPATH

echo "PYTHONPATH: $PYTHONPATH"

#input file fir.
run_dir=${datapath}/${analdate}

echo "run Jedi starting at `date`" > ${run_dir}/logs/run_jedi.out
module list >> ${run_dir}/logs/run_jedi.out

cd ${run_dir}
rm -rf ioda_v2_data diag
mkdir ioda_v2_data diag
cp diag_conv_* diag/.
module list
which python
echo "in run_dir: $${run_dir}" >> ${run_dir}/logs/run_jedi.out
echo "ls diag" >> ${run_dir}/logs/run_jedi.out
echo "`ls diag`" >> ${run_dir}/logs/run_jedi.out

python ${iodablddir}/bin/proc_gsi_ncdiag.py \
       -o ioda_v2_data diag

echo "ls ioda_v2_data" >> ${run_dir}/logs/run_jedi.out
echo "`ls ioda_v2_data`" >> ${run_dir}/logs/run_jedi.out

minute=0
second=0

ensdatadir=${run_dir}/Data
mkdir -p ${ensdatadir}
cd ${ensdatadir}

echo "cd ${ensdatadir}" >> ${run_dir}/logs/run_jedi.out

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

/work2/noaa/da/weihuang/cycling/scripts/jedi_C96_lgetkf_sondesonly/gen_ensmean.sh ${run_dir}

rm -rf analysis hofx obsout stdoutNerr observer solver
mkdir -p analysis/mean analysis/increment hofx obsout solver

number_members=80
n=0
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
yyyymmddhh=${year}${month}${day}${hour}

source ~/intelenv
export jediblddir=/work2/noaa/gsienkf/weihuang/production2/build/fv3-bundle
export LD_LIBRARY_PATH=${jediblddir}/lib:$LD_LIBRARY_PATH
executable=$jediblddir/bin/fv3jedi_letkf.x

#--------------------------------------------------------------------------------------------
#export OOPS_DEBUG=-11
#export OOPS_TRACK=-11
#export OOPS_TRACE=1

export OMP_NUM_THREADS=1
export corespernode=40
export mpitaskspernode=40
nprocs=240
count=1
totnodes=6

 echo "run observer"
 obstype=sondes
 MYLAYOUT="3,2"
 NODES=$SLURM_NNODES

 number_members=80
 n=0
 while [ $n -le $number_members ]
 do
   used_nodes=0
   while [ $used_nodes -lt $NODES ] && [ $n -le $number_members ]
   do
     used_nodes=$(( $used_nodes + 1 ))

     if [ $n -lt 10 ]
     then
       member_str=mem00${n}
     elif [ $n -lt 100 ]
     then
       member_str=mem0${n}
     else
       member_str=mem${n}
     fi

     mkdir -p analysis/increment/${member_str}
     mkdir -p obsout/${member_str}

sed -e "s?LAYOUT?${MYLAYOUT}?g" \
    -e "s?MEMSTR?${member_str}?g" \
    -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
    -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
    ${jeditemplatedir}/getkf.yaml.template.1member.rr.observer > obsout/getkf.yaml.observer.${member_str}

sed -e "s?YYYYMMDDHH?${yyyymmddhh}?g" \
    -e "s?MEMSTR?${member_str}?g" \
    ${jeditemplatedir}/${obstype}.obs.yaml.template.rr.observer >> obsout/getkf.yaml.observer.${member_str}

     mkdir -p obsout/${member_str}
     srun -N 1 -n 36 ${executable} obsout/getkf.yaml.observer.${member_str} >& obsout/log.${member_str} &

     n=$(( $n + 1 ))
   done
   wait
 done

 echo "concanate observer"
 cd ${run_dir}
 mv obsout observer

 number_members=81
 for var in sondes_tsen sondes_tv sondes_q sondes_uv
 do
   time python /work2/noaa/gsienkf/weihuang/production/run/transform/concanate-observer.py \
      --run_dir=${run_dir} \
      --datestr=${yyyymmddhh} \
      --nmem=${number_members} \
      --varname=${var} &
 done

 wait

 echo "run solver"
 cd ${run_dir}

 MYLAYOUT="11,6"
 NUMMEM=80
sed -e "s?LAYOUT?${MYLAYOUT}?g" \
    -e "s?NUMBEROFMEMBERS?${NUMMEM}?g" \
    -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
    -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
    ${jeditemplatedir}/getkf.yaml.template.solver > getkf.solver.yaml

sed -e "s?YYYYMMDDHH?${yyyymmddhh}?g" \
    ${jeditemplatedir}/${obstype}.obs.yaml.template.solver >> getkf.solver.yaml

export OMP_NUM_THREADS=1
export corespernode=40
export mpitaskspernode=40
nprocs=396
totnodes=10

echo "srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \\" >> ${run_dir}/logs/run_jedi.out
echo "  --exclusive --cpu-bind=cores --verbose $executable getkf.yaml" >> ${run_dir}/logs/run_jedi.out
echo "srun: `which srun`" >> ${run_dir}/logs/run_jedi.out

#srun -N $totnodes -n $nprocs --ntasks-per-node=$mpitaskspernode $executable getkf.solver.yaml
srun -n $nprocs $executable getkf.solver.yaml

cd ${run_dir}
echo "generate increments"

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


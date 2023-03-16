#!/bin/sh
# model was compiled with these 
echo "run Jedi starting at `date`"
#source $MODULESHOME/init/sh

export VERBOSE=${VERBOSE:-"NO"}
hydrostatic=${hydrostatic:=".false."}
launch_level=$(echo "$LEVS/2.35" |bc)
if [ $VERBOSE = "YES" ]; then
 set -x
fi

source ${datapath}/analdate.sh

# yr,mon,day,hr at middle of assim window (analysis time)
export year=`echo $analdate |cut -c 1-4`
export month=`echo $analdate |cut -c 5-6`
export day=`echo $analdate |cut -c 7-8`
export hour=`echo $analdate |cut -c 9-10`
yyyymmddhh=${year}${month}${day}${hour}

#input file fir.
run_dir=${datapath}/${analdate}

source ~/gdasenv
executable=${jediblddir}/bin/fv3jedi_letkf.x
ulimit -s unlimited

echo "run Jedi starting at `date`"

cd ${run_dir}
rm -rf ioda_v2_data diag
mkdir ioda_v2_data diag
cp diag_conv_* diag/.
which python
echo "in run_dir: $${run_dir}"
#echo "ls diag"
#ls diag

#echo "module list"
#module list

python ${iodablddir}/bin/proc_gsi_ncdiag.py \
       -o ioda_v2_data diag

#cd ioda_v2_data
#flst=`ls *_ps_obs_${yyyymmddhh}.nc4`
#
#python ${iodablddir}/bin/combine_obsspace.py \
#  -i ${flst} -o ps_${yyyymmddhh}.nc4
#
#cd ..

echo "ls ioda_v2_data"
ls ioda_v2_data

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
     ${enkfscripts}/genyaml/coupler.res.template > coupler.res

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

echo "Run gen_ensmean.sh"

echo "module list"
module list

#echo "env"
#env

${enkfscripts}/gen_ensmean.sh ${run_dir}

echo "cd ${run_dir}" >> ${run_dir}/logs/run_jedi.out
cd ${run_dir}

#--------------------------------------------------------------------------------------------
 cp ${enkfscripts}/genyaml/config.template .
 cp ${enkfscripts}/genyaml/ps.yaml .
 cp ${enkfscripts}/genyaml/halo.distribution .
 cp ${enkfscripts}/genyaml/rr.distribution .

 export corespernode=40
 export mpitaskspernode=40
 count=1
 export OMP_NUM_THREADS=1

 NODES=$SLURM_NNODES

 export observer_layout_x=3
 export observer_layout_y=2
 export solver_layout_x=8
 export solver_layout_y=5
 export NMEM_ENKF=80

 python ${enkfscripts}/genyaml/genconfig.py \
   --template=config.template \
   --year=${year} \
   --month=${month} \
   --day=${day} \
   --hour=${hour} \
   --intv=3

 python ${enkfscripts}/genyaml/genyaml.py \
   --config=config.yaml \
   --observer=${enkfscripts}/genyaml/getkf.yaml.template.rr.observer \
   --solver=${enkfscripts}/genyaml/getkf.yaml.template.solver \
   --numensmem=${NMEM_ENKF} \
   --obsdir=observer

#--------------------------------------------------------------------------------------------
 export OOPS_DEBUG=-11
 export OOPS_TRACK=-11
#export OOPS_TRACE=1

 echo "run observer"

 rm -rf analysis hofx stdoutNerr solver
 mkdir -p analysis/mean analysis/increment hofx solver

number_members=${NMEM_ENKF}
n=0
while [ $n -le $number_members ]
do
   used_nodes=0
   while [ $used_nodes -lt $NODES ] && [ $n -le $number_members ]
   do
     used_nodes=$(( $used_nodes + 1 ))

     zeropadmem=`printf %03d $n`
     member_str=mem${zeropadmem}
     cp ${ensdatadir}/coupler.res ${member_str}/INPUT/.
     mkdir -p analysis/increment/${member_str}
     mkdir -p observer/${member_str}

     srun -N 1 -n 36 --ntasks-per-node=40 ${executable} \
	observer/getkf.yaml.observer.${member_str} >& observer/log.${member_str} &

     n=$(( $n + 1 ))
   done
   wait
 done

echo "module list"
module list

echo "env"
env

 echo "concanate observer"
 cd ${run_dir}
 obstype=ps

 number_members=81
 time python ${enkfscripts}/python_scripts/concanate-observer.py \
      --run_dir=${run_dir} \
      --datestr=${yyyymmddhh} \
      --nmem=${number_members} \
      --obstype=${obstype}

 echo "run solver"
 cd ${run_dir}

export OMP_NUM_THREADS=1
export corespernode=30
export mpitaskspernode=30
#nprocs=360
totnodes=8
MYLAYOUT="8,5"
nprocs=240

#echo "srun -N $totnodes -n $nprocs -c $count --ntasks-per-node=$mpitaskspernode \\" >> ${run_dir}/logs/run_jedi.out
#echo "  --exclusive --cpu-bind=cores --verbose $executable getkf.yaml" >> ${run_dir}/logs/run_jedi.out
echo "srun: `which srun`" >> ${run_dir}/logs/run_jedi.out

#srun -N $totnodes -n $nprocs --ntasks-per-node=$mpitaskspernode $executable getkf.solver.yaml
 srun -N 8 -n 240 --ntasks-per-node=30 \
        ${executable} getkf.solver.yaml log.solver.out

cd ${run_dir}
echo "generate increments"

interpsrcdir=${enkfscripts}/interp_fv3cube2gaussian
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


#!/bin/sh

# cold start script

 run_dir=/work2/noaa/da/weihuang/cycling/jedi_C96_lgetkf_sondesonly
 datestr=2020010100
 cold_start_dir=${run_dir}/${datestr}

 mkdir -p ${cold_start_dir}

 touch ${cold_start_dir}/cold_start_bias

 cp gdas1.t00z.abias ${cold_start_dir}/.
 cp abias_pc ${cold_start_dir}/.

cat > ${run_dir}/analdate.sh << EOF1
export analdate=${datestr}
export analdate_end=2020011600
EOF1

cat > ${run_dir}/fg_only.sh << EOF2
export fg_only=true
export cold_start=true
EOF2

 exit 0

 cd ${cold_start_dir}

 num_member=80
 n=1
 while [ $n -le ${num_member} ]
 do
   if [ $n -lt 10 ]
   then
     member_str=00${n}
   elif [ $n -lt 100 ]
   then
     member_str=0${n}
   else
     member_str=${n}
   fi

   dirname=mem${member_str}
   mkdir -p analysis/increment/${dirname}/INPUT

   n=$(( $n + 1 ))
 done


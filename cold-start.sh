#!/bin/sh

# cold start script

#run_dir=/work2/noaa/gsienkf/weihuang/gsi/jedi_C96_lgetkf_sondesonly
 run_dir=/scratch2/BMC/gsienkf/Wei.Huang/producttion/run/jedi_C96_lgetkf_sondesonly
 datestr=2020010100
 cold_start_dir=${run_dir}/${datestr}

 mkdir -p ${cold_start_dir}

 touch ${cold_start_dir}/cold_start_bias

 cp gdas1.t00z.abias ${cold_start_dir}/.
 cp abias_pc ${cold_start_dir}/.

cat > ${run_dir}/analdate.sh << EOF1
export analdate=${datestr}
export analdate_end=2020020100
EOF1

cat > ${run_dir}/fg_only.sh << EOF2
export fg_only=true
export cold_start=true
EOF2


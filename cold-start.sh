#!/bin/sh

# cold start script

 cold_start_dir=/work2/noaa/gsienkf/weihuang/gsi/C96_lgetkf_sondesonly/2020010100

 mkdir -p ${cold_start_dir}

 touch ${cold_start_dir}/cold_start_bias

 cp gdas1.t00z.abias ${cold_start_dir}/.
 cp abias_pc ${cold_start_dir}/.



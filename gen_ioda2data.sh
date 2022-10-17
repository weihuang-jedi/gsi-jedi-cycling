#!/bin/bash

#output dir.
output_dir=$1
mkdir -p ${output_dir}

#input file fir.
run_dir=$2

source /home/weihuang/intelenv.skylab
module list
which python

temp_dir=${run_dir}/diag
mkdir -p ${temp_dir}
rm -rf ${temp_dir}/*
cd ${temp_dir}
cp ${run_dir}/diag_conv_* .

 source ~/intelenv

#ioda-bundle build dir:
#export iodablddir=/work2/noaa/gsienkf/weihuang/production/build/ioda-bundle
export iodablddir=/work2/noaa/gsienkf/weihuang/jedi/build/ioda-bundle
export LD_LIBRARY_PATH=${iodablddir}/lib:$LD_LIBRARY_PATH
export PYTHONPATH=${iodablddir}/lib/python3.9/pyioda:$PYTHONPATH

#Convert GSI diag 2 ioda2 format
python ${iodablddir}/bin/proc_gsi_ncdiag.py -o ${output_dir} ${temp_dir}


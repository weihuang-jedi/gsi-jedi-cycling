#!/bin/bash
# sh submit_job.sh <machine>
if [ "$#" -eq  "0" ]
then
  machine=orion
else
  machine=$1
fi

#echo "machine: ${machine}"

cat preamble/${machine} config.sh > job.sh
sbatch job.sh

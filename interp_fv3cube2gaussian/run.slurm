#!/bin/bash
#SBATCH --ntasks-per-node=40
#SBATCH -N 1
#SBATCH -n 40
#SBATCH -t 00:15:00
#SBATCH -A gsienkf
##SBATCH --partition=orion
#SBATCH --partition=bigmem
#SBATCH --job-name=interp
#SBATCH --output=log.interp.o%j

 set -x

 source ~/intelenv

 cd /work2/noaa/gsienkf/weihuang/production/run/transform/interp_fv3cube2gaussian

 time srun -n 40 fv3interp.exe

 sacct --format=JobID,CPUTime,Elapsed,AveVMSize,MaxRSS,NodeList%30 --units=M -j $SLURM_JOBID


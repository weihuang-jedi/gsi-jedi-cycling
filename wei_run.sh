# sh submit_job.sh <machine>
machine=hera
cat ${machine}_preamble config.sh > job.sh
sbatch job.sh


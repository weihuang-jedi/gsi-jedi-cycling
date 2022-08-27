# sh submit_job.sh <machine>
machine=orion
cat ${machine}_preamble config.sh > job.sh
echo sbatch job.sh

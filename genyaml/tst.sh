#!/bin/bash

 set -x

 export layout="[3, 2]"
 export NMEM_ENKF=80

 python genconfig.py \
   --template=config.template \
   --year=2020 \
   --month=1 \
   --day=16 \
   --hour=12 \
   --intv=3

 python genyaml.py \
   --config=config.yaml \
   --observer=getkf.yaml.template.rr.observer \
   --solver=getkf.yaml.template.solver \
   --numensmem=80 \
   --obsdir=observer


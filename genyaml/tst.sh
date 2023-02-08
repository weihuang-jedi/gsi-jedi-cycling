#!/bin/bash

 set -x

 export layout_x=3
 export layout_y=2
 export NMEM_ENKF=80
 export CDATE=2020011612

#python genyaml.py \
#  --config=config.yaml \
#  --in=lgetkf.yaml \
#  --out=new_lgetkf.yaml

 python genyaml.py \
   --config=config.yaml \
   --observer=getkf.yaml.template.rr.observer \
   --solver=getkf.yaml.template.solver \
   --numensmem=80 

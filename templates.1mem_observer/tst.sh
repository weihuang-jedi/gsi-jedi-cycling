#!/bin/bash

 NODES=9

 windowdatetime=2020-01-01T12:00:00Z \
 backgrounddatetime=2020-01-01T12:00:00Z \
 yyyymmddhh=2020010112 \
 jeditemplatedir=/work2/noaa/da/weihuang/cycling/scripts/gsi-jedi-cycling/templates.1mem_observer
 run_dir=/work2/noaa/da/weihuang/cycling/scripts/gsi-jedi-cycling/obsout

 obstype=sondes
 MYLAYOUT="3,2"

 number_members=81
 n=0
 while [ $n -lt $number_members ]
 do
   used_nodes=0
   while [ $used_nodes -lt $NODES ] && [ $n -le $number_members ]
   do
     used_nodes=$(( $used_nodes + 1 ))

     if [ $n -lt 10 ]
     then
       member_str=mem00${n}
     elif [ $n -lt 100 ]
     then
       member_str=mem0${n}
     else
       member_str=mem${n}
     fi

     mkdir -p analysis/increment/${member_str}
     mkdir -p obsout/${member_str}

sed -e "s?LAYOUT?${MYLAYOUT}?g" \
  -e "s?MEMSTR?${member_str}?g" \
  -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
  -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
  ${jeditemplatedir}/getkf.yaml.template.1member.rr.observer > obsout/getkf.yaml.observer.${member_str}

sed -e "s?YYYYMMDDHH?${yyyymmddhh}?g" \
  ${jeditemplatedir}/${obstype}.obs.yaml.template.rr.observer >> obsout/getkf.yaml.observer.${member_str}

     mkdir -p obsout/${member_str}
     srun -N 1 -n 36 ${executable} obsout/getkf.yaml.observer.${member_str} >& obsout/log.${member_str} &

     n=$(( $n + 1 ))
   done
   wait
 done

 mkdir -p observer

 for var in sondes_tsen sondes_tv sondes_q sondes_uv
 do
   time python /work2/noaa/gsienkf/weihuang/production/run/transform/concanate-observer.py \
      --run_dir=${run_dir} \
      --datestr=${yyyymmddhh} \
      --nmem=${number_members} \
      --varname=${var} &
 done

 wait

 mkdir -p solver

 MYLAYOUT="5,8"
 NUMMEM=80
sed -e "s?LAYOUT?${MYLAYOUT}?g" \
    -e "s?NUMBEROFMEMBERS?${NUMMEM}?g" \
    -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
    -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
    ${jeditemplatedir}/getkf.yaml.template.solver > getkf.yaml

sed -e "s?YYYYMMDDHH?${yyyymmddhh}?g" \
    ${jeditemplatedir}/${obstype}.obs.yaml.template.solver >> getkf.yaml


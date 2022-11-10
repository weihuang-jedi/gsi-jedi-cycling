#!/bin/sh
# yr,mon,day,hr at middle of assim window (analysis time)
export year=2020
export month=01
export day=01
export hour=12

nodes=6
NUMMEM=1
MYLAYOUT="5,8"
backgrounddatetime=${year}-${month}-${day}T${hour}:00:00Z
windowdatetime=`python ${enkfscripts}/setjedistartdate.py --year=${year} --month=${month} --day=${day} --hour=${hour} --intv=3`
echo "windowdatetime=$windowdatetime"
casename=sondes
READFROMDISK=false
UPDATEWITHGEOMETRY=false
RUNASOBSERVER=false
SAVEENSEMBLEINCREMENTS=false
MAXPOOLSIZE=1
DISTRIBUTION=' name: Halo'
HALOSIZE=' halo size: 1250e3'
yyyymmddhh=${year}${month}${day}${hour}
echo "yyyymmddhh=$yyyymmddhh"

number_members=80
total_nodes=20
n=1
while [ $n -le $number_members ]
do
   used_nodes=0
   while [ $used_nodes -le $total_nodes ] && [ $n -le $number_members ]
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

sed -e "s?LAYOUT?${MYLAYOUT}?g" \
    -e "s?NUMBEROFMEMBERS?${NUMMEM}?g" \
    -e "s?WINDOWBEGINDATETIME?${windowdatetime}?g" \
    -e "s?BACKGROUNDDATETIME?${backgrounddatetime}?g" \
    -e "s?MEMSTR?${member_str}?g" \
    -e "s?READFROMDISK?${READFROMDISK}?g" \
    -e "s?SAVEENSEMBLEINCREMENTS?${SAVEENSEMBLEINCREMENTS}?g" \
    -e "s?UPDATEWITHGEOMETRY?${UPDATEWITHGEOMETRY}?g" \
    -e "s?RUNASOBSERVER?${RUNASOBSERVER}?g" \
    templates/getkf.yaml.template.1member > getkf.yaml.${member_str}

      echo "srun --hint=nomultithread -N 1 --ntasks=36 --ntasks-per-node=36 --ntasks-per-socket=18 executable getkf.yaml.${member_str} &"
      n=$(( $n + 1 ))
   done
  #wait

done

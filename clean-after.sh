#!/bin/bash

 sdatestr=2020010106
 edatestr=2024010100

 if [ "$#" -eq  "0" ]
 then
   datadir=/work2/noaa/da/weihuang/cycling/gsi_C96_lgetkf_sondesonly
 else
   datadir=$1
 fi

 incrhour=6
 yyyymmddhh=$sdatestr
 while [ $yyyymmddhh -lt $edatestr ]
 do
   year=`echo $yyyymmddhh | cut -c1-4`
   month=`echo $yyyymmddhh | cut -c5-6`
   day=`echo $yyyymmddhh | cut -c7-8`
   hour=`echo $yyyymmddhh | cut -c9-10`

   if [ ! -d ${datadir}/${yyyymmddhh} ]
   then
      echo "No more avialable runs from: ${yyyymmddhh}"
      exit -1
   fi

   cd ${datadir}/${yyyymmddhh}

   rm -rf logs gsitmp_ensmean
   rm -rf mem0*
   rm -f enkf.nml hybens_info satbias_angle satbias_in satbias_pc vlocal_eig.dat
   rm -f bfg_*_mem* sanl_*_mem* sfg_*_mem*
   rm -f anavinfo convinfo  enkf.log fort.*
   rm -f ozinfo satinfo scaninfo
   
   yyyymmddhh=`date -u -d "${year}-${month}-${day} ${hour}:00:00 UTC $incrhour hour" +%Y%m%d%H`
 done


#!/bin/sh

#set -x

 module load cdo/1.9.10

 indir=$1
 outdir=${indir}/mem000/INPUT
 mkdir -p ${outdir}

 if [ ! -f ${outdir}/coupler.res ]
 then
   for fl in coupler.res grid_spec.nc atm_stoch.res.nc
   do
     if [ -f ${indir}/mem001/INPUT/$fl ]
     then
       cp ${indir}/mem001/INPUT/$fl ${outdir}/.
     fi
   done

   if [ -f ${indir}/mem001/INPUT/C96_grid.tile1.nc ]
   then
     cp ${indir}/mem001/INPUT/C96_grid.tile*.nc ${outdir}/.
   fi
 fi

#typelist=(fv_core.res fv_srf_wnd.res fv_tracer.res oro_data phy_data sfc_data)
 typelist=(fv_core.res fv_srf_wnd.res fv_tracer.res phy_data sfc_data)

 for i in ${!typelist[@]}
 do
   echo "element $i is ${typelist[$i]}"
   type=${typelist[$i]}
   echo "Working on type: $type"

   tile=0
   while [ $tile -lt 6 ]
   do
     tile=$(( $tile + 1 ))
     echo "\tWorking on tile: $tile"

     ofile=${outdir}/${type}.tile${tile}.nc
     rm -f $ofile

     ifiles=`ls ${indir}/mem*/INPUT/${type}.tile${tile}.nc`
     cdo ensmean $ifiles $ofile &
   done
 done

 wait


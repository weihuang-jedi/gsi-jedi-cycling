#!/bin/bash

 set -x

 edate=2020011118

 plot_stats () {
   argnum=$#
   if [ $argnum -lt 4 ]
   then
     echo "Usage: $0 sdate edate interval, for example: $0 2020010112 2020010812 12 all"
     exit -1
   fi

   sdate=$1
   edate=$2
   interval=$3
   flag=$4
   dir1=$5
   dir2=$6
   lbl1=$7
   lbl2=$8

  #argnum=0
  #echo "@ gives:"
  #for arg in "$@"
  #do
  #  argnum=$(( argnum + 1 ))
  #  echo "Arg $argnum: <$arg>"
  #done

   python diag.py --sdate=$sdate --edate=$edate \
     --dir1=${dir1} --dir2=${dir2} --interval=$interval \
     --lbl1=${lbl1} --lbl2=${lbl2} \
     --datadir=/work2/noaa/da/weihuang/cycling > obs_count_${flag}.csv

   python plot-jedi-gsi-diag.py --lbl1=${lbl1} --lbl2=${lbl2} \
	--output=1 >> obs_count_${flag}.csv

   dirname=${lbl2}-${lbl1}
   rm -rf ${dirname}
   mkdir -p ${dirname}
   mv -f obs_count_${flag}.csv ${dirname}/.
   for fl in diag_omf_rmshumid diag_omf_rmstemp diag_omf_rmswind humidity_rms temp_rms wind_rms
   do
     mv -f ${fl}.png ${dirname}/${fl}_${flag}.png
   done
   for case in ${dir1} ${dir2}
   do
     mv -f stats_${case} ${dirname}/${case}_${flag}_stats
     mv -f stats_${case}.nc ${dirname}/${case}_${flag}_stats.nc
   done
   mv -f *stats* ${dirname}/.
   mv -f *.csv ${dirname}/.
   mv -f *.png ${dirname}/.
 }

 tar cvf ~/jg.tar plot-jedi-gsi-diag.py get_diag.sh
#------------------------------------------------------------------------------
#firstlist=(feb8.jedi_C96_lgetkf_sondesonly)
#firstlist=(sepreint.jedi_C96_lgetkf_sondesonly)
#firstlist=(jedi_C96_lgetkf_sondesonly)
#secondlist=(jedi_C96_lgetkf_sondesonly)
#secondlist=(gdas-cycling)
#firstlbls=(SRIO)
#secondlbls=(JEDI)

 firstlist=(jedi_C96_lgetkf_sondesonly)
 secondlist=(gdas-cycling)
 firstlbls=(JEDI)
 secondlbls=(GDAS)
 for j in ${!firstlist[@]}
 do
   first=${firstlist[$j]}
   second=${secondlist[$j]}
   echo "first: ${first}, second: ${second}"

   plot_stats 2020010118 ${edate} 12 at_6h  ${first} ${second} ${firstlbls[$j]} ${secondlbls[$j]}
   plot_stats 2020010112 ${edate} 12 at_12h ${first} ${second} ${firstlbls[$j]} ${secondlbls[$j]}
   plot_stats 2020010112 ${edate} 6  all    ${first} ${second} ${firstlbls[$j]} ${secondlbls[$j]}

   tar uvf ~/jg.tar ${secondlbls[$j]}-${firstlbls[$j]}
 done

 exit 0


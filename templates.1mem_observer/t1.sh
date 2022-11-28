#!/bin/bash

memlist=()

function get_members()
{
  number_of_members=$1

  n=0
  while [ $n -le $number_of_members ]
  do
    if [ $n -lt 10 ]
    then
      memlist[${#memlist[@]}]="mem00${n}"
    elif [ $n -lt 100 ]
    then
      memlist[${#memlist[@]}]="mem0${n}"
    else
      memlist[${#memlist[@]}]="mem${n}"
    fi
    n=$(( $n + 1 ))
  done
}

get_members 80

# Iterate the loop to read and print each array element
for value in "${memlist[@]}"
do
     echo $value
done


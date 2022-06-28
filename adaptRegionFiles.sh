#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

# Requires wcstools
shopt -s nullglob


region_files_list=${1:-"reg_files.txt"}
## Check if input file exists
##
##

echo
echo "Region Files Listed in $region_files_list:"
echo

# List region files in file
while read -r line
do
    ## Check if file found
    found=""

    ## If extract end after . is empty
    ## append .reg and check if exists

    echo "$line$found"
done < "$region_files_list"

echo
echo -n "Continue with the listed regions files?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
else
    echo No
    return 1 2> /dev/null || exit 1
fi

# List detectors and exposures found
echo
echo "Detectors and Exposures Found:"
echo

# Get list of files containing *-obj-image-sky.fits
det_files=( *-obj-image-sky.fits )
#echo ${mosFiles[@]}
for f in ${det_files[@]}; do

    instrume=$(gethead INSTRUME "$f") # EMOS1, EMOS2, EPN
    instrume="${instrume:1}" # MOS1, MOS2, PN
    instrume=$(echo "$instrume" | tr '[:upper:]' '[:lower:]') # mos1, mos2, pn
    expid=$(gethead EXPIDSTR "$f")

    echo "$instrume$expid"

done

echo
echo -n "Continue with the listed detectors and exposures?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
    echo
else
    echo No
    return 1 2> /dev/null || exit 1
fi

# ./sky2det.sh mos1S001-obj-image-sky.fits ds9.reg


# List region files in file
while read -r line
do

    for f in ${det_files[@]}; do

        ./sky2det.sh "$f" "$line.reg"
        echo 
        echo "$line: ${f%%\-*}"

    done

    echo
    #echo "$line$found"
done < "$region_files_list"


shopt -u nullglob

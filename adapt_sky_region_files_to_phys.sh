#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

####
##  Setup working directories
####

## Script start tagged by: <[^v^]>
## Warnings tagged by: <[*,*]>
## WIP tagged by: ***
## Steps tagged by: ---

_SCRIPT=$( basename "${BASH_SOURCE[0]}" )
_SCRIPT_PATH=$( dirname "${BASH_SOURCE[0]}" )
_CURRENT_DIR="${PWD##*/}"
_PARENT_DIR="${PWD%/*}"


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
# Updated to work with or without needing newline at end of txt file
# https://unix.stackexchange.com/a/418067
while IFS= read -r line || [ -n "$line" ]; do

    ## Check if file found
    found=""

    ## If extract end after . is empty
    ## append .reg and check if exists

    printf '%s\n' "$line$found"
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

# Check for ANY event files output from e%chain; exit if none found
det_files=($( find . -maxdepth 1 -type f -name '*EVLI*.FIT' -not -name '*OEVLI*.FIT' ))
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
while IFS= read -r line || [ -n "$line" ]; do

    for f in ${det_files[@]}; do

        source $_SCRIPT_PATH/xmm_sky2phys_regions.sh "$f" "$line.reg" &
        wait $!
        echo
        echo "$line: ${f%%\-*}"

    done

    echo
    printf '%s\n' "$line"
done < "$region_files_list"

shopt -u nullglob

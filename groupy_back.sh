#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

# Requires wcstools
detector=${1:-"all"}

elo=$2

ehi=$3

bgregion_suffix=${4:-"back"}

region_files_list=${5:-"reg_files.txt"}





## Check if input file exists

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR != "spectral_products" ]; then
    echo
    echo "Current directory is not 'spectral_products'. Try again. ;)"
    echo
    return 1 2> /dev/null || exit 1
fi

if [[ ! -f $region_files_list ]]; then
    echo "Text file containing region file names not found."
    echo "Either create file reg_files.txt and populate with [region_file].reg;"
    echo "or check that $region_files_list exists."
    return 1 2> /dev/null || exit 1
fi

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

# List region files in file
while read -r line
do
    # Avoid background substracting the background file
    if [[ "$line" != "$bgregion_suffix" ]]; then
        # Calculate BACKSCAL since we're comparing data from two different observations now;
        # One symptom of not scaling the custom background properly is a negative count rate in XSPEC

        pushd ../intermediates

        src="$detector-obj-im-det-$elo-$ehi-$line.fits"
        bg="$detector-obj-im-det-$elo-$ehi-$bgregion_suffix.fits"
        echo
        echo
        echo $src
        echo $bg

        echo $PWD
        echo
        echo
        if [[ -f $src && -f $bg ]]; then
            regPix=$(getpix -g 0 $src 0 0 | wc -l)
            backPix=$(getpix -g 0 $bg 0 0 | wc -l)
            popd
        else
            echo "Source or background detector image not found in ../intermediates"
            echo "Cannot count pixels; skipping region: $line"
            popd
            continue
        fi
        

        if [[ $regPix == 0 || $backPix == 0 ]]; then
            echo "Obtained zero pixel counts for src:$regPix or bg:$backPix"
            echo "Canceling backscal calc and bg subtracted grppha for region: $line"
            continue
        fi

        #initBackscal

        ratio=$(echo "scale=10; $regPix/$backPix" | bc -q)
        echo "echoing backscal $ratio"

        . groupy.sh "$detector" "-$line" 25 "-$bgregion_suffix" "$ratio"
    fi

done < "$region_files_list"


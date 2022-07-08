#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

# Requires wcstools
detector=${1:-"all"}

bgregion_suffix=${2:-"back"}

region_files_list=${3:-"reg_files.txt"}

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
        . groupy.sh "$detector" "-$line" 25 "-$bgregion_suffix"
    fi

done < "$region_files_list"


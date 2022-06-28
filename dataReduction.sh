#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

# Requires wcstools
detector=${1:-"all"}

region_files_list=${2:-"reg_files.txt"}
## Check if input file exists

if [[ ! -f $region_files_list ]]; then
    echo "Text file containing region file names not found."
    echo "Either create file reg_files.txt and populate with [region_file].reg;"
    echo "or check that $region_files_list exists."
    return 1 2> /dev/null || exit 1
fi

pushd ..
if [[ ! -d spectral_products ]]; then
    mkdir spectral_products
fi
popd


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

# mos-spectra prefix=1S001 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=pnS003_backtest.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1

while read -r -u 3 line
do
    # SAS_CLOBBER=1
    # SAS_VERB=0

    # MOS1
    if [[ "$detector" == "mos1" || "$detector" == "all" ]]; then
        if [[ -f "mos1S001-obj.pi" ]]; then

            echo "Found mos1S001-obj.pi"
            echo "Skipping run of mos-spectra as it won't overwrite."
            echo "Either clear all mos-spectra output or start over."

        elif [[ -f "mos1S001-obj-$line.pi" ]]; then

            echo "Found mos1S001-obj-$line.pi. This will be overwritten if script continues."
            echo -n "Continue and overwrite mos1S001-obj-$line.pi?"
            read -p "" answer

            if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
                echo Yes
                mos-spectra prefix=1S001 caldb=$ESAS_CALDB region="mos1S001_$line.txt" mask=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1
            else
                echo No
                return 1 2> /dev/null || exit 1
            fi

        else
            mos-spectra prefix=1S001 caldb=$ESAS_CALDB region="mos1S001_$line.txt" mask=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1
        fi

        wait $!

        if [[ ! -f "mos1S001-obj.pi" ]]; then
            echo "Output from mos-spectra not found for mos1S001. Aborting mos_back and script."
            return 1 2> /dev/null || exit 1
        fi    

        mos_back prefix=1S001 caldb=$ESAS_CALDB diag=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1

        if [[ ! -f "mos1S001-back.pi" ]]; then
            echo "Output from mos_back not found for mos1S001. Aborting file renaming and grppha."
            return 1 2> /dev/null || exit 1
        fi

        mv mos1S001-obj.pi "mos1S001-obj-$line.pi"
        mv mos1S001-back.pi "mos1S001-back-$line.pi"
        mv mos1S001.rmf "mos1S001-$line.rmf"
        mv mos1S001.arf "mos1S001-$line.arf"
        mv mos1S001-obj-im-sp-det.fits "mos1S001-sp-$line.fits"

        . groupy.sh mos1S001 "-$line"

        mv *-$line* ../spectral_products

    fi

    # MOS2
    if [[ "$detector" == "mos2" || "$detector" == "all" ]]; then

        if [[ -f "mos2S002-obj.pi" ]]; then

            echo "Found mos2S002-obj.pi"
            echo "Skipping run of mos-spectra as it won't overwrite."
            echo "Either clear all mos-spectra output or start over."

        elif [[ -f "mos2S002-obj-$line.pi" ]]; then

            echo "Found mos2S002-obj-$line.pi. This will be overwritten if script continues."
            echo -n "Continue and overwrite mos2S002-obj-$line.pi?"
            read -p "" answer

            if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
                echo Yes
                mos-spectra prefix=2S002 caldb=$ESAS_CALDB region="mos2S002_$line.txt" mask=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=0 ccd6=1 ccd7=1
            else
                echo No
                return 1 2> /dev/null || exit 1
            fi

        else
            mos-spectra prefix=2S002 caldb=$ESAS_CALDB region="mos2S002_$line.txt" mask=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=0 ccd6=1 ccd7=1
        fi

        wait $!

        if [[ ! -f "mos2S002-obj.pi" ]]; then
            echo "Output from mos-spectra not found for mos2S002. Aborting mos_back and script."
            return 1 2> /dev/null || exit 1
        fi  

        mos_back prefix=2S002 caldb=$ESAS_CALDB diag=0 elow=300 ehigh=7000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=0 ccd6=1 ccd7=1

        wait $!

        if [[ ! -f "mos2S002-back.pi" ]]; then
            echo "Output from mos_back not found for mos2S002. Aborting file renaming and grppha."
            return 1 2> /dev/null || exit 1
        fi

        mv mos2S002-obj.pi "mos2S002-obj-$line.pi"
        mv mos2S002-back.pi "mos2S002-back-$line.pi"
        mv mos2S002.rmf "mos2S002-$line.rmf"
        mv mos2S002.arf "mos2S002-$line.arf"
        mv mos2S002-obj-im-sp-det.fits "mos2S002-sp-$line.fits"

        . groupy.sh mos2S002 "-$line"

        mv *-$line* ../spectral_products
    fi

    # pn
    if [[ "$detector" == "pn" || "$detector" == "all" ]]; then

        if [[ -f "pnS003-obj.pi" ]]; then

            echo "Found pnS003-obj.pi"
            echo "Skipping run of pn-spectra as it won't overwrite."
            echo "Either clear all pn-spectra output or start over."

        elif [[ -f "pnS003-obj-$line.pi" ]]; then

            echo "Found pnS003-obj-$line.pi. This will be overwritten if script continues."
            echo -n "Continue and overwrite pnS003-obj-$line.pi?"
            read -p "" answer

            if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
                echo Yes
                pn-spectra prefix=S003 caldb=$ESAS_CALDB region="pnS003_$line.txt" mask=0 elow=300 ehigh=7000 quad1=1 quad2=1 quad3=1 quad4=1
            else
                echo No
                return 1 2> /dev/null || exit 1
            fi

        else
            pn-spectra prefix=S003 caldb=$ESAS_CALDB region="pnS003_$line.txt" mask=0 elow=300 ehigh=7000 quad1=1 quad2=1 quad3=1 quad4=1
        fi

        wait $!

        if [[ ! -f "pnS003-obj.pi" ]]; then
            echo "Output from pn-spectra not found. Aborting mos_back and script."
            return 1 2> /dev/null || exit 1
        fi  

        pn_back prefix=S003 caldb=$ESAS_CALDB diag=0 elow=300 ehigh=7000 quad1=1 quad2=1 quad3=1 quad4=1

        wait $!

        if [[ ! -f "pnS003-back.pi" ]]; then
            echo "Output from pn_back not found. Aborting file renaming and grppha."
            return 1 2> /dev/null || exit 1
        fi

        mv pnS003-obj.pi "pnS003-obj-$line.pi"
        mv pnS003-back.pi "pnS003-back-$line.pi"
        mv pnS003.rmf "pnS003-$line.rmf"
        mv pnS003.arf "pnS003-$line.arf"
        mv pnS003-obj-im-sp-det.fits "pnS003-sp-$line.fits"
        mv pnS003-obj-os.pi "pnS003-obj-os-$line.pi"

        . groupy.sh pnS003 "-$line"

        mv *-$line* ../spectral_products
    fi
    
    # SAS_CLOBBER=0
    # SAS_VERB=0

    echo
    #echo "$line$found"
done 3< "$region_files_list"


# https://stackoverflow.com/questions/11704353/bash-nested-interactive-read-within-a-loop-thats-also-using-read
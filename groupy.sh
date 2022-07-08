#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

## Ask inst and offer options
inst=$1
suffix=${2:-""}
group=${3:-25}
bgsuffix=${4:-""}

if [[ "${line:0:1}" == "p" ]]; then
    inFile=${inst}"-obj-os$suffix.pi"
else
    inFile=${inst}"-obj$suffix.pi"
fi
outFile=${inst}"-obj-grp$suffix.pi"
arfFile=${inst}"$suffix.arf"
rmfFile=${inst}"$suffix.rmf"

if [[ "$bgsuffix" != "" ]]; then
    nxbFile=${inst}"-obj-grp$bgsuffix.pi"
    outFile=${inst}"-obj-grp$suffix-bgsubd.pi"
else
    nxbFile=${inst}"-back$suffix.pi"
fi


_CURRENT_DIR=${PWD##*/}

if [[ $_CURRENT_DIR == "analysis" || $_CURRENT_DIR == "spectral_products" ]]; then

    grppha infile=./${inFile} outfile=${outFile} clobber=yes comm="chkey ANCRFILE ./$arfFile & chkey RESPFILE ./$rmfFile & chkey BACKFILE ./$nxbFile & group min $group & exit"

    grppha infile=${outFile} outfile=${outFile} clobber=yes comm="show all & exit"

else
    echo
    echo "Current directory is not 'analysis' nor 'spectral_products'. Try again. ;)"
    echo
fi
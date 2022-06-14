#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

## Ask inst and offer options
inst=$1

inFile=${inst}"-obj.pi"
outFile=${inst}"-obj-grp.pi"
arfFile=${inst}".arf"
rmfFile=${inst}".rmf"
nxbFile=${inst}"-back.pi"

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR == "analysis" ]; then

    grppha infile=./${inFile} outfile=${outFile} clobber=yes comm="chkey ANCRFILE ./$arfFile & chkey RESPFILE ./$rmfFile & chkey BACKFILE ./$nxbFile & group min 50 & exit"

    grppha infile=${outFile} outfile=${outFile} clobber=yes comm="show all & exit"

else
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
fi
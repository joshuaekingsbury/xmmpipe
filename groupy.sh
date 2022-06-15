#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

## Ask inst and offer options
inst=$1
if [[ "${line:0:1}" == "p" ]]; then
    inFile=${inst}"-obj-os.pi"
else
    inFile=${inst}"-obj.pi"
fi
outFile=${inst}"-obj-grp.pi"
arfFile=${inst}".arf"
rmfFile=${inst}".rmf"
nxbFile=${inst}"-back.pi"

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR == "analysis" ]; then

    grppha infile=./${inFile} outfile=${outFile} clobber=yes comm="chkey ANCRFILE ./$arfFile & chkey RESPFILE ./$rmfFile & chkey BACKFILE ./$nxbFile & group min 25 & exit"

    grppha infile=${outFile} outfile=${outFile} clobber=yes comm="show all & exit"

else
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
fi
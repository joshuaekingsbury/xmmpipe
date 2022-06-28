#!/bin/bash

# Make sure to *source* and not just run script
# $. cheeseCloth.sh
# NOT
# $./cheeseCloth.sh

#det=$1

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR == "analysis" ]; then

    #_OBD_ID=${PWD%/*}
    #_OBS_ID=${_PARENT_DIR:1}

    # Log all the files in the folder

    # run cheese

    # copy files to cheese analysis (fridge)

    # 

    export SAS_CCF="${PWD}/ccf.cif"

    pushd ..
    _OBD_ID=${PWD##*/}

    if [ -d "./odf" ]; then
        pushd ./odf
        export SAS_ODF="${PWD}/"
        popd
    fi

    popd

    echo
    echo "EXPORTED DIRECTORIES:"
    echo "SAS_ODF="$SAS_ODF
    echo "SAS_CCF="$SAS_CCF

    # if [[ "${det:0:1}" == "S" ]]; then
    #     cheese prefixp=$det scale=0.20 rate=0.01 rates=0.01 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000
    # else
    #     cheese prefixm=$det scale=0.20 rate=0.01 rates=0.01 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000
    # fi

    _SCALE=0.2
    _RATE=0.01

    cheese prefixm="1S001 2S002" prefixp="S003" scale=$_SCALE rate=$_RATE rates=1.0 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000

    # cheese-band prefixm="1S001 2S002" prefixp="S003" scale=0.20 ratet=0.01 rates=0.01 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000


else
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
fi

# Create and backup cheese(d)

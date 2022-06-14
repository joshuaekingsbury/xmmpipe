#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

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

else
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
fi

# Create and backup cheese(d)

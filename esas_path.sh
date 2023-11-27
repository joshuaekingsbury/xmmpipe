#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run **before** any other sas tasks,           ##
##     after sas initialization in analysis directory  ##

## This script prepares the working directory with an updated cif file and replaces ODF summary file
## The respective SAS_CCF and SAS_ODF paths are also exported

## Script start tagged by: <[^v^]>
## Warnings tagged by: <[*,*]>

_SCRIPT=$( basename "${BASH_SOURCE[0]}" )
_SCRIPT_PATH=$( dirname "${BASH_SOURCE[0]}" )
_CURRENT_DIR="${PWD##*/}"
_PARENT_DIR="${PWD%/*}"

echo
echo "<[^v^]>"
echo "Executing script: ${_SCRIPT}"
echo "From: ${_SCRIPT_PATH}"
echo "In: ${_CURRENT_DIR}"
echo "Of: ${_PARENT_DIR}"
echo

# Prompt user to check if current directory is acceptable to continue;
# default is cookbook suggested "analysis" directory
if [ "${_CURRENT_DIR}" != "analysis" ]; then

    echo -n "Current directory is not 'analysis'. Continue anyway (y/n)?"
    read response

    if [ "$response" != "${response#[Yy]}" ] ;then
        echo
        echo "Continuing in current directory: ${_CURRENT_DIR}"
        echo
    else
        echo
        echo "<[*,*]> Opted NOT to continue in current directory: ${_CURRENT_DIR}"
        echo "Please create an \"analysis\" directory to work from"
        echo "Exiting"
        echo
        return 1 2> /dev/null || exit 1
    fi

fi

export SAS_CCF="${PWD}/ccf.cif"

#echo
#echo "Changing to parent directory"
#pushd ..
#cd "${_PARENT_DIR}"

# Check for and retrieve odf directory; exit if not found in parent directory
if [ -d "${_PARENT_DIR}/odf" ]; then
    echo
    #echo "Pushing to odf directory"
    #pushd ./odf
    echo "odf directory found in parent of working directory"
    echo "Exporting SAS_ODF as:"
    echo "${_PARENT_DIR}/odf"
    export SAS_ODF="${_PARENT_DIR}/odf"
    echo
    #echo "Popping to parent directory"
    #popd
else
    echo
    echo "<[*,*]> No odf directory found in parent of working directory"
    echo "(where \"odf\" is expected to be lowercase)"
    #echo "Popping back to working directory"
    #popd
    echo
    echo "Exiting"
    return 1 2> /dev/null || exit 1
fi

#echo
#echo "Popping to working directory"
#popd

echo
echo "EXPORTED DIRECTORIES:"
echo "SAS_CCF=${SAS_CCF}"
echo "SAS_ODF=${SAS_ODF}"
echo


echo
echo -n "Run from cifbuild and odfingest (y/n)?"
read response

# This grammar (the #[] operator) trims the first leading y or Y from the string
# If a y or Y is removed from the start of the word, the compared arguments are different, and a "yes" intention is assumed
# This means a "return" is considered a no for safety to avoid overwriting files accidentally
if [ "${response}" != "${response#[Yy]}" ] ;then

    ## From the ESAS Cookbook V21.0; 5.6
    echo
    echo Preparing directory with updated cif file and replacing ODF summary file
    echo

    # Overwrites current cif.cif file in directory
    cifbuild withccfpath=no analysisdate=now category=XMMCCF calindexset="${SAS_CCF}" fullpath=yes | tee ./_log_cifbuild.txt

    # Remove *.SAS files included from original pipeline processing and rebuild them
    rm "${SAS_ODF}"/*.SAS
    odfingest odfdir="${SAS_ODF}" outdir="${SAS_ODF}" | tee ./_log_odfingest.txt

else
    echo
    echo "<[*,*]> Opted not to run cifbuild and odfingest tasks"
    echo "Exiting"
    echo
    return 1 2> /dev/null || exit 1
fi
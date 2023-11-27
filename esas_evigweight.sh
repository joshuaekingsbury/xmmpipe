#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after esas_initial_reduction.sh, or after esas_manual_flare.sh ##

## Pre-requisites
## - WCSTools (For reading fits header info with <gethead>)

## This script runs the <evigweight> package on all found *-allevc.fits files,
##   outputing *-allevc-evigweight.fits
## (OR alternate provided suffix than "-allevc")

## NOTE


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

    echo -n "Current directory is not 'analysis'. Continue anyway (y/n)? "
    read response

    # This grammar (the #[] operator) trims the first leading y or Y from the string
    # If a y or Y is removed from the start of the word, the compared arguments are different, and a "yes" intention is assumed
    # This means a "return" is considered a no for safety to avoid overwriting files accidentally
    if [ "${response}" != "${response#[Yy]}" ] ;then
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

evigweight_pn=false
evigweight_mos1=false
evigweight_mos2=false

echo
echo -n "Run <evigweight> for which EPIC detectors (all/pn/mos/mos1/mos2/skip)? "
read response

if [ "${response}" = "all" ] ;then
    echo
    echo "Selected <evigweight> for all EPIC detectors"
    echo

    evigweight_pn=true
    evigweight_mos1=true
    evigweight_mos2=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Selected <evigweight> for PN detector"
    echo

    evigweight_pn=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Selected <evigweight> for both MOS detectors"
    echo

    evigweight_mos1=true
    evigweight_mos2=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Selected <evigweight> for MOS1 detector"
    echo

    evigweight_mos1=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Selected <evigweight> for MOS2 detector"
    echo

    evigweight_mos2=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping <evigweight>"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without running <evigweight>"
    echo
    return 1 2> /dev/null || exit 1
fi

echo
echo "Provide suffix string used to identify"
echo "  event file(s) for input to <evigweight> (or \"skip\")"
echo
echo -n "Default is \"-allevc\": "
read response

evc_suffix=""

if [ "${response}" = "" ] ;then

    evc_suffix="-allevc"

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping suffix entry for <evigweight>"
    echo "Exiting without running <evigweight>"
    echo
    return 1 2> /dev/null || exit 1

else

    evc_suffix="${response}"

fi

echo
echo "Selecting event files ending with \"${evc_suffix}\" (.fits)"
echo

# Check for files ending with suffix selection
evc_files=($( find . -maxdepth 1 -type f -name "*${evc_suffix}.fits" ))
if [[ -n "${evc_files[@]}" ]]; then
    echo
    echo "Event files found:"
    printf "%s\n" "${evc_files[@]}"
    echo
else
    echo
    echo "<[*,*]> No event files found matching pattern "'*'"${evc_suffix}"'.fits'
    echo "Cannot continue without event files"
    echo "Exiting"
    echo
    return 1 2> /dev/null || exit 1
fi

echo
echo -n "Continue with the listed event files?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
else
    echo No
    return 1 2> /dev/null || exit 1
fi


##
## Build i/o file names, and run <evigweight> if detector selected
##

# File suffix for <evselect> diagnostic images
evigweight_suffix="-evigweight"
evigweight_files_pre=($( find . -maxdepth 1 -type f -name "*${evigweight_suffix}.fits" ))
for f in "${evc_files[@]}"; do
    f="${f#*'/'}" # Trim the leading "./" on the file path/name from <find>
    ext="${f##*'.'}" # Extension without "."
    basename="${f%'.'*}" # Leading name before "."
    outfile="${basename}${evigweight_suffix}.${ext}"

    instrume=$(gethead INSTRUME "${f}") # EMOS1, EMOS2, EPN
    instrume="${instrume:1}" # MOS1, MOS2, PN
    expid=$(gethead EXPIDSTR "${f}")

    E="${instrume}${expid}"

    ## Prepare file string variations for different parts of the pipeline
    # Uppercase strings
    SCHED_FLAG="${E: -4:1}" # S for Scheduled, U for Unscheduled, X for multi-exposure?
    DETECTOR="${E%$SCHED_FLAG*}" # MOS1, MOS2, PN
    DTCTR=$(echo "${DETECTOR}" | sed 's/OS//') # M1, M2, PN
    EXPOSURE="${E#*$DETECTOR}"

    # Lowercase alternatives
    e=$(echo "${E}" | tr '[:upper:]' '[:lower:]')
    sched_flag="${e: -4:1}" # S for Scheduled, U for Unscheduled, X for multi-exposure?
    detector="${e%$sched_flag*}" # mos1, mos2, pn
    dtctr=$(echo "${detector}" | sed 's/os//') # m1, m2, pn
    exposure="${e#*$detector}"

    exposure_prefix="${detector}${EXPOSURE}"

    ## Check if event file(s) desired from <response> before continuing iteration
    ## If detector evigweight flag is false, and then matching current detector is selected, continue
    if [ "${response}" = "skip" ] ;then continue ;fi

    if ! $evigweight_pn ;then
        if [ "${detector}" = "pn" ] ;then continue ;fi
    fi
    if ! $evigweight_mos1 ;then
        if [ "${detector}" = "mos1" ] ;then continue ;fi
    fi
    if ! $evigweight_mos2 ;then
        if [ "${detector}" = "mos2" ] ;then continue ;fi
    fi

    echo
    echo "Creating file: ${outfile}"
    echo

    evigweight ineventset="${f}" witheffectivearea=yes withquantumefficiency=yes withfiltertransmission=yes outeventset="${outfile}" \
    | tee "./_log_${exposure_prefix}_evigweight.txt" &

    wait $!

    if [ -f "${PWD}/${outfile}" ] ;then
        echo
        echo "<evigweight> output found for ${exposure_prefix}:"
        echo "${outfile}"
        echo
    else
        echo
        echo "<[*,*]> <evigweight> output not found"
        echo "Check log file: ./_log_${exposure_prefix}_evigweight.txt"
        echo
    fi

    continue

done
evigweight_files_post=($( find . -maxdepth 1 -type f -name "*${evigweight_suffix}.fits" ))

echo
echo "Source files found:"
printf "%s\n" "${evc_files[@]}"
echo

echo
echo "<evigweight> output files found before run:"
printf "%s\n" "${evigweight_files_pre[@]}"
echo

echo
echo "<evigweight> output files found after run:"
printf "%s\n" "${evigweight_files_post[@]}"
echo


##
## Housekeeping
##

# mv all logs to logs directory
log_files=($( find . -maxdepth 1 -type f -name '*_log_*' ))
for i in "${log_files[@]}"
do
    mv "${i}" logs
done
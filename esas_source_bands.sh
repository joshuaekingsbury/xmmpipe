#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after esas_initial_reduction.sh ##

## Script start tagged by: <[^v^]>
## Warnings tagged by: <[*,*]>
## WIP tagged by: ***
## Steps tagged by: ---

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


#### ---
##
    # Prompt user to check if current directory is acceptable to begin/continue processing
##
####

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

#### ---
##
    # Make directories for housekeeping
##
####

if [ ! -d source_detect ]; then
    mkdir source_detect
fi


#### ---
##
    # Energy ranges of final output fits files (applied after proton flare filtering)
    #   Note: espfilt does not limit energy range of output
    #         The ranges below are used to create new files over energy ranges of interest
##
####

## <edetect_chain> can handle up to 6 bands

mos_b1_min=200
mos_b1_max=500

mos_b2_min=500
mos_b2_max=1000

mos_b3_min=1000
mos_b3_max=2000

mos_b4_min=2000
mos_b4_max=4500

mos_b5_min=4500
mos_b5_max=10000

mos_full_min=200
mos_full_max=10000

## PN lowest energy level (eV) is different due to different energy range sensitivities between the detectors

pn_b1_min=300
pn_b1_max=500

pn_b2_min=500
pn_b2_max=1000

pn_b3_min=1000
pn_b3_max=2000

pn_b4_min=2000
pn_b4_max=4500

pn_b5_min=4500
pn_b5_max=10000

pn_full_min=300
pn_full_max=10000

## *not used in this script*
## Encircled Energy Fraction values per detector per filter per band
## https://xmmssc.aip.de/cms/documentation/catalogue-structure/#ECFs
# pn_medium="8.3696 7.8681 5.7673 1.9290 0.5764"
# m1_medium="1.5258 1.6974 2.0058 0.7292 0.1451"
# m2_medium="1.5223 1.7082 2.0079 0.7333 0.1524"

## Detection Likelihood Threshold
##  Software default: 10
##  Auchettl procedures examples: 100
##  Auchettl procedures suggested start: 25
likemin=25

#### ---
##
    # Find e%chain output event files
##
####

# Check for ANY event files output from e%chain; exit if none found
event_chain_out=($( find . -maxdepth 1 -type f -name '*EVLI*.FIT' ))
# Evaluate
if [[ -n "${event_chain_out[@]}" ]] ;then
    echo
    echo "e%chain outputs found"
    printf "%s\n" "${event_chain_out[@]}"
    echo
else
    echo
    echo "<[*,*]> No output found for emchain or epchain"
    echo "Cannot continue without event files"
    echo "Exiting"
    echo
    return 1 2> /dev/null || exit 1
fi

#### ---
##
    # List detectors and exposures found from identified event files
##
####

echo
echo "Detectors and Exposures Found:"
echo

# Get list of files containing *EVLI*.FIT
# Using event_chain_out from earlier
exposures=()
for f in "${event_chain_out[@]}" ;do

    instrume=$(gethead INSTRUME "${f}") # EMOS1, EMOS2, EPN
    instrume="${instrume:1}" # MOS1, MOS2, PN
    expid=$(gethead EXPIDSTR "${f}")

    #echo "${instrume_lower}${expid}"
    exposures+=("${instrume}${expid}")
done

## Get unique detector/exposure combos (removing pn-oot)
exposures=( $(printf "%s\n" "${exposures[@]}" | sort -u) )

#echo "${exps_lower[@]}"
printf "%s\n" "${exposures[@]}"


#### ---
##
    # Prompt user for which detectors source detection should be run on,
    #   extract images across energy bands, and then run edetect_chain for those detectors
##
####

run_edetect_pn=false
run_edetect_mos1=false
run_edetect_mos2=false


echo
echo -n "Run edetect_chain for which EPIC detectors (all/pn/mos/mos1/mos2/skip)? "
read response


if [ "${response}" = "all" ] ;then
    echo
    echo "Selected edetect_chain for all EPIC detectors"
    echo

    run_edetect_pn=true
    run_edetect_mos1=true
    run_edetect_mos2=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Selected edetect_chain for PN detector"
    echo

    run_edetect_pn=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Selected edetect_chain for both MOS detectors"
    echo

    run_edetect_mos1=true
    run_edetect_mos2=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Selected edetect_chain for MOS1 detector"
    echo

    run_edetect_mos1=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Selected edetect_chain for MOS2 detector"
    echo

    run_edetect_mos2=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping edetect_chain"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without running edetect_chain"
    echo
    return 1 2> /dev/null || exit 1
fi


#### ---
##
    # Iterate over exposures and extract images across bands for those selected previously
##
####


for E in "${exposures[@]}"; do

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

    ## Troubleshooting variable trimming
    # echo
    # echo $E $SCHED_FLAG $DETECTOR $DTCTR $EXPOSURE
    # echo
    # echo $e $sched_flag $detector $dtctr $exposure
    # echo
    # continue

    ## Check if diagnostic file(s) desired from <response> before continuing iteration
    ## If detector diagnostic flag is false, and then matching current detector is selected, continue
    if [ "${response}" = "skip" ] ;then continue ;fi

    if ! $run_edetect_pn ;then
        if [ "${detector}" = "pn" ] ;then continue ;fi
    fi
    if ! $run_edetect_mos1 ;then
        if [ "${detector}" = "mos1" ] ;then continue ;fi
    fi
    if ! $run_edetect_mos2 ;then
        if [ "${detector}" = "mos2" ] ;then continue ;fi
    fi

    #### ---
    ##
        # Identify event file(s) and proceed with processing
    ##
    ####

    event_file=("${detector}${EXPOSURE}-allevc.fits")
    gti_file=("${detector}${EXPOSURE}-gti.fits")

    if [ ! -f "${gti_file}" ] ;then
        echo
        echo "<[*.*]> No GTI file found:"
        echo "${gti_file}"
        echo "Continuing to next detector selection"
        echo
    fi

    if [ -f "${event_file}" ] ;then
        echo
        echo "Processing band images for:"
        echo "${event_file}"
        echo
    else
        echo
        echo "<[*.*]> No event file found:"
        echo "${event_file}"
        echo "Continuing to next detector selection"
        echo
    fi

    # 
    if [ "${detector}" = "pn" ] ;then

        ##0.3-10.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_full.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_full_min}:${pn_full_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##0.3-0.5 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b1.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_b1_min}:${pn_b1_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##0.5-1.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b2.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_b2_min}:${pn_b2_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##1.0-2.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b3.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_b3_min}:${pn_b3_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##2.0-4.5 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b4.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_b4_min}:${pn_b4_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##4.5-10.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b5.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EP&&(PI in [${pn_b5_min}:${pn_b5_max}])&&(PATTERN in [0:4])&&(FLAG==0) && gti(${gti_file},TIME)"

    fi

    # 
    if [ "${detector}" = "mos1" ] || [ "${detector}" = "mos2" ] ;then

        ##0.2-10.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_full.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_full_min}:${mos_full_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##0.2-0.5 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b1.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_b1_min}:${mos_b1_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##0.5-1.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b2.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_b2_min}:${mos_b2_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##1.0-2.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b3.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_b3_min}:${mos_b3_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##2.0-4.5 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b4.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_b4_min}:${mos_b4_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

        ##4.5-10.0 keV
        evselect table="${event_file}":EVENTS imagebinning='binSize' imageset="${dtctr}_image_b5.fits" \
        withimageset=yes xcolumn='X' ycolumn='Y' ximagebinsize=80 yimagebinsize=80 \
        expression="#XMMEA_EM&&(PI in [${mos_b5_min}:${mos_b5_max}])&&(PATTERN in [0:12])&&(FLAG==0) && gti(${gti_file},TIME)"

    fi

    continue

done

eml_200_2000_fname="energy_${mos_b1_min}-${mos_b3_max}_mksrcdet_lm${likemin}"
eml_2000_10000_fname="energy_${mos_b4_min}-${mos_b5_max}_mksrcdet_lm${likemin}"
eml_200_10000_fname="energy_${mos_b1_min}-${mos_b5_max}_mksrcdet_lm${likemin}"

# Create atthk (make sure ODFPATH is set properly):
atthk_file=atthk.fits
atthkgen atthkset="${atthk_file}" timestep=1

#Looking at only the 0.2-2.0 keV energy range
edetect_chain eventsets="pnS001-allevc.fits mos1S002-allevc.fits mos2S003-allevc.fits" \
    imagesets="pn_image_b1.fits pn_image_b2.fits pn_image_b3.fits \
               m1_image_b1.fits m1_image_b2.fits m1_image_b3.fits \
               m2_image_b1.fits m2_image_b2.fits m2_image_b3.fits" \
    attitudeset="${atthk_file}" \
    pimin="${pn_b1_min} ${pn_b2_min} ${pn_b3_min} ${mos_b1_min} ${mos_b2_min} ${mos_b3_min} ${mos_b1_min} ${mos_b2_min} ${mos_b3_min}" \
    pimax="${pn_b1_max} ${pn_b2_max} ${pn_b3_max} ${mos_b1_max} ${mos_b2_max} ${mos_b3_max} ${mos_b1_max} ${mos_b2_max} ${mos_b3_max}" \
    witheexpmap=yes likemin="${likemin}" \
    eboxl_list="energy_${mos_b1_min}-${mos_b3_max}_energy_src_lm${likemin}.fits" \
    eboxm_list="energy_${mos_b1_min}-${mos_b3_max}_bkg_lm${likemin}.fits" \
    eml_list="${eml_200_2000_fname}.fits" &

wait $!

#Looking at only the 2.0-10.0 keV energy range
edetect_chain eventsets="pnS001-allevc.fits mos1S002-allevc.fits mos2S003-allevc.fits" \
    imagesets="pn_image_b4.fits pn_image_b5.fits \
               m1_image_b4.fits m1_image_b5.fits \
               m2_image_b4.fits m2_image_b5.fits" \
    attitudeset="${atthk_file}" \
    pimin="${pn_b4_min} ${pn_b5_min} ${mos_b4_min} ${mos_b5_min} ${mos_b4_min} ${mos_b5_min}" \
    pimax="${pn_b4_max} ${pn_b5_max} ${mos_b4_max} ${mos_b5_max} ${mos_b4_max} ${mos_b5_max}" \
    witheexpmap=yes likemin="${likemin}" \
    eboxl_list="energy_${mos_b4_min}-${mos_b5_max}_energy_src_lm${likemin}.fits" \
    eboxm_list="energy_${mos_b4_min}-${mos_b5_max}_bkg_lm${likemin}.fits" \
    eml_list="${eml_2000_10000_fname}.fits" &

wait $!

#Looking at the full 0.2-10.0 keV energy range
edetect_chain eventsets="pnS001-allevc.fits mos1S002-allevc.fits mos2S003-allevc.fits" \
    imagesets="pn_image_b1.fits pn_image_b2.fits pn_image_b3.fits pn_image_b4.fits pn_image_b5.fits\
               m1_image_b1.fits m1_image_b2.fits m1_image_b3.fits m1_image_b4.fits m1_image_b5.fits\
               m2_image_b1.fits m2_image_b2.fits m2_image_b3.fits m2_image_b4.fits m2_image_b5.fits" \
    attitudeset="${atthk_file}" \
    pimin="${pn_b1_min} ${pn_b2_min} ${pn_b3_min} ${pn_b4_min} ${pn_b5_min} \
                ${mos_b1_min} ${mos_b2_min} ${mos_b3_min} ${mos_b4_min} ${mos_b5_min} \
                    ${mos_b1_min} ${mos_b2_min} ${mos_b3_min} ${mos_b4_min} ${mos_b5_min}" \
    pimax="${pn_b1_max} ${pn_b2_max} ${pn_b3_max} ${pn_b4_max} ${pn_b5_max} \
                ${mos_b1_max} ${mos_b2_max} ${mos_b3_max} ${mos_b4_max} ${mos_b5_max}\
                    ${mos_b1_max} ${mos_b2_max} ${mos_b3_max} ${mos_b4_max} ${mos_b5_max}" \
    witheexpmap=yes likemin="${likemin}" \
    eboxl_list="energy_${mos_b1_min}-${mos_b5_max}_energy_src_lm${likemin}.fits" \
    eboxm_list="energy_${mos_b1_min}-${mos_b5_max}_bkg_lm${likemin}.fits" \
    eml_list="${eml_200_10000_fname}.fits" &

wait $!

#### ---
##
    # Display detected sources over image with ds9 (if works)
    # Ds9 Formatted Region Files Out
##
####

srcdisplay boxlistset="${eml_200_2000_fname}.fits" imageset=pn_image_full.fits \
           sourceradius=0.005 withregionfile=true regionfile="${eml_200_2000_fname}.reg"

srcdisplay boxlistset="${eml_2000_10000_fname}.fits" imageset=pn_image_full.fits \
           sourceradius=0.005 withregionfile=true regionfile="${eml_2000_10000_fname}.reg"

srcdisplay boxlistset="${eml_200_10000_fname}.fits" imageset=pn_image_full.fits \
           sourceradius=0.005 withregionfile=true regionfile="${eml_200_10000_fname}.reg"

#### ---
##
    # Housekeeping
##
####

#
src_out=($( find . -maxdepth 1 -type f -name '*energy*.fits' -o -name '*image*.fits' ))
# Mv all src process outputs to source_detect directory
for i in "${src_out[@]}"
do
    mv "${i}" source_detect
done
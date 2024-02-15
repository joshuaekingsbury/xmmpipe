#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after esas_path.sh ##

## Pre-requisites
## - WCSTools (For reading fits header info with <gethead>)

## This script runs the emchain and epchain commands for the initial data reduction,
##     generating the base event files for the detectors using the most recent CCF and SAS software
## Preprocessed versions of the event files are included in the observation data, but its recommended
##     to remake them since it is fast and the latest calibration and software versions will be used

## NOTE
## chain vs proc result in identical data outputs which differ only in output file names
## From the ESAS Cookbook V21.0; 5.7

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

if [ ! -d intermediates ]; then
    mkdir intermediates
    mkdir intermediates/chain
    mkdir intermediates/espfilt
fi
if [ ! -d logs ]; then
    mkdir logs
fi
if [ ! -d diagnostics ]; then
    mkdir diagnostics
fi
if [ ! -d images ]; then
    mkdir images
fi

#### ---
##
    # Energy ranges of final output fits files (applied after proton flare filtering)
    #   Note: espfilt does not limit energy range of output
    #         The ranges below are used to create new files over energy ranges of interest
    # For full energy range;
    #   - MOS 0-11999
    #   - PN  0-20479
##
####

mos1_elo=0
mos1_ehi=11999

mos2_elo=0
mos2_ehi=11999

pn_elo=0
pn_ehi=20479


#### ---
##
    # Event pattern and detector region flags
##
####

pattern_mos="(PATTERN <= 12)"
flag_mos_full="((FLAG & 0x766aa000)==0)"
flag_mos_fov="(#XMMEA_EM)"
flag_mos_corner="((FLAG & 0x766aa000)==0)&&!(CIRCLE(435,1006,17100,DETX,DETY)||CIRCLE(-34,68,17700,DETX,DETY)||BOX(-20,-17000,6500,500,0,DETX,DETY)||BOX(5880,-20500,7500,1500,10,DETX,DETY)||BOX(-5920,-20500,7500,1500,350,DETX,DETY)||BOX(-20,-20000,5500,500,0,DETX,DETY))"

pattern_pn_double_down="(PATTERN <= 4)"
pattern_pn_single="(PATTERN == 0)"
flag_pn_full="(#XMMEA_EP)"
flag_pn_fov="((FLAG & 0xfb0000)==0)"
flag_pn_corner="(#XMMEA_EP)&&!((DETX,DETY) in circle(-2200,-1100,18080))"


#### ---
##
    # Prompt user for which detectors base event files should be prepared for
    #   and then run e%chain for those detectors
    # Menu option for ccd selection has been added (MOS only for now)
##
####

run_epchain=false
run_emchain_mos1=false
run_emchain_mos2=false

select_ccds=false
ccds=""

mos_ccds_auto=false
mos_ccd_states="G"


echo
echo -n "Run chains for which EPIC detectors (all/pn/mos/mos1/mos2/ccds/skip)? "
read response

if [ "${response}" = "ccds" ] ;then
    select_ccds=true

    echo
    echo -n "Run chain and modify CCDs of which EPIC detector (all_auto/mos1/mos2/mos1_auto/mos2_auto)? "
    read ccd_response

    response="${ccd_response%'_'*}" ## Pass through the detector selection to <response> (all/mos1/mos2)

    if [ "${ccd_response#*'_'}" = "auto" ] ;then
        mos_ccds_auto=true
    else
        echo
        echo "Enter CCDs on one line (This script does not yet validate CCD entry format)"
        echo "PN format example for CCD 1, 4, & 8:"
        echo "NOT IMPLEMENTED HERE YET"
        echo
        echo "MOS format example for CCD 1, 4, & 8:"
        echo "1 4 8"
        echo -n "Enter now:\n"
        read ccd_response

        echo
        echo "CCD string entered as:<${ccd_response}>"

        ccds="${ccd_response}"
    fi

fi

if [ "${response}" = "all" ] ;then
    echo
    echo "Selected chains for all EPIC detectors"
    echo

    run_epchain=true
    run_emchain_mos1=true
    run_emchain_mos2=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Selected epchain for PN detector"
    echo

    run_epchain=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Selected emchain for both MOS detectors"
    echo

    run_emchain_mos1=true
    run_emchain_mos2=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Selected emchain for MOS1 detector"
    echo

    run_emchain_mos1=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Selected emchain for MOS2 detector"
    echo

    run_emchain_mos2=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping e%chains"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without running chains"
    echo
    return 1 2> /dev/null || exit 1
fi


# epchain package documentation recommends the following parameters and epchain order
# The intermediate files are reused by the second epchain call,
#   and then cleaned up by the second epchain call
if $run_epchain ;then

    ## Fixing (CONSTITUENT) error wg=hen running epchain in SAS v21.0;
    ## "...the task radmonfix that it is not included in the SAS v21.0 binary distribution"
    ## Fix @ https://195.169.141.9/web/xmm-newton/sas-watchout-2100-error-constituent

    echo
    echo "Running chains for PN detector"
    echo

    ## Insert a check on exposure counts here; particularly important for EPN
    ## epchain exposure=99
    ## From the ESAS Cookbook V21.0; 5.7

    ## For now
    echo
    echo "Running a pre-check with epchain to see how many pn exposures exist:"
    echo

    epchain exposure=99 | tee "./_epchain_exposure_count_diagn.txt"
    ##

    ## Running epchain twice
    ## Users Guide to the XMM-Newton Science Analysis System V17.0; 4.9
    ##   OoT events are recorded by PN between integration intervals when the CCD is readout
    ##   OoT events broaden spectral features and are wrongly reconstructed in PN images
    ##   Up to 6.3% of events can be OoT depending on frame mode
    ##   Simulating OoT events by this procedure is recommended "If highest spectral resolution is required"
    ##   Section 4.9.2 shows impact on spectra

    epchain withoutoftime=Y keepintermediate=raw runradmonfix=N | tee "./_log_epchain_oot.txt"

    # Check for output *PN*OOEVLI*.FIT
    if [ ! -f *PN*OOEVLI*.FIT ] ;then
        echo "<[*,*]> No Out-of-Time output from epchain"
    fi

    epchain runradmonfix=N | tee "./_log_epchain.txt"

    # Check for output *PN*PIEVLI*.FIT
    if [ ! -f *PN*PIEVLI*.FIT ] ;then
        echo "<[*,*]> No output from epchain"
    fi

fi

# By default emchain runs both MOS detectors and all CCDs
# These can be specified as follows:
# emchain instruments=M2 exposures=S002 ccds=’1 3 4’
# For troubleshooting, emchain documentation specifies ways to continue or restart emchain in different ways

if $run_emchain_mos1 ;then

    echo
    echo "Running chain for MOS1 detector"
    echo

    if [ ! $select_ccds ] || [ $mos_ccds_auto ] ;then
        emchain instruments=M1 | tee "./_log_emchain_mos1.txt"
    else
        emchain instruments=M1 ccds="${ccds}" | tee "./_log_emchain_mos1.txt"
    fi

    # Check for output *M1*MIEVLI*.FIT
    if [ ! -f *M1*MIEVLI*.FIT ] ;then
        echo "<[*,*]> No output from emchain for MOS1"
    fi

fi

if $run_emchain_mos2 ;then

    echo
    echo "Running chain for MOS2 detector"
    echo

    emchain instruments=M2 | tee ./_log_emchain_mos2.txt

    if [ ! $select_ccds ] || [ $mos_ccds_auto ] ;then
        emchain instruments=M2 | tee ./_log_emchain_mos2.txt
    else
        emchain instruments=M2 ccds="${ccds}" | tee ./_log_emchain_mos2.txt
    fi

    # Check for output *M2*MIEVLI*.FIT
    if [ ! -f *M2*MIEVLI*.FIT ] ;then
        echo "<[*,*]> No output from emchain for MOS2"
    fi

fi

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
    # List detectors and exposures found from newly created event files
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
    # Function to create full-band FOV preview images of key products (WIP) ***
    # Parameter(s):
    #   - <event_file> name
##
####

create_event_file_images (){

    if [ ! -f "${PWD}/$1" ] ;then
        echo "File <$1> not found"
        echo "No images created"
        return 1
    fi

    fname=$1
    fname="${fname%.*}"

    instrume=$(gethead INSTRUME "$1") # EMOS1, EMOS2, EPN
    instrume="${instrume:1:1}" # M, M, P

    event_pattern=""
    area_flag=""

    if [ "${instrume}" == "M" ] ;then
        event_pattern="${pattern_mos}"
        area_flag="${flag_mos_fov}" ## FOV only; Excludes corner events; (FLAG & 0x766aa000)==0 is entire FOV
    elif [ "${instrume}" == "P" ] ;then
        event_pattern="${pattern_pn_double_down}"
        area_flag="${flag_pn_fov}" ## FOV only; Excludes corner events; #XMMEA_EP is entire FOV
    else
        echo "Detector undetermined for given event file"
        echo "File: ${fname}"
        echo "No images created"
        return 1
    fi

    preview_sky_prefix="${fname}-im-sky"

    evselect table="$1" withimageset=yes imageset="${preview_sky_prefix}.fits" \
    filtertype=expression expression="${event_pattern}&&${area_flag}" \
    ignorelegallimits=yes imagebinning=imageSize \
    xcolumn=X ximagesize=780 ximagemax=50000 ximagemin=1 \
    ycolumn=Y yimagesize=780 yimagemax=50000 yimagemin=1 | tee "./_log_${preview_sky_prefix}_evselect.txt" &

    wait $!
    mv ${preview_sky_prefix}.fits images

    preview_det_prefix="${fname}-im-det"

    evselect table="$1" withimageset=yes imageset="${preview_det_prefix}.fits" \
    filtertype=expression expression="${event_pattern}&&${area_flag}" \
    ignorelegallimits=yes imagebinning=imageSize \
    xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
    ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 | tee "./_log_${preview_det_prefix}_evselect.txt" &

    wait $!
    mv ${preview_det_prefix}.fits images

}

#### ---
##
    # Ask user to continue for diagnostic images, filtering, and energy cuts
##
####

# Check if want to skip again or specify detector
if [ "${response}" = "skip" ] ;then
    echo
    echo "Preparing to run:"
    echo "  - evselect for diagnostic images"
    echo "  - espfilt for proton flare time filtering"
    echo "  - evselect for energy range cuts to espfilt output"
    echo

    echo
    echo -n "Generate diagnostics and filter which EPIC detectors (all/pn/mos/mos1/mos2/skip)? "
    read response
fi

    diagnostic_pn_event=false
    diagnostic_mos1_event=false
    diagnostic_mos2_event=false

if [ "${response}" = "all" ] ;then
    echo
    echo "Creating diagnostic images for and filtering all found exposures"
    echo

    diagnostic_pn_event=true
    diagnostic_mos1_event=true
    diagnostic_mos2_event=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Creating diagnostic images for and filtering PN exposures"
    echo

    diagnostic_pn_event=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Creating diagnostic images for and filtering both MOS exposures"
    echo

    diagnostic_mos1_event=true
    diagnostic_mos2_event=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Creating diagnostic images for and filtering MOS1 exposures"
    echo

    diagnostic_mos1_event=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Creating diagnostic images for and filtering MOS2 exposures"
    echo

    diagnostic_mos2_event=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping diagnostic image creation and filtering"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "Accepted inputs are: all/pn/mos/mos1/mos2/skip"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without creating diagnostic images nor filtering"
    echo
    return 1 2> /dev/null || exit 1
fi

# File suffix for <evselect> diagnostic images
diagn_suffix="-diagn-det-unfilt"


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

    if ! $diagnostic_pn_event ;then
        if [ "${detector}" = "pn" ] ;then continue ;fi
    fi
    if ! $diagnostic_mos1_event ;then
        if [ "${detector}" = "mos1" ] ;then continue ;fi
    fi
    if ! $diagnostic_mos2_event ;then
        if [ "${detector}" = "mos2" ] ;then continue ;fi
    fi

    #### ---
    ##
        # Identify event file(s) and proceed with processing
    ##
    ####

    event_file=""
    event_file_oot=""

    if [ "${detector}" = "mos1" ] || [ "${detector}" = "mos2" ] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"MIEVLI*.FIT)

    elif [ "${detector}" = "pn" ] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"PIEVLI*.FIT)
        event_file_oot=(*"${DTCTR}${EXPOSURE}"OOEVLI*.FIT)

    fi

    #### ---
    ##
        # Check header for reasons a specific exposure may be unusable or problematic
        # Create array for logging diagnostic info for current event file:
        #   If a property of the exposure is outside the bounds of this pipeline script,
        #     trigger <exit_early> and skip this exposure after writing out <detector_highlights>
    ##
    ####

    ## Gather detector header highlights
    obs_id=$(gethead OBS_ID "${event_file}")
    revolut=$(gethead REVOLUT "${event_file}") #Revolution
    datamode=$(gethead DATAMODE "${event_file}") #Instrument Mode (IMAGING or TIMING)
    obs_mode=$(gethead OBS_MODE "${event_file}") #Observation mode (POINTING or SLEW)
    submode=$(gethead SUBMODE "${event_file}") #Guest Observer Mode (ie 'PrimeFullWindow')
    filter=$(gethead FILTER "${event_file}") #Filter ID (ie 'Thin1')


    ## Human readable exposure summary, not specifically designed for reading by later processing scripts
    detector_highlights=()
    highlights_outfile="${detector}${EXPOSURE}_highlights_diagn.txt"
    exit_early=false

    detector_highlights+=("exposure_id:${detector}${EXPOSURE}")
    sched_flag_highlight="sched_flag:${SCHED_FLAG}"
    detector_highlights+=("event_file:${event_file}")
    detector_highlights+=("observation_id:${obs_id}")
    detector_highlights+=("revolution:${revolut}")
    #data_mode_highlight=("data_mode:${datamode}") # Only meaningful for OM instrument; <submode> stores relevant EPIC info
    observation_mode_highlight="observation_mode:${obs_mode}"
    guest_observer_mode_highlight="guest_observer_mode:${submode}"
    filter_highlight="filter_id:${filter}"

    echo
    echo "Starting exposure: ${detector}${EXPOSURE}"
    echo

    #### Observation Mode check
    ## No information found for the complete listing of values for EPIC OBS_MODE
    ## Assuming <SLEW> and <POINTING>
    if [ "${obs_mode}" != "POINTING" ] ;then
        observation_mode_highlight="${observation_mode_highlight} ( <[*,*]> WARNING : Event file deleted )"

        echo
        echo "<[*,*]> Observation mode is not POINTING"
        echo "Observation Mode: ${obs_mode}"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo

        rm "${event_file}"
        exit_early=true
    fi
    detector_highlights+=("${observation_mode_highlight}")


    #### Guest Observer Mode check
    ## XMM-Newton Data Files Handbook; Issue 4.8, December 27, 2017
    ## Table 35, pg 54: submode keywords for instrument modes
    if [ "${submode#Extended}" != "PrimeFullWindow" ] ;then
        guest_observer_mode_highlight="${guest_observer_mode_highlight} ( <[*,*]> WARNING )"

        echo
        echo "<[*,*]> submode is not PrimeFullWindow"
        echo "Observation Mode: ${submode}"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo

    fi
    detector_highlights+=("${guest_observer_mode_highlight}")

    #### Schedule check
    ## Unscheduled (U):
    ##     "In case of there were interruptions, for example, due to high radiation levels,
    ##         the exposures taken after the interruptions are called unscheduled."
    ## Midooka, T., Mizumoto, M., & Ebisawa, K. 2023, Astron. Nachr., 344, e230039.
    ## https://doi.org/10.1002/asna.20230039

    ## General purpose/multi-exposure (X):
    ##     file from CRSCOR group and/or product is not due to single exposure
    ##         CRSCOR group = crosscorrelation group
    ## XMM-Newton ABC Guide v4.6 for XMM-SAS v14.0; May 2016

    ## If an s or S CANNOT be trimmed from the front of sched_flag,
    ## It must be an unscheduled or multi-exposure observation
    if [ "${sched_flag}" = "${sched_flag#[Ss]}" ] ;then
        sched_flag_highlight="${sched_flag_highlight} ( <[*,*]> WARNING )"

        echo
        echo "<[*,*]> sched_flag attribute of exposure ${E} is either:"
        echo "- unscheduled (U)"
        echo "- general purpose/multi-exposure (X)"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo
    fi
    detector_highlights+=("${sched_flag_highlight}")

    #### Filter check
    ## From the ESAS Cookbook V21.0
    ## B.1. A Simple Single Observation, Spectroscopy and Imaging
    # "The event files for the "CalClosed" segments are not useful and can be deleted.""
    if [ "${filter}" = "CalClosed" ] ;then
        filter_highlight="${filter_highlight} ( <[*,*]> WARNING : Event file deleted )"

        echo
        echo "<[*,*]> filter is CalClosed"
        echo "Deleting event file: ${event_file}"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo

        rm "${event_file}"
        exit_early=true
    fi
    detector_highlights+=("${filter_highlight}")

    detector_highlights+=("ccds:${ccds} (All selected if none shown here)")

    if $exit_early ;then
        detector_highlights+=("ABORTED")

        echo
        echo "<[*,*]> Diagnostics for ${detector}${EXPOSURE} aborted"
        echo "Writing out to ${highlights_outfile}"
        printf "%s\n" "${detector_highlights[@]}" > "${highlights_outfile}"

        continue
    fi

    #### ---
    ##
        # If exit_early not triggered, continue creating diagnostic files (+) for observation/exposure
    ##
    ####

    exposure_prefix="${detector}${EXPOSURE}"
    in_file="${exposure_prefix}.FIT"
    in_file_allccds="${exposure_prefix}_allccds.FIT"
    cp "${event_file}" "${in_file}"
    cp "${event_file}" "${in_file_allccds}"

    # Energy range for proton-flare-filtering; defaults from <espfilt> documentation
    esp_elo=2500 # default: 2500 ; ESAS Cookbook: 2500
    esp_ehi=8500 # default: 8000 ; ESAS Cookbook: 8500
    detector_highlights+=("espfilt_elow:${esp_elo}")
    detector_highlights+=("espfilt_ehigh:${esp_ehi}")

    # Energy ranges used for "quick look" diagnostic images (anom CCDs and arcing)
    anom_elo=300
    anom_ehi=1000
    #arc_elo= ## Placeholder when I estimate energy ranges of arcing ***
    #arc_ehi=

    # Energy ranges used for filtering final output; adjusted below by detector
    det_elo=0
    det_ehi=0

    event_pattern=""
    area_flag=""

    if [ "${detector}" = "mos1" ] || [ "${detector}" = "mos2" ] ;then

        if [ "${detector}" = "mos1" ] ;then
            det_elo="${mos1_elo}"
            det_ehi="${mos1_ehi}"
        fi

        if [ "${detector}" = "mos2" ] ;then
            det_elo="${mos2_elo}"
            det_ehi="${mos2_ehi}"
        fi

        event_pattern="${pattern_mos}"
        area_flag="${flag_mos_full}"

        #### ---
        ##
            # Running <emanom> to run a basic check of the MOS CCDs for anomalous behavior
            # "Data above 2 keV are unaffected" (ESAS Cookbook V21.0; 5.9)
            # <emanom> task added to goflib 05-11-2020
        ##
        ####

        ## From the ESAS Cookbook V21.0; 5.9
        ## Examining CCDs for Anomalous States
        ## Writes estimated ccd states/flags to header of <event_file> as keys <ANOMFLn>
        ## NOTE: Documentation examples section shows "eventset" instead of "eventfile" (correct) for param

        emanom eventfile="${event_file}" keepcorner=no # expected output is mos#S###-anom.log
        mv "${detector}${EXPOSURE}-anom.log" "${detector}${EXPOSURE}-diagn-anom-allccd.log"

        #### ---
        ##
            # If auto reprocessing to exclude anomalous CCDS
            #   - Get anomalous CCD states assigned by emanom
            #   - Remove previous e%chain output
            #   - emchain again with ccds
        ##
        ####

        if $mos_ccds_auto ;then
            ANOMFL2=$(gethead ANOMFL2 "${event_file}")
            ANOMFL3=$(gethead ANOMFL3 "${event_file}")
            ANOMFL4=$(gethead ANOMFL4 "${event_file}")
            ANOMFL5=$(gethead ANOMFL5 "${event_file}")
            ANOMFL6=$(gethead ANOMFL6 "${event_file}")
            ANOMFL7=$(gethead ANOMFL7 "${event_file}")

            ccds="1"
            if [ "${ANOMFL2%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 2" ;fi
            if [ "${ANOMFL3%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 3" ;fi
            if [ "${ANOMFL4%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 4" ;fi
            if [ "${ANOMFL5%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 5" ;fi
            if [ "${ANOMFL6%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 6" ;fi
            if [ "${ANOMFL7%[$mos_ccd_states]*}" = "" ] ;then ccds=$ccds" 7" ;fi

            echo
            echo "<emanom> estimated anomalous CCD states (2-7): "
            echo "${ANOMFL2} ${ANOMFL3} ${ANOMFL4} ${ANOMFL5} ${ANOMFL6} ${ANOMFL7}"
            echo
            echo "Re-running chain for ${DETECTOR} detector with state selection: ${mos_ccd_states}"
            echo "CCDs selected: ${ccds}"
            echo
        fi

        # If re-chaining mos with auto ccds, clean directory of previous MOSn chain output
        # Check for output *M%*MIEVLI*.FIT
        if [ -f *${DTCTR}*MIEVLI*.FIT ] && $mos_ccds_auto ;then

            # Get arrays of *${obs_id}*.FIT files excluding e%chain output <event> files *EVLI*.FIT
            intermediate_chain_out=($( find . -maxdepth 1 -type f -name '*${obs_id}*.FIT' -not -name 'P*EVLI*.FIT' ))
            # rm all old e%chain outputs
            for i in "${intermediate_chain_out[@]}"
            do
                rm "${i}"
            done
            # rm previous MOSn emchain event file with all ccds
            rm *"${DTCTR}"*MIEVLI*.FIT

            wait $!
        fi

        if $select_ccds ;then
            echo "${ccds}" > "${detector}${EXPOSURE}-emchain-ccds.txt"
            create_event_file_images "${in_file_allccds}"
        fi

        if $mos_ccds_auto ;then

            emchain instruments="${DTCTR}" exposures="${EXPOSURE}" ccds="${ccds}" | tee "./_log_emchain_${detector}_anom.txt" &
            wait $!

            # ## Update new e%chain output with CCD states, and add "diagn" tag to <emanom> log
            emanom eventfile="${event_file}" keepcorner=no # expected output is mos#S###-anom.log
            # ## *** Only 1 emanom log file is left over per detector, doesn't leave one per exposure.....?
            mv "${detector}${EXPOSURE}-anom.log" "${detector}${EXPOSURE}-diagn-anom.log"

            # Check for output *M%*MIEVLI*.FIT
            if [ -f *${DTCTR}*MIEVLI*.FIT ] ;then
                cp "${event_file}" "${in_file}" # Overwrite <in_file> from allccds to ccds
            else
                echo "<[*,*]> No output found from emchain for ${DETECTOR} with CCD selection"
            fi
        fi

        ## From the ESAS Cookbook V21.0; 5.8
        ## Examining MOS CCDs for Anomalous States from 300-1000 keV (assigned above)

        ## Even if only interested in analysis >1.5 keV where anom state doesn't affect data,
        ##   also create images to check for scattering arcs (NOT YET IMPLEMENTED)
        evselect table="${in_file}" withimageset=yes imageset="${exposure_prefix}${diagn_suffix}".fits \
        filtertype=expression expression="(PI in [${anom_elo}:${anom_ehi}])&&${event_pattern}&&${area_flag}" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 | tee "./_log_${exposure_prefix}_evselect.txt" &

        ## The "&" after evselect assigns evselect to a background process
        ## The background process is retrieved from the $! env variable
        ## We can then wait for the background process to finish before running ds9
        wait $!

        if [ -f "${PWD}/${exposure_prefix}${diagn_suffix}.fits" ] ;then
            ## DS9 export image(s)
            ds9 "${PWD}/${exposure_prefix}${diagn_suffix}.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${exposure_prefix}${diagn_suffix}-${anom_elo}-${anom_ehi}.png" -exit &
            wait $!
        else
            continue
        fi

        ## Pre-espfilt images
        create_event_file_images "${in_file}"

        ## espfilt; From the ESAS Cookbook V21.0; 5.10
        ## Soft Proton Flare Filtering
        ##   Procedure checks flaring at high energies independently of output elow/ehigh range provided

        # "If there is a bright extended source in the FOV,
        # increasing the rangescale to 10 for the MOS
        # and 25 for the pn may be necessary to get a good fit."
        #     default rangescale=6.0
        espfilt eventfile="${in_file}" elow="${esp_elo}" ehigh="${esp_ehi}" \
        withsmoothing=yes smooth=51 rangescale=6.0 allowsigma=3.0 method=histogram \
        keepinterfiles=false | tee "./_log_${exposure_prefix}_espfilt.txt"

        wait $!

    elif [ "${detector}" = "pn" ] ;then

        exposure_prefix_oot="${exposure_prefix}_oot"
        in_file_oot="${exposure_prefix_oot}.FIT"
        cp "${event_file_oot}" "${in_file_oot}"

        det_elo="${pn_elo}"
        det_ehi="${pn_ehi}"

        event_pattern="${pattern_pn_double_down}"
        area_flag="${flag_pn_full}"

        ## Users Guide to the XMM-Newton Science Analysis System V17.0; 4.4.5
        ##   Recommended to run <epspatialcti> for pn after epchain to correct for CTI effects
        ##   (CTI: Charge Transfer Inefficiency)
        ## Running here since we have <event_file> name(s) for input
        ## *** Unsure if should run on both base and oot output of epchain
        ## *** Holding off since shouldn't be applied to Extended Full Frame
        ##       So this should be checked first on <submode>
        ## epspatialcti


        ## Creating preview images of PN at same energy range as MOS anomalous diagnostic images
        ##   *** Change this later since (most of) this range exclude double-pixel events (PATTERN == 0)
        evselect table="${in_file}" withimageset=yes imageset="${exposure_prefix}${diagn_suffix}".fits \
        filtertype=expression expression="(PI in [${anom_elo}:${anom_ehi}])&&${event_pattern}&&${area_flag}" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 | tee "./_log_${exposure_prefix}_evselect.txt" &

        wait $!

        evselect table="${in_file_oot}" withimageset=yes imageset="${exposure_prefix_oot}${diagn_suffix}".fits \
        filtertype=expression expression="(PI in [${anom_elo}:${anom_ehi}])&&${event_pattern}&&${area_flag}" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 | tee "./_log_${exposure_prefix_oot}_evselect.txt" &

        wait $!

        if [ -f "${PWD}/${exposure_prefix}${diagn_suffix}.fits" ] ;then
            ## DS9 export image(s)
            ds9 "${PWD}/${exposure_prefix}${diagn_suffix}.fits" -scale log -cmap heat -zoom to fit -zoom to fit -saveimage png "${PWD}/${exposure_prefix}${diagn_suffix}-${anom_elo}-${anom_ehi}.png" -exit &
            wait $!
        else
            echo "${exposure_prefix}${diagn_suffix}.fits not found for DS9 export"
        fi
        if [ -f "${PWD}/${exposure_prefix_oot}${diagn_suffix}.fits" ] ;then
            ds9 "${PWD}/${exposure_prefix_oot}${diagn_suffix}.fits" -scale log -cmap heat -zoom to fit -zoom to fit -saveimage png "${PWD}/${exposure_prefix_oot}${diagn_suffix}-${anom_elo}-${anom_ehi}.png" -exit &
            wait $!
        else
            echo "${exposure_prefix_oot}${diagn_suffix}.fits not found for DS9 export"
        fi

        ## Pre-espfilt images
        create_event_file_images "${in_file}"

        ## espfilt; From the ESAS Cookbook V21.0; 5.10
        ## Soft Proton Flare Filtering
        ##   Procedure checks flaring at high energies independently of output elow/ehigh range provided

        # "If there is a bright extended source in the FOV,
        # increasing the rangescale to 10 for the MOS
        # and 25 for the pn may be necessary to get a good fit."
        #     default rangescale=15.0
        espfilt eventfile="${in_file}" elow="${esp_elo}" ehigh="${esp_ehi}" \
        withsmoothing=yes smooth=51 rangescale=15.0 allowsigma=3.0 method=histogram \
        withoot=Y ootfile="${in_file_oot}" keepinterfiles=false | tee "./_log_${exposure_prefix}_espfilt.txt"

        wait $!

    fi

    #### ---
    ##
        # Check for espfilt outputs and if found:
        #   - Create images
        #   - Apply low and high energy cutoffs to events list of cleaned espfilt output
    ##
    ####

    exposure_allevc_out="${detector}${EXPOSURE}-allevc.fits"
    if [ -f "${exposure_allevc_out}" ] ;then
        detector_highlights+=("espfilt_out:${exposure_allevc_out}")

        ## Post-espfilt images
        create_event_file_images "${exposure_allevc_out}"

        ## Applying elow/ehigh cutoffs to allevc
        evselect table="${exposure_allevc_out}":EVENTS withfilteredset=yes \
        expression="(PI in [${det_elo}:${det_ehi}])&&${event_pattern}&&${area_flag}" \
        filteredset="${detector}${EXPOSURE}-evc-cut.fits" filtertype=expression keepfilteroutput=yes

        ## *** store ELO/EHI in header for later processing, alongside EHIGH/ELOW stored by espfilt
        ## *** http://tdc-www.harvard.edu/software/wcstools/sethead/sethead.ex.html

        detector_highlights+=("cut_elow:${det_elo}")
        detector_highlights+=("cut_ehigh:${det_ehi}")
        detector_highlights+=("espfilt_out_cut:${detector}${EXPOSURE}-evc-cut.fits")

        ## Post-espfilt *CUT* images
        create_event_file_images "${detector}${EXPOSURE}-evc-cut.fits"

    else
        detector_highlights+=("espfilt_out:MISSING ( <[*,*]> WARNING )")
        echo
        echo "<[*,*]> ${exposure_allevc_out} not found"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo
    fi

    if [ -f "${detector}${EXPOSURE}-allevcoot.fits" ] ;then
        detector_highlights+=("espfilt_out_oot:${detector}${EXPOSURE}-allevcoot.fits")

        ## Post-espfilt images
        create_event_file_images "${detector}${EXPOSURE}-allevcoot.fits"

        ## Applying elow/ehigh cutoffs to allevcoot
        evselect table="${detector}${EXPOSURE}-allevcoot.fits":EVENTS withfilteredset=yes \
        expression="(PI in [${det_elo}:${det_ehi}])&&${event_pattern}&&${area_flag}" \
        filteredset="${detector}${EXPOSURE}-evcoot-cut.fits" filtertype=expression keepfilteroutput=yes

        ## *** store ELO/EHI in header for later processing, alongside EHIGH/ELOW stored by espfilt
        ## *** http://tdc-www.harvard.edu/software/wcstools/sethead/sethead.ex.html

        detector_highlights+=("espfilt_out_oot_cut:${detector}${EXPOSURE}-evcoot-cut.fits")

        ## Post-espfilt *CUT* images
        create_event_file_images "${detector}${EXPOSURE}-evcoot-cut.fits"

    fi

    exposure_gti_out="${detector}${EXPOSURE}-gti.fits"
    if [ -f "${exposure_gti_out}" ] ;then
        ontime=$(gethead ONTIME "${exposure_gti_out}")

        detector_highlights+=("espfilt_gti_out:${exposure_gti_out}")
        detector_highlights+=("gti_ontime:${ontime}")
    fi

    if [ -f "${PWD}/${detector}${EXPOSURE}-allimc.fits" ] ;then
        ## DS9 export image(s)
        ds9 "${PWD}/${detector}${EXPOSURE}-allimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-allimc-${esp_elo}-${esp_ehi}.png" -exit &
        wait $!
    else
        echo "${detector}${EXPOSURE}-allimc.fits not found for DS9 export"
    fi
    if [ -f "${PWD}/${detector}${EXPOSURE}-corimc.fits" ] ;then
        ## DS9 export image(s)
        ds9 "${PWD}/${detector}${EXPOSURE}-corimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-corimc-${esp_elo}-${esp_ehi}.png" -exit &
        wait $!
    else
        echo "${detector}${EXPOSURE}-corimc.fits not found for DS9 export"
    fi

    diagn_hist_out="${detector}${EXPOSURE}-diagn-hist.gif"
    if [ -f "${PWD}/${detector}${EXPOSURE}-hist.qdp" ] ;then
        echo
        echo "Appending commands to ${detector}${EXPOSURE}-hist.qdp for image hardcopy out"
        echo -e "\nhardcopy ${diagn_hist_out}/gif \nexit" >> "${detector}${EXPOSURE}-hist.qdp"
        echo "Running qdp"
        qdp "${detector}${EXPOSURE}-hist.qdp"
        if [ ! -f "${PWD}/${diagn_hist_out}" ] ;then
            echo "<[*,*]> No hardcopy (gif) found"
        fi
        echo
    else
        echo
        echo "<[*,*]> No espfilt diagnostic histogram found"
        echo "Missing: ${detector}${EXPOSURE}-hist.qdp"
        echo
    fi

    echo
    echo "Diagnostic and cleaning output complete for ${detector}${EXPOSURE}"
    echo "Check ${highlights_outfile} for exposure details"
    echo

    echo
    echo "For ${detector}${EXPOSURE}"
    echo "Writing out to ${highlights_outfile}"
    printf "%s\n" "${detector_highlights[@]}" > "${highlights_outfile}"

    continue

done

#### ---
##
    # Housekeeping
##
####

# Get arrays of P*.FIT files including/excluding e%chain output event files *EVLI*.FIT
chain_out=($( find . -maxdepth 1 -type f -name 'P*.FIT' ))
intermediate_chain_out=($( find . -maxdepth 1 -type f -name 'P*.FIT' -not -name 'P*EVLI*.FIT' ))
# Cp all e%chain outputs to intermediate directory
for i in "${chain_out[@]}"
do
    cp "${i}" intermediates/chain
done

# Rm e%chain intermediates from working directory
for i in "${intermediate_chain_out[@]}"
do
    rm "${i}"
done

# Get arrays of diagnostic and log files to move
diagnostic_files=($( find . -maxdepth 1 -type f -name '*diagn*' ))
# mv all diagnostic files to diagnostics directory
for i in "${diagnostic_files[@]}"
do
    mv "${i}" diagnostics
done

# mv all logs to logs directory
log_files=($( find . -maxdepth 1 -type f -name '*_log_*' ))
for i in "${log_files[@]}"
do
    mv "${i}" logs
done

# Sort espfilt outputs
espfilt_out=($( find . -maxdepth 1 -type f -name '*.fits' ))
qdp_espfilt_out=($( find . -maxdepth 1 -type f -name '*-hist.qdp' ))
primary_espfilt_out=($( find . -maxdepth 1 -type f -name '*.fits' ! -name '*-allevc*.fits' ! -name '*-gti.fits' ! -name '*evc-*.fits' ))

## Copy, then move so I don't need mess with rm and primary files are retained in working dir

# cp all espfilt files to intermediate directory
for i in "${espfilt_out[@]}"
do
    cp "${i}" intermediates/espfilt
done

# mv everything except pipeline-necessary espfilt files to intermediate directory
for i in "${primary_espfilt_out[@]}"
do
    mv "${i}" intermediates/espfilt
done

# mv all espfilt qdp files to intermediate directory
for i in "${qdp_espfilt_out[@]}"
do
    mv "${i}" intermediates/espfilt
done
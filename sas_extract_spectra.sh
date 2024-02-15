#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after (***clarify):
##   - evigweight if diffuse, or proton flare filtering if point
##   - Regions are formatted into selection strings in physical coords

## Pre-requisites
## - WCSTools (For reading fits header info with <gethead>)

## This script ...

## If needed later ***; can check if evigweight run by running following and checking for
##   either nothing returned or WEIGHT str returned
# gethead mos1S001-allevc-evigweight.fits ttype13


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
    # Make directories and vars for housekeeping
##
####

if [ ! -d spectra ]; then
    mkdir spectra
fi

obs_id=""

#### ---
##
    # Energy ranges of response matrices
    # For full energy range;
    #   - MOS 0-11999
    #   - PN  0-20479
    #
    ##  To generate spectrum in desired energy range, a selection expression must be used
    ##  NOT withspecranges/specchannelmin/specchannelmax
    #   - https://www.cosmos.esa.int/web/xmm-newton/sas-thread-pn-spectrum#cav

    # Create expression for energy ranges of final output spectral files
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
    # Spectral bin size
##
####

spectral_bin_size=5

#### ---
##
    # Group min
##
####

group_min=20

#### ---
##
    # Event pattern and detector region flags *** Not used yet
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

#shopt -s nullglob

region_list=()

if [ -f "reg_files.txt" ] ;then

    region_files_list=${1:-"reg_files.txt"}

    echo
    echo "Region Files Listed in $region_files_list:"
    echo


    # List region files in file
    # Updated to work with or without needing newline at end of txt file
    # https://unix.stackexchange.com/a/418067
    while IFS= read -r line || [ -n "$line" ] ;do

        ## Check if file found
        found=""

        ## If extract end after . is empty
        ## append .reg and check if exists

        printf '%s\n' "$line$found"
        region_list+=("${line}")
    done < "$region_files_list"

else

    echo
    echo "<[*,*]> File Not Found For Regions List: $region_files_list"
    echo

    return 1 2> /dev/null || exit 1

fi

echo
echo -n "Continue with the region selection above?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
else
    echo No
    return 1 2> /dev/null || exit 1
fi


#### ---
##
    # Prompt user for which detectors base event files should be prepared for
    #   and then run e%chain for those detectors
    # REMOVED: Menu option for ccd selection has been added (MOS only for now)
    #   and was only partially implemented
    ## NOTE: While using (CCDNR==N) works in selection expression of evselect
    ##         rmfgen and arfgen fail for SAS pipeline if X/Y or DETX/DETY or regions
    ##         are not used to explicitly specify pixels according to DSS(lib)
    ## ERROR:
    ##   ** rmfgen: error (RegionInvalid), DSS regions defined in X/Y and DETX/DETY
    ##     space are unbounded. The ARF can not be calculated
##
####

extract_pn=false
extract_mos1=false
extract_mos2=false

# select_ccds=false
# ccds=""

# mos_ccds_auto=false
# mos_ccd_states="G"


echo
#echo -n "Extract spectra for which EPIC detectors (all/pn/mos/mos1/mos2/ccds/skip)? "
echo -n "Extract spectra for which EPIC detectors (all/pn/mos/mos1/mos2/skip)? "
read response

# if [ "${response}" = "ccds" ] ;then
#     select_ccds=true

#     echo
#     echo -n "Extract spectra for CCDs of which EPIC detector (all_auto/mos1/mos2/mos1_auto/mos2_auto)? "
#     read ccd_response

#     response="${ccd_response%'_'*}" ## Pass through the detector selection to <response> (all/mos1/mos2)

#     if [ "${ccd_response#*'_'}" = "auto" ] ;then
#         mos_ccds_auto=true
#     else
#         echo
#         echo "Enter CCDs on one line (This script does not yet validate CCD entry format)"
#         echo "PN format example for CCD 1, 4, & 8:"
#         echo "NOT IMPLEMENTED HERE YET"
#         echo
#         echo "MOS format example for CCD 1, 4, & 8:"
#         echo "1 4 8"
#         echo -n -e "Enter now:\n"
#         read ccd_response

#         echo
#         echo "CCD string entered as:<${ccd_response}>"

#         ## *Assume* if "fov" is in region list its because no region is provided
#         ## If no region is provided or reg file not found by <evselect>, it will default to FOV*
#         ##   Actually for evselect it will not default to FOV, rmfgen will fail due to "unbounded regions"
#         ## If no regions and ccds selected, adjust <region_list> to have ccd num(s)
#         ## This will then be used later for the file naming suffix

#         ## Actually need a per-detector ccd expression builder somewhere to handle this properly
#         if [ "${region_list[0]}" = "fov" ] ;then
#             region_list=("ccd_${ccd_response// /_}")
#         fi

#         ccds="${ccd_response}"
#     fi

# fi

if [ "${response}" = "all" ] ;then
    echo
    echo "Selected to extract spectra for all EPIC detectors"
    echo

    extract_pn=true
    extract_mos1=true
    extract_mos2=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Selected to extract spectra for PN detector"
    echo

    extract_pn=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Selected to extract spectra for both MOS detectors"
    echo

    extract_mos1=true
    extract_mos2=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Selected to extract spectra for MOS1 detector"
    echo

    extract_mos1=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Selected to extract spectra for MOS2 detector"
    echo

    extract_mos2=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping extracting spectra"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without extracting spectra"
    echo
    return 1 2> /dev/null || exit 1
fi


#### ---
##
    # Find event files to extract spectra from
##
####


# File suffix for event files to use
# *** If empty, check first for mos1S001.fits style, then default to e%chain outputs if nothing found
echo
echo -n "Enter suffix of event files to extract spectra from: "
read evc_suffix


echo
echo "Selecting event files ending with \"${evc_suffix}\" (.fits)"
echo

# Check for files ending with suffix selection
event_suffix_files_found=($( find . -maxdepth 1 -type f -name "*${evc_suffix}.fits" ))
if [[ -n "${event_suffix_files_found[@]}" ]]; then
    echo
    echo "Event files found:"
    printf "%s\n" "${event_suffix_files_found[@]}"
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

#### ---
##
    # Find event files to extract spectra from
##
####

for f in "${event_suffix_files_found[@]}"; do

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

    if [ "${obs_id}" = "" ] ;then
        obs_id=$(gethead OBS_ID "${f}")
    fi

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

    if ! $extract_pn ;then
        if [ "${detector}" = "pn" ] ;then continue ;fi
    fi
    if ! $extract_mos1 ;then
        if [ "${detector}" = "mos1" ] ;then continue ;fi
    fi
    if ! $extract_mos2 ;then
        if [ "${detector}" = "mos2" ] ;then continue ;fi
    fi

    #### ---
    ##
        # Identify event file(s) and proceed with processing
    ##
    ####

    event_file="${f}"

    #### ---
    ##
        # Check header for reasons a specific exposure may be unusable or problematic
        # Create array for logging diagnostic info for current event file:
        #   If a property of the exposure is outside the bounds of this pipeline script,
        #     trigger <exit_early> and skip this exposure after writing out <detector_highlights>
    ##
    ####

    evigweight_col=$(gethead TTYPE13 "${event_file}")
    #detmaptype=


    #### ---
    ##
        # If exit_early not triggered, continue creating diagnostic files (+) for observation/exposure
    ##
    ####

    exposure_prefix="${detector}${EXPOSURE}"
    spectra_prefix="${obs_id}_${detector}${EXPOSURE}"

    for region in "${region_list[@]}"; do

        ## Check for region file

        ## Get name of region from file name
        #region_name="${reg%.*}"

        #region_selection_str="${1:-${reg}}"

        region_selection_str=$(<"${exposure_prefix}_${region}_physical.txt")

        echo "Region:"
        echo $region
        echo
        echo "Region Selection String:"
        echo $region_selection_str
        echo

        spec_out_file="${spectra_prefix}_${region}.fits"
        bkg_file="${spectra_prefix}_background.fits"
        rmf_out_file="${spectra_prefix}_${region}.rmf"
        arf_out_file="${spectra_prefix}_${region}.arf"
        grppha_out_file="${spectra_prefix}_${region}_grp${group_min}.fits"
        grppha_out_bkgsubbed_file="${spectra_prefix}_${region}_grp${group_min}_bkgsubbed.fits"

        # Energy ranges used for filtering final output; adjusted below by detector
        det_elo=0
        det_ehi=0

        specchannelmin=0
        specchannelmax=0

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

            ## DO NOT CHANGE; should be 0-11999
            specchannelmin=0
            specchannelmax=11999

            event_pattern="${pattern_mos}"
            area_flag="${flag_mos_fov}"

        elif [ "${detector}" = "pn" ] ;then

            det_elo="${pn_elo}"
            det_ehi="${pn_ehi}"

            ## DO NOT CHANGE; should be 0-20479
            specchannelmin=0
            specchannelmax=20479

            event_pattern="${pattern_pn_double_down}"
            area_flag="${flag_pn_fov}"

        fi

        #### ---
        ##
            # Extract the spectrum for the given region
            #   - Arguments after <expression> line are for output images of selection regions
            #       ## These are to verify regions were properly selected
        ##
        ####

        evselect table="${event_file}" withspectrumset=yes spectrumset="${spec_out_file}" \
        energycolumn=PI spectralbinsize="${spectral_bin_size}" \
        withspecranges=yes specchannelmin="${specchannelmin}" specchannelmax="${specchannelmax}" \
        expression="(PI in [$det_elo:$det_ehi])&&${event_pattern}&&${area_flag}${region_selection_str}" \
        withimageset=yes imageset="${spec_out_file%.*}_im.fits" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=X ximagesize=780 ximagemax=50000 ximagemin=1 \
        ycolumn=Y yimagesize=780 yimagemax=50000 yimagemin=1 &

        ## The "&" after evselect assigns evselect to a background process
        ## The background process is retrieved from the $! env variable
        ## We can then wait for the background process to finish before running ds9
        wait $!

        mv ${spec_out_file%.*}_im.fits spectra

        backscale spectrumset="${spec_out_file}" badpixlocation="${event_file}" &
        wait $!

        rmfgen spectrumset="${spec_out_file}" rmfset="${rmf_out_file}" &
        wait $!

        arfgen spectrumset="${spec_out_file}" arfset="${arf_out_file}" withrmfset=yes rmfset="${rmf_out_file}" \
        badpixlocation="${event_file}" detmaptype=flat extendedsource=yes &
        wait $!

        #### ---
        ##
            # Grouping spectra outputs:
            #   - We will first group with no BACKFILE; both for background and source spectra
            #   - If background subracting in XSPEC; DO NOT USE GROUPED background
            #       ## 8.3.2 Grouping; https://heasarc.gsfc.nasa.gov/docs/asca/abc/node9.html
            #       ## "Note that background files should not be grouped since XSPEC will
            #       ##    automatically group the background to match the source data."
            #   - If this loop is NOT background spectrum, and background spectra is found
            #       ## create an additional src group adding background file for BACKSCALE
        ##
        ####

        grppha infile="${spec_out_file}" outfile=${grppha_out_file} \
        comm="chkey ANCRFILE ${arf_out_file} & chkey RESPFILE ${rmf_out_file} \
        & chkey BACKFILE none & group min ${group_min} & exit" \
        clobber=yes &

        wait $!

        ## Running again passing last input in and back out without changes
        ##   to display updated information in the command line and see updated arf, rmf, bkg chkeys
        grppha infile=${grppha_out_file} outfile=${grppha_out_file} comm="show all & exit" clobber=yes &

        wait $!

        ### Check for BACKFILE
        ## If current loop is extracting background spectrum, there is no BACKFILE; continue
        if [ "${region}" = "background" ] ;then continue ;fi

        ## If no background file is found, there is no BACKFILE; continue
        if [ ! -f "${bkg_file}" ] ;then continue ;fi

        grppha infile="${spec_out_file}" outfile=${grppha_out_bkgsubbed_file} \
        comm="chkey ANCRFILE ${arf_out_file} & chkey RESPFILE ${rmf_out_file} \
        & chkey BACKFILE ${bkg_file} & group min ${group_min} & exit" \
        clobber=yes &

        wait $!

        ## Running again passing last input in and back out without changes
        ##   to display updated information in the command line and see updated arf, rmf, bkg chkeys
        grppha infile=${grppha_out_bkgsubbed_file} outfile=${grppha_out_bkgsubbed_file} comm="show all & exit" clobber=yes &

        wait $!


        continue

    done

done



#### ---
##
    # Housekeeping
##
####

# Get arrays of spectra-related products to move
spectra_out_files=($( find . -maxdepth 1 -type f -name "${obs_id}_*" ))
## Not doing this for now since want background files to remain, possibly query regarding this

# for i in "${spectra_out_files[@]}"
# do
#     mv "${i}" spectra
# done
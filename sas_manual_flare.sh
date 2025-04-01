#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after esas_initial_reduction.sh if espfilt fails due to excessive flaring, but possible good times are visible ##

## Pre-requisites
## - WCSTools (For reading fits header info with <gethead>)

## NOTE
# Referencing:
# - Notes by Dr. Katie Auchettl
# - Steps for filtering EPIC background at following link
#     https://www.cosmos.esa.int/web/xmm-newton/sas-thread-epic-filterbackground


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

get_pn_rates=false
get_mos1_rates=false
get_mos2_rates=false

echo
echo -n "Get rates for which EPIC detectors (all/pn/mos/mos1/mos2/skip)? "
read response

if [ "${response}" = "all" ] ;then
    echo
    echo "Elected to get rates for all EPIC detectors"
    echo

    get_pn_rates=true
    get_mos1_rates=true
    get_mos2_rates=true

elif [ "${response}" = "pn" ] ;then

    echo
    echo "Elected to get rates for PN detector"
    echo

    get_pn_rates=true

elif [ "${response}" = "mos" ] ;then

    echo
    echo "Elected to get rates for both MOS detectors"
    echo

    get_mos1_rates=true
    get_mos2_rates=true

elif [ "${response}" = "mos1" ] ;then

    echo
    echo "Elected to get rates for MOS1 detector"
    echo

    get_mos1_rates=true

elif [ "${response}" = "mos2" ] ;then

    echo
    echo "Elected to get rates for MOS2 detector"
    echo

    get_mos2_rates=true

elif [ "${response}" = "skip" ] ;then
    echo
    echo "<[*,*]> Skipping rates"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "<[*,*]> Exiting without getting rates"
    echo
    return 1 2> /dev/null || exit 1
fi


# Check for ANY event files originally output from e%chain in esas_initial_reduction.sh; exit if none found
event_chain_out=($( find . -maxdepth 1 -type f -name '*EVLI*.FIT' ))
# Evaluate
if [[ -n "${event_chain_out[@]}" ]]; then
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


##
## Build event file names
##

# List detectors and exposures found from event files
echo
echo "Detectors and Exposures Found:"
echo

# Get list of files containing *EVLI*.FIT
# Using event_chain_out from earlier
exposures=()
for f in "${event_chain_out[@]}"; do

    instrume=$(gethead INSTRUME "${f}") # EMOS1, EMOS2, EPN
    instrume="${instrume:1}" # MOS1, MOS2, PN
    expid=$(gethead EXPIDSTR "${f}")

    #echo "${instrume_lower}${expid}"
    exposures+=("${instrume}${expid}")
done

# Get unique detector/exposure combos (removing pn-oot)
exposures=( $(printf "%s\n" "${exposures[@]}" | sort -u) )

#echo "${exps_lower[@]}"
printf "%s\n" "${exposures[@]}"


##
####
    # Preparing to run evselect for initial view of rates
####
##

# File suffix for <evselect> rate images
rate_suffix="_rate"
gti_suffix="_gti"
filtered_suffix="_filtered"
cleaned_suffix="_clean"

pn_total_flag="#XMMEA_EP" # Includes FOV and corners
mos_total_flag="((FLAG & 0x766aa000)==0)" # <#XMMEA_EM> + corners

pn_corner_flag="(#XMMEA_EP)&&!((DETX,DETY) in circle(-2200,-1100,18080))"
mos_corner_flag="((FLAG & 0x766aa000)==0)&&!(CIRCLE(435,1006,17100,DETX,DETY)||CIRCLE(-34,68,17700,DETX,DETY)||BOX(-20,-17000,6500,500,0,DETX,DETY)||BOX(5880,-20500,7500,1500,10,DETX,DETY)||BOX(-5920,-20500,7500,1500,350,DETX,DETY)||BOX(-20,-20000,5500,500,0,DETX,DETY))"

# <evselect> expressions to select events at energies where detector insensitive to source emission,
# where background emission dominates, and only in FOV
pn_flare_expression="((FLAG & 0xfb0000)==0) && (PI>10000&&PI<12000) && (PATTERN==0)"
mos_flare_expression="#XMMEA_EM && (PI>10000) && (PATTERN==0)"

pn_clean_pattern="(PATTERN<=4)"
mos_clean_pattern="(PATTERN<=12)"

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

    if ! $get_pn_rates ;then
        if [ "${detector}" = "pn" ] ;then continue ;fi
    fi
    if ! $get_mos1_rates ;then
        if [ "${detector}" = "mos1" ] ;then continue ;fi
    fi
    if ! $get_mos2_rates ;then
        if [ "${detector}" = "mos2" ] ;then continue ;fi
    fi

    ##
    ####
        # Identify event file(s) and proceed with processing
    ####
    ##

    event_file=""

    if [ "${detector}" = "mos1" ] || [ "${detector}" = "mos2" ] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"MIEVLI*.FIT)

    elif [ "${detector}" = "pn" ] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"PIEVLI*.FIT)

    fi


    exposure_prefix="${detector}${EXPOSURE}"
    rate_file="${exposure_prefix}${rate_suffix}.fits"
    gti_file="${exposure_prefix}${rate_suffix}${gti_suffix}.fits"
    filtered_file="${exposure_prefix}${rate_suffix}${filtered_suffix}.fits"
    clean_file="${exposure_prefix}${rate_suffix}${cleaned_suffix}.fits"

    detector_flare_expression="${pn_flare_expression}"
    detector_total_flag="${pn_total_flag}"
    detector_corner_flag="${pn_corner_flag}"
    detector_clean_pattern="${pn_clean_pattern}"

    if [ "${detector}" = "mos1" ] || [ "${detector}" = "mos2" ] ;then
        detector_flare_expression="${mos_flare_expression}"
        detector_total_flag="${mos_total_flag}"
        detector_corner_flag="${mos_corner_flag}"
        detector_clean_pattern="${mos_clean_pattern}"
    fi

    evselect table="${event_file}" withrateset=Y rateset="${rate_file}" \
    maketimecolumn=Y timebinsize=10 makeratecolumn=Y \
    expression="${detector_flare_expression}" | tee "${PWD}/_log_${exposure_prefix}${rate_suffix}.txt" &

    wait $!

    if [ -f "${PWD}/${rate_file}" ] ;then
        fv "${rate_file}" &
        #wait $!
        echo
        echo -n "Enter lower cutoff rate for ${exposure_prefix}: "
        read min_rate

        echo -n "Enter upper cutoff rate for ${exposure_prefix}: "
        read max_rate

        ## <[*,*]> Should include check for numerical input

        tabgtigen table="${rate_file}" expression="(RATE>=${min_rate}&&RATE<=${max_rate})" \
        gtiset="${gti_file}"

        evselect table="${event_file}" withfilteredset=Y filteredset="${filtered_file}" destruct=Y \
        keepfilteroutput=T expression="${detector_total_flag} && gti(${gti_file},TIME) && (PI>150)"

        evselect table="${filtered_file}":EVENTS withfilteredset=Y filteredset="${clean_file}" destruct=Y \
        keepfilteroutput=T expression="${detector_total_flag} && ${detector_clean_pattern} && (PI in [500:10000])"

        # FOV and corners for filtering diagnostic
        evselect table="${clean_file}":EVENTS withimageset=yes imageset="${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-allimc.fits" \
        destruct=Y \
        expression="${detector_total_flag} && ${detector_clean_pattern} && (PI in [500:10000])" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499

        # Corners for diagnostic
        evselect table="${clean_file}":EVENTS withimageset=yes imageset="${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-corimc.fits" \
        destruct=Y \
        expression="${detector_corner_flag} && ${detector_clean_pattern} && (PI in [500:10000])" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499



        if [ -f "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-allimc.fits" ] ;then
            ## DS9 export image(s)
            ds9 "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-allimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-allimc.png" -exit &
            wait $!
        else
            echo "${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-allimc.fits not found for DS9 export"
        fi
        if [ -f "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-corimc.fits" ] ;then
            ## DS9 export image(s)
            ds9 "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-corimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-corimc.png" -exit &
            wait $!
        else
            echo "${exposure_prefix}${rate_suffix}${clean_suffix}-diagn-corimc.fits not found for DS9 export"
        fi

    else
        continue
    fi

    # http://www.physics.rutgers.edu/~matilsky/documents/tutorial/node25.html
    # https://heasarc.gsfc.nasa.gov/lheasoft/ftools/caldb/release/help/fplot.txt
    # flcol mos1S001_rate.fits[1]


    #echo -e "LOg Y \nLIne OFf \nMArker ON \nhardcopy ${PWD}/rada.gif/gif \nexit" > /tmp/tmpfile.pco
    #fplot "${rate_file}"[1] TIME RATE - /GIF @/tmp/tempfile.pco
    #rm /tmp/tmpfile.pco


    # Stop after dat or plot out
    continue


    ## From the ESAS Cookbook V21.0; 5.9
    ## Examining CCDs for Anomalous States
    emanom eventfile="${in_file}" keepcorner=no # expected output is mos#S###-anom.log
    ## *** Only 1 emanom file is left over per detector, doesn't leave one per exposure.....
    mv "${detector}${EXPOSURE}-anom.log" "${detector}${EXPOSURE}-diagn-anom.log"

    ## espfilt; From the ESAS Cookbook V21.0; 5.10
    ## Soft Proton Flare Filtering

    # "If there is a bright extended source in the FOV,
    # increasing the rangescale to 10 for the MOS
    # and 25 for the pn may be necessary to get a good fit."
    #     default rangescale=6.0
    espfilt eventfile="${in_file}" elow=2500 ehigh=8500 \
    withsmoothing=yes smooth=51 rangescale=6.0 allowsigma=3.0 method=histogram \
    keepinterfiles=false | tee "./_log_${exposure_prefix}_espfilt.txt"

    wait $!


    exposure_allevc_out="${detector}${EXPOSURE}-allevc.fits"
    if [ -f "${exposure_allevc_out}" ] ;then
        detector_highlights+=("espfilt_out:${exposure_allevc_out}")
    else
        detector_highlights+=("espfilt_out:MISSING ( <[*,*]> WARNING )")
        echo
        echo "<[*,*]> ${exposure_allevc_out} not found"
        echo
        echo "Warning added to: ${highlights_outfile}"
        echo
    fi
    exposure_gti_out="${detector}${EXPOSURE}-gti.fits"
    if [ -f "${exposure_gti_out}" ] ;then
        ontime=$(gethead ONTIME "${exposure_gti_out}")

        detector_highlights+=("espfilt_gti_out:${exposure_gti_out}")
        detector_highlights+=("gti_ontime:${ontime}")
    fi

    if [ -f "${PWD}/${detector}${EXPOSURE}-allimc.fits" ] ;then
        ## DS9 export image(s)
        ds9 "${PWD}/${detector}${EXPOSURE}-allimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-allimc.png" -exit &
        wait $!
    else
        echo "${detector}${EXPOSURE}-allimc.fits not found for DS9 export"
    fi
    if [ -f "${PWD}/${detector}${EXPOSURE}-corimc.fits" ] ;then
        ## DS9 export image(s)
        ds9 "${PWD}/${detector}${EXPOSURE}-corimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-corimc.png" -exit &
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
    echo "Diagnostic output complete for ${detector}${EXPOSURE}"
    echo "Check ${highlights_outfile} for exposure details"
    echo

    echo
    echo "For ${detector}${EXPOSURE}"
    echo "Writing out to ${highlights_outfile}"
    printf "%s\n" "${detector_highlights[@]}" > "${highlights_outfile}"

    continue

done

##
## Housekeeping
##

# Get arrays of rate files to move
rate_files=($( find . -maxdepth 1 -type f -name '*rate*' ))
# mv all rate files to rates directory

if [ ! -d rates ]; then
    mkdir rates
fi

for i in "${rate_files[@]}"
do
    mv "${i}" rates
done




# # Get arrays of diagnostic and log files to move
# diagnostic_files=($( find . -maxdepth 1 -type f -name '*diagn*' ))
# # mv all diagnostic files to diagnostics directory
# for i in "${diagnostic_files[@]}"
# do
#     mv "${i}" diagnostics
# done

# # mv all logs to logs directory
# log_files=($( find . -maxdepth 1 -type f -name '*_log_*' ))
# for i in "${log_files[@]}"
# do
#     mv "${i}" logs
# done

# # Sort espfilt outputs
# espfilt_out=($( find . -maxdepth 1 -type f -name '*.fits' ))
# qdp_espfilt_out=($( find . -maxdepth 1 -type f -name '*-hist.qdp' ))
# primary_espfilt_out=($( find . -maxdepth 1 -type f -name '*.fits' ! -name '*-allevc*.fits' ! -name '*-gti.fits' ))

# ## Copy, then move so I don't need mess with rm and primary files are retained in working dir

# # cp all espfilt files to intermediate directory
# for i in "${espfilt_out[@]}"
# do
#     cp "${i}" intermediates/espfilt
# done

# # mv everything except pipeline-necessary espfilt files to intermediate directory
# for i in "${primary_espfilt_out[@]}"
# do
#     mv "${i}" intermediates/espfilt
# done

# # mv all espfilt qdp files to intermediate directory
# for i in "${qdp_espfilt_out[@]}"
# do
#     mv "${i}" intermediates/espfilt
# done
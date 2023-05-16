#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

## To be run after esas_path.sh ##

## This script runs the emchain and epchain commands for the initial data reduction,
## generating the base event files for the detectors using the most recent CCF and SAS software
## Preprocessed versions of the event files are included in the observation data, but its recommended
## to remake them since it is fast and the latest calibration and software versions will be used

## NOTE
## chain vs proc result in identitical data outputs which differ only in output file names
## From the ESAS Cookbook V21.0; 5.7

_CURRENT_DIR=${PWD##*/}

# Prompt user to check if current directory is acceptable to continue;
# default is cookbook suggested "analysis" directory
if [ $_CURRENT_DIR != "analysis" ]; then

    echo -n "Current directory is not 'analysis'. Continue anyway (y/n)?"
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
        echo "*** Opted NOT to continue in current directory: ${_CURRENT_DIR}"
        echo "Please create an \"analysis\" directory to work from"
        echo "Exiting"
        echo
        return 1 2> /dev/null || exit 1
    fi

fi

##
## Insert a check on exposure counts here; particularly important for EPN
## epchain exposure=99
## From the ESAS Cookbook V21.0; 5.7

## For now

#epchain exposure=99 | tee ./_log_epchain_exposure_count.txt

##


run_epchain=false
run_emchain_mos1=false
run_emchain_mos2=false

echo
echo -n "Run chains for which EPIC detectors (all/pn/mos/mos1/mos2/skip)?"
read response

if [[ "${response}" == "all" ]] ;then
    echo
    echo "Selected chains for all EPIC detectors"
    echo

    run_epchain=true
    run_emchain_mos1=true
    run_emchain_mos2=true

elif [[ "${response}" == "pn" ]] ;then

    echo
    echo "Selected epchain for PN detector"
    echo

    run_epchain=true

elif [[ "${response}" == "mos" ]] ;then

    echo
    echo "Selected emchain for both MOS detectors"
    echo

    run_emchain_mos1=true
    run_emchain_mos2=true

elif [[ "${response}" == "mos1" ]] ;then

    echo
    echo "Selected emchain for MOS1 detector"
    echo

    run_emchain_mos1=true

elif [[ "${response}" == "mos2" ]] ;then

    echo
    echo "Selected emchain for MOS2 detector"
    echo

    run_emchain_mos2=true

elif [[ "${response}" == "skip" ]] ;then
    echo
    echo "*** Skipping e%chains"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "*** Exiting without running chains"
    echo
    return 1 2> /dev/null || exit 1
fi


# epchain package documentation recommends the following parameters and epchain order,
# then also states order of epchain calls is irrelevant
# Raw files *are* cleaned up by second epchain; maybe they're also reused to save time (look into at some point)
if $run_epchain ;then

    echo
    echo "Running chains for PN detector"
    echo

    epchain withoutoftime=Y keepintermediate=raw | tee ./_log_epchain_oot.txt

    # Check for output *PN*OOEVLI*.FIT
    if [ ! -f *PN*OOEVLI*.FIT ] ;then
        echo "*** No Out-of-Time output from epchain"
    fi

    epchain | tee ./_log_epchain.txt

    # Check for output *PN*PIEVLI*.FIT
    if [ ! -f *PN*PIEVLI*.FIT ] ;then
        echo "*** No output from epchain"
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

    emchain instruments=M1 | tee ./_log_emchain_mos1.txt

    # Check for output *M1*MIEVLI*.FIT
    if [ ! -f *M1*MIEVLI*.FIT ] ;then
        echo "*** No output from emchain for MOS1"
    fi

fi

if $run_emchain_mos2 ;then
    
    echo
    echo "Running chain for MOS2 detector"
    echo

    emchain instruments=M2 | tee ./_log_emchain_mos2.txt

    # Check for output *M2*MIEVLI*.FIT
    if [ ! -f *M2*MIEVLI*.FIT ] ;then
        echo "*** No output from emchain for MOS2"
    fi

fi

# Check for ANY event files output from e%chain; exit if none found
event_chain_out=($( find . -maxdepth 1 -type f -name '*EVLI*.FIT' ))
# Evaluate 
if [[ -n "${event_chain_out[@]}" ]]; then
    echo
    echo "e%chain outputs found"
    printf "'%s'\n" "${event_chain_out[@]}"
    echo
else
    echo
    echo "*** No output found for emchain or epchain"
    echo "Cannot continue without event files"
    echo "Exiting"
    echo
    return 1 2> /dev/null || exit 1
fi

# Get arrays of *.FIT files including/excluding e%chain output event files *EVLI*.FIT 
chain_out=($( find . -maxdepth 1 -type f -name '*.FIT' ))
intermediate_chain_out=($( find . -maxdepth 1 -type f -name '*.FIT' -not -name '*EVLI*.FIT' ))
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
## Preparing to run evselect for diagnostic images
##

# Check if want to skip again or specify detector
if [[ "${response}" == "skip" ]] ;then
    echo
    echo "Preparing to run evselect for diagnostic images"
    echo "prior to espfilt"
    echo

    echo
    echo -n "Make diagnostic images for which EPIC detectors (all/pn/mos/mos1/mos2/skip)?"
    read response
fi

    diagnostic_pn_event=false
    diagnostic_mos1_event=false
    diagnostic_mos2_event=false

if [[ "${response}" == "all" ]] ;then
    echo
    echo "Creating diagnostic images for all found exposures"
    echo

    diagnostic_pn_event=true
    diagnostic_mos1_event=true
    diagnostic_mos2_event=true

elif [[ "${response}" == "pn" ]] ;then

    echo
    echo "Creating diagnostic images for PN exposures"
    echo

    diagnostic_pn_event=true

elif [[ "${response}" == "mos" ]] ;then

    echo
    echo "Creating diagnostic images for both MOS exposures"
    echo

    diagnostic_mos1_event=true
    diagnostic_mos2_event=true

elif [[ "${response}" == "mos1" ]] ;then

    echo
    echo "Creating diagnostic images for MOS1 exposures"
    echo

    diagnostic_mos1_event=true

elif [[ "${response}" == "mos2" ]] ;then

    echo
    echo "Creating diagnostic images for MOS2 exposures"
    echo

    diagnostic_mos2_event=true

elif [[ "${response}" == "skip" ]] ;then
    echo
    echo "*** Skipping diagnostic image creation"
    echo
else

    echo
    echo "Desired detectors not explicitly given"
    echo "(all lowercase expected)"
    echo "*** Exiting without creating diagnostic images"
    echo
    return 1 2> /dev/null || exit 1
fi

allevc_csv=()
gti_csv=()

diagn_suffix="-diagn-det-unfilt"

for E in ${exposures[@]}; do

    # Uppercase strings
    SCHED_FLAG=${E: -4:1} # S for Scheduled, U for Unscheduled, X for multi-exposure?
    DETECTOR="${E%$SCHED_FLAG*}" # MOS1, MOS2, PN
    DTCTR=$(echo "${DETECTOR}" | sed 's/OS//') # M1, M2, PN
    EXPOSURE="${E#*$DETECTOR}"

    # Lowercase alternatives
    e=$(echo "${E}" | tr '[:upper:]' '[:lower:]')
    sched_flag=${e: -4:1} # S for Scheduled, U for Unscheduled, X for multi-exposure?
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

    ## Check if diagnostic file desired before continuing iteration
    ## If detector diagnostic flag is false, and then matching current detector is selected, continue
    if [[ "${response}" == "skip" ]] ;then continue ;fi

    if ! $diagnostic_pn_event ;then
        if [[ "${detector}" == "pn" ]] ;then continue ;fi
    fi
    if ! $diagnostic_mos1_event ;then
        if [[ "${detector}" == "mos1" ]] ;then continue ;fi
    fi
    if ! $diagnostic_mos2_event ;then
        if [[ "${detector}" == "mos2" ]] ;then continue ;fi
    fi


    ## If an s or S CANNOT be trimmed from the front of sched_flag,
    ## It must be an unscheduled or multi-exposure observation
    if [ "${sched_flag}" = "${sched_flag#[Ss]}" ] ;then
        echo
        echo "*** sched_flag attribute of exposure ${E} is unscheduled (U) or multi-exposure (X)"
        echo "Aborting this exposure"
        echo
        continue
    fi

    event_file=""
    event_file_oot=""

    if [[ "${detector}" == "mos1" || "${detector}" == "mos2" ]] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"MIEVLI*.FIT)

    elif [[ "${detector}" == "pn" ]] ;then

        event_file=(*"${DTCTR}${EXPOSURE}"PIEVLI*.FIT)
        event_file_oot=(*"${DTCTR}${EXPOSURE}"OOEVLI*.FIT)

    fi

    obs_id=$(gethead OBS_ID "${event_file}")
    datamode=$(gethead DATAMODE "${event_file}") #Instrument Mode (IMAGING or TIMING)
    revolut=$(gethead REVOLUT "${event_file}") #Revolution
    filter=$(gethead FILTER "${event_file}") #Filter ID (ie 'Thin1')
    submode=$(gethead SUBMODE "${event_file}") #Guest Observer Mode (ie 'PrimeFullWindow')
    obs_mode=$(gethead OBS_MODE "${event_file}") #Observation mode (POINTING or SLEW)

    in_file_lead="${obs_id}_${detector}${EXPOSURE}"
    in_file="${in_file_lead}.FIT"
    cp "${event_file}" "${in_file}"

    elo=300
    ehi=1000

    if [[ "${detector}" == "mos1" || "${detector}" == "mos2" ]] ;then
        ## From the ESAS Cookbook V21.0; 5.8
        ## Examining CCDs for Anomalous States
        evselect table="${in_file}" withimageset=yes imageset="${in_file_lead}${diagn_suffix}".FIT \
        filtertype=expression expression="(PI in [$elo:$ehi])&& (PATTERN<=12)&&((FLAG & 0x766aa000)==0)" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 &

        ## The "&" after evselect assigns evselect to a background process
        ## The background process is retrieved from the $! env variable
        ## We can then wait for the background process to finish before running ds9
        wait $!

        ## DS9 export images
        ds9 "${PWD}/${in_file_lead}${diagn_suffix}.FIT" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${in_file_lead}${diagn_suffix}-${elo}-${ehi}.png" -exit &
        wait $!

        ## From the ESAS Cookbook V21.0; 5.9
        ## Examining CCDs for Anomalous States
        emanom eventfile="${in_file}" keepcorner=no # expected output is mos#S###-anom.log

        mv "${detector}${EXPOSURE}-anom.log" "${detector}${EXPOSURE}-diagn-anom.log"

        ## espfilt; From the ESAS Cookbook V21.0; 5.10
        ## Soft Proton Flare Filtering

        # "If there is a bright extended source in the FOV,
        # increasing the rangescale to 10 for the MOS
        # and 25 for the pn may be necessary to get a good fit."
        espfilt eventfile="${in_file}" elow=2500 ehigh=8500 \
        withsmoothing=yes smooth=51 rangescale=6.0 allowsigma=3.0 method=histogram \
        keepinterfiles=false

        wait $!

    elif [[ "${detector}" == "pn" ]] ;then

        in_file_oot_lead="${obs_id}_${detector}${EXPOSURE}_oot"
        in_file_oot="${in_file_oot_lead}.FIT"
        cp "${event_file_oot}" "${in_file_oot}"

        ## From the ESAS Cookbook V21.0; 5.8
        ## Examining CCDs for Anomalous States
        evselect table="${in_file}" withimageset=yes imageset="${in_file_lead}${diagn_suffix}".FIT \
        filtertype=expression expression="(PI in [$elo:$ehi])&& (PATTERN <= 4)&&(#XMMEA_EP)" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 &

        wait $!

        evselect table="${in_file_oot}" withimageset=yes imageset="${in_file_oot_lead}${diagn_suffix}".FIT \
        filtertype=expression expression="(PI in [$elo:$ehi])&& (PATTERN <= 4)&&(#XMMEA_EP)" \
        ignorelegallimits=yes imagebinning=imageSize \
        xcolumn=DETX ximagesize=780 ximagemax=19500 ximagemin=-19499 \
        ycolumn=DETY yimagesize=780 yimagemax=19500 yimagemin=-19499 &

        wait $!

        ## DS9 export images
        ds9 "${PWD}/${in_file_lead}${diagn_suffix}.FIT" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${in_file_lead}${diagn_suffix}-${elo}-${ehi}.png" -exit &
        wait $!
        ds9 "${PWD}/${in_file_oot_lead}${diagn_suffix}.FIT" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${in_file_oot_lead}${diagn_suffix}-${elo}-${ehi}.png" -exit &
        wait $!

        ## espfilt; From the ESAS Cookbook V21.0; 5.10
        ## Soft Proton Flare Filtering

        # "If there is a bright extended source in the FOV,
        # increasing the rangescale to 10 for the MOS
        # and 25 for the pn may be necessary to get a good fit."
        espfilt eventfile=${in_file} elow=2500 ehigh=8500 \
        withsmoothing=yes smooth=51 rangescale=15.0 allowsigma=3.0 method=histogram \
        withoot=Y ootfile=${in_file_oot} keepinterfiles=false

        allevc_csv+=("${detector},${EXPOSURE},${detector}${EXPOSURE}-allevcoot.fits")

    fi

    allevc_csv+=("${detector},${EXPOSURE},${detector}${EXPOSURE}-allevc.fits")
    gti_csv+=("${detector},${EXPOSURE},${detector}${EXPOSURE}-gti.fits")

    ## DS9 export images
    ds9 "${PWD}/${detector}${EXPOSURE}-allimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-allimc.png" -exit &
    wait $!
    ds9 "${PWD}/${detector}${EXPOSURE}-corimc.fits" -scale log -cmap heat -zoom to fit -saveimage png "${PWD}/${detector}${EXPOSURE}-diagn-corimc.png" -exit &
    wait $!

    echo -e "\nhardcopy ${detector}${EXPOSURE}-diagn-hist.gif/gif \nexit" >> "${detector}${EXPOSURE}-hist.qdp"
    qdp "${detector}${EXPOSURE}-hist.qdp"

    echo $event_file
    continue

    # spectra_continue=false

done

##
## Housekeeping
##

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
primary_espfilt_out=($( find . -maxdepth 1 -type f -name '*.fits' ! -name '*-allevc*.fits' ! -name '*-gti.fits' ))

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


printf "%s\n" "${allevc_csv[@]}" > meta/allevc_csv.txt
printf "%s\n" "${gti_csv[@]}" > meta/gti_csv.txt
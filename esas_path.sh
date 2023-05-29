#!/bin/bash

# Make sure to *source* and not just run script
# $. script.sh
# NOT
# $script.sh

_CURRENT_DIR=${PWD##*/}

# Prompt user to check if current directory is acceptable to continue;
# default is cookbook suggested "analysis" directory
if [ $_CURRENT_DIR != "analysis" ]; then

    echo -n "Current directory is not 'analysis'. Continue anyway (y/n)?"
    read response

    if [ "$response" != "${response#[Yy]}" ] ;then
        echo
        echo "Continuing in current directory: ${_CURRENT_DIR}"
        echo
    else
        echo
        echo "Opted NOT to continue in current directory: ${_CURRENT_DIR}"
        echo "Please create an \"analysis\" directory to work from"
        echo "*_* Exiting"
        echo
        return 1 2> /dev/null || exit 1
    fi

fi

export SAS_CCF="${PWD}/ccf.cif"

echo
echo "Pushing to parent directory"
pushd ..
#***_OBD_ID=${PWD##*/}

# Check for and retrieve odf directory; exit if not found in parent directory
if [ -d "./odf" ]; then
    echo
    echo "Pushing to odf directory"
    pushd ./odf
    export SAS_ODF="${PWD}/"
    echo
    echo "Popping to parent directory"
    popd
else
    echo
    echo "*_* No odf directory found in parent of working directory"
    echo "(where \"odf\" is expected to be lowercase)"
    echo "Popping back to working directory"
    popd
    echo
    echo "Exiting"
    return 1 2> /dev/null || exit 1
fi

echo
echo "Popping to working directory"
popd

echo
echo "EXPORTED DIRECTORIES:"
echo "SAS_ODF=${SAS_ODF}"
echo "SAS_CCF=${SAS_CCF}"
echo

#pushd ..
if [[ ! -d spectral_products ]]; then
    mkdir spectral_products
fi
if [[ ! -d intermediates ]]; then
    mkdir intermediates
    mkdir intermediates/chain
    mkdir intermediates/espfilt
    mkdir intermediates/filter
fi
if [[ ! -d logs ]]; then
    mkdir logs
fi
if [[ ! -d diagnostics ]]; then
    mkdir diagnostics
fi
if [[ ! -d meta ]]; then
    mkdir meta
fi
#popd

echo
echo -n "Run from cifbuild and odfingest (y/n)?"
read response

# This grammar (the #[] operator) trims the first leading y or Y from the string
# If a y or Y is removed from the start of the word, the compared arguments are different, and a "yes" intention is assumed
# This means a "return" is considered a no for safety to avoid overwriting files accidentally
if [ "${response}" != "${response#[Yy]}" ] ;then
    echo
    echo Creating cif file and 
    echo
    
    # Overwrites current cif.cif file in directory
    cifbuild withccfpath=no analysisdate=now category=XMMCCF calindexset="${SAS_CCF}" fullpath=yes | tee ./_log_cifbuild.txt
    
    # Remove *.SAS files included from original pipeline processing and rebuild them
    rm "${SAS_ODF}"/*.SAS
    odfingest odfdir="${SAS_ODF}" outdir="${SAS_ODF}" | tee ./_log_odfingest.txt

    #***
    # wait $!

    # epchain withoutoftime=true

    # wait $!

    # epchain

    # wait $!
    # echo "epchain returned?"
    # echo "pn-filter about to start?"

    # pn-filter

    # wait $!

    # emchain

    # wait $!

    # mos-filter | tee ./_log_mos-filter.txt

    # # Get list of files containing *-obj-image-det-soft.fits
    # # For each one get instrument name, exposure id; save out detector soft band image
    # shopt -s nullglob
    # mosFiles=( mos*-obj-image-det-soft.fits )
    # #echo ${mosFiles[@]}
    # for f in ${mosFiles[@]}; do
    #     instrume=$(gethead INSTRUME "$f") # EMOS1, EMOS2, EPN
    #     instrume="${instrume:1}" # MOS1, MOS2, PN
    #     instrume=$(echo "$instrume" | tr '[:upper:]' '[:lower:]') # mos1, mos2, pn
    #     expid=$(gethead EXPIDSTR "$f")

    #     ds9 "./$f" -scale log -cmap sls -zoom to fit -saveimage png "./$instrume$expid-det-soft.png" -exit &
    #     #ds9 "${_CURRENT_DIR}/$f" -scale log -cmap sls -zoom to fit -saveimage png "${_CURRENT_DIR}/$instrume$expid-det-soft.png" -exit &
    #     wait $!
    #     echo "Saved image as: $instrume$expid"
    # done
    # shopt -u nullglob

    # wait $!

    # rm -f *FIT # From XMM ESAS Cookbook

    # wait $!

    # ## Should log output from mos-filter regarding potentially anomolous ccds
    # pushd ..
    # zip -r filtered.zip analysis
    # popd
    #***

else
    echo
    echo "Opted not to run cifbuild and odfingest tasks"
    echo "Exiting"
    echo
    return 1 2> /dev/null || exit 1
fi

#***

# cheese prefixm=1S001 scale=0.20 mask=1 rate=0.01 rates=0.01 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000

# xmmselect table=mos1S001-clean.fits%EVENTS

# mos-spectra prefix=1S001 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=pnS003_backtest.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1



# _ODFPATH="./$_OBSID/odf"
# _ANALYSISPATH="./$_OBSID/analysis"

# _OBSIDTARGZ="$_OBSID.tar.gz" # Primary archive in odf
# #_OBSIDTAR="*$_OBSID.TAR" # Secondary archive a few levels into primary
# # Take given observation directory

# # Check if in current directory

# if [ -d "./$_OBSID" ]
# then
#     echo "Observation directory found containing XXX"

#     #if analysis, ask if wish to continue analysis

#     # else if odf, ask if prepare observation for reduction

#     if [[ -d $_ANALYSISPATH ]]
#     then
#         echo "analysis found."
#     elif [[ -d $_ODFPATH ]]
#     then
#         echo "odf directory found."# Temp dir is set to ->$TMP<-"
#     else
#         echo "odf nor analysis found"
#     fi

#     # ## https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
#     echo -n "Continue? y/n: "
#     read answer

#     if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
#         echo "Onwards!"
#     else
#         return
#     fi

# # else
# #     echo "Directory for observation $_OBSID not found in current directory. Exiting."
# #     return
# fi

# # Assuming yes above for odf

# #push pop
# pushd $_ODFPATH

# if [ -f "$_OBSIDTARGZ" ]
# then
#     # mkdir "$TMP/$_OBSID"
#     # cp ./$_OBSTARGZ $TMP/$_OBSID

#     # #push
#     # pushd $TMP/$_OBSID
#     # #_OBSIDTARGZ="$(find . -type f -iname "*.tar.gz")"
#     tar -zxvf $_OBSIDTARGZ

#     #push
#     #pushd ./$_OBSID
#     _OBSIDTAR="${find . -type f -iname '*.TAR'}"
#     tar -xvf $_OBSIDTAR

#     #_EXTRACTDIR="$(find . -type d)"

#     #mv ./$_EXTRACTDIR/* ./

#     #rmdir ./$_EXTRACTDIR
#     # This tar is enclosed inside the tar.gz and unzipped takes up over 1GB
#     # Leaving the tar.gz incase need to reset the files...
#     # Means I can delete the original download zip and still reset
#     rm -v $_OBSIDTAR

#     #_TMPODFDIR="$(pwd)"

#     #pop pop
#     #popd
#     #popd
#     #mv /_TMPODFDIR/* .

#     #rmdir /$TMP/$_OBSID

#     #pop
#     popd
#     echo "Observation odf setup."

# else
#     popd
#     echo "Observation tar.gz not found. Exiting."
# fi

# # Ask if like to initialize observation for 

# # Check for observation directories and list if not given one
# # Need temp

# # Check if temp directory exists and is assigned
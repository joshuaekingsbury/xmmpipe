#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR == "analysis" ]; then

    #_OBD_ID=${PWD%/*}
    #_OBS_ID=${_PARENT_DIR:1}

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

echo -n "Run from cifbuild thru to mos-filter (y/n)? "
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes

    cifbuild withccfpath=no analysisdate=now category=XMMCCF calindexset=$SAS_CCF fullpath=yes

    wait $!

    odfingest odfdir=$SAS_ODF outdir=$SAS_ODF

    wait $!

    epchain withoutoftime=true

    wait $!

    epchain

    wait $!
    echo "epchain returned?"
    echo "pn-filter about to start?"

    pn-filter

    wait $!

    emchain

    wait $!

    mos-filter | tee ./_log_mos-filter.txt

    wait $!

    ## Should log output from mos-filter regarding potentially anomolous ccds

else
    echo No
    break;
fi

# cheese prefixm=1S001 scale=0.20 mask=1 rate=0.01 rates=0.01 rateh=0.01 dist=15.0 clobber=1 elow=300 ehigh=7000

# xmmselect table=mos1S001-clean.fits%EVENTS

# mos-spectra prefix=1S001 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1




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
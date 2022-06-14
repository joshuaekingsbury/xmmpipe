#!/bin/bash

_OBSID=$1

_ODFPATH="./$_OBSID/odf"
_ANALYSISPATH="./$_OBSID/analysis"

_OBSIDTARGZ="$_OBSID.tar.gz" # Primary archive in odf
#_OBSIDTAR="*$_OBSID.TAR" # Secondary archive a few levels into primary
# Take given observation directory

# Check if in current directory

#####_tar -xzf *.gz;tar -xf *.TAR; rm *.TAR


if [ -d "./$_OBSID" ]
then
    echo "Observation directory found containing XXX"

    #if analysis, ask if wish to continue analysis

    # else if odf, ask if prepare observation for reduction

    if [[ -d $_ANALYSISPATH ]]
    then
        echo "analysis found."
    elif [[ -d $_ODFPATH ]]
    then
        echo "odf directory found."# Temp dir is set to ->$TMP<-"
    else
        echo "odf nor analysis found"
    fi

    # ## https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
    echo -n "Continue? y/n: "
    read answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
        echo "Onwards!"
    else
        return
    fi

# else
#     echo "Directory for observation $_OBSID not found in current directory. Exiting."
#     return
fi

# Assuming yes above for odf

#push pop
pushd $_ODFPATH

if [ -f "$_OBSIDTARGZ" ]
then
    # mkdir "$TMP/$_OBSID"
    # cp ./$_OBSTARGZ $TMP/$_OBSID

    # #push
    # pushd $TMP/$_OBSID
    # #_OBSIDTARGZ="$(find . -type f -iname "*.tar.gz")"
    tar -zxvf $_OBSIDTARGZ

    #push
    #pushd ./$_OBSID
    _OBSIDTAR="${find . -type f -iname '*.TAR'}"
    tar -xvf $_OBSIDTAR

    #_EXTRACTDIR="$(find . -type d)"

    #mv ./$_EXTRACTDIR/* ./

    #rmdir ./$_EXTRACTDIR
    # This tar is enclosed inside the tar.gz and unzipped takes up over 1GB
    # Leaving the tar.gz incase need to reset the files...
    # Means I can delete the original download zip and still reset
    rm -v $_OBSIDTAR

    #_TMPODFDIR="$(pwd)"

    #pop pop
    #popd
    #popd
    #mv /_TMPODFDIR/* .

    #rmdir /$TMP/$_OBSID

    #pop
    popd
    echo "Observation odf setup."

else
    popd
    echo "Observation tar.gz not found. Exiting."
fi

# Ask if like to initialize observation for 

# Check for observation directories and list if not given one
# Need temp

# Check if temp directory exists and is assigned
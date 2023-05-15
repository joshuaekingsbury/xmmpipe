#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR == "analysis" ]; then

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

echo -n "Run from cifbuild thru to emproc (y/n)? "
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes

    cifbuild withccfpath=no analysisdate=now category=XMMCCF calindexset=$SAS_CCF fullpath=yes

    wait $!

    odfingest odfdir=$SAS_ODF outdir=$SAS_ODF

    wait $!

    epproc | tee ./_log_epproc.txt

    wait $!

    emproc | tee ./_log_emproc.txt

    wait $!

    # Get list of files containing *-obj-image-det-soft.fits
    # For each one get instrument name, exposure id; save out detector soft band image
    shopt -s nullglob
    evtFiles=( *ImagingEvts.ds )
    #echo ${evtFiles[@]}
    for f in ${evtFiles[@]}; do
        instrume=$(gethead INSTRUME "$f") # EMOS1, EMOS2, EPN
        instrume="${instrume:1}" # MOS1, MOS2, PN
        instrume=$(echo "$instrume" | tr '[:upper:]' '[:lower:]') # mos1, mos2, pn
        expid=$(gethead EXPIDSTR "$f")

        cp ./$f ./${instrume}_${expid}.fits
        echo "Renamed events file to: ${instrume}_${expid}.fits"

        wait $!

        evselect table=$f withimageset=yes imageset=${instrume}_${expid}_image.fits \
            xcolumn=X ycolumn=Y imagebinning=imageSize ximagesize=600 yimagesize=600
        echo "Saved fits image as: ${instrume}_${expid}_image.fits"
        wait $!

        ds9 "./${instrume}_${expid}_image.fits" -scale log -cmap he -zoom to fit -saveimage png "./${instrume}_${expid}_image.png" -exit &
        wait $!
        echo "Saved image as: ${instrume}_${expid}_image.png"
    done
    shopt -u nullglob

    wait $!

    # #STANDARD FILTERS 6.3

    # evselect table=MOS1_S001.fits withfilteredset=yes expression='(PATTERN <= 12)&&(PI in [200:12000])&&#XMMEA_EM' filteredset=EMOS1_S001_filt.fits filtertype=expression keepfilteroutput=yes updateexposure=yes filterexposure=yes


    # #CREATE AND DISPLAY A LIGHT CURVE 6.4

    # evselect table=MOS1_S001.fits withrateset=yes rateset=MOS1_S001_ltcrv.fits \
    #     maketimecolumn=yes timecolumn=TIME timebinsize=100 makeratecolumn=yes
        
    # fv MOS1_S001_ltcrv.fits &

    # #APPLYING TIME FILTERS TO THE DATA 6.5

    # tabgtigen table=MOS1_S001_ltcrv.fits gtiset=gtiset.fits timecolumn=TIME \
    #     expression='(RATE <= 9)'

    # evselect table=MOS1_S001_filt.fits withfilteredset=yes \
    #     expression='GTI(gtiset.fits,TIME)' filteredset=MOS1_S001_filt_time.fits \
    #     filtertype=expression keepfilteroutput=yes \
    #     updateexposure=yes filterexposure=yes

    # #SOURCE DETECTION WITH edetect_chain 6.6

    # atthkgen atthkset=attitude.fits timestep=1

    # evselect table=MOS1_S001_filt_time.fits withimageset=yes imageset=MOS1_S001-s.fits imagebinning=binSize xcolumn=X ximagebinsize=22 ycolumn=Y yimagebinsize=22 filtertype=expression expression='(FLAG == 0)&&(PI in [300:2000])'

    # edetect_chain imagesets='MOS1_S001-s.fits MOS1_S001-h.fits' eventsets='MOS1_S001_filt_time.fits' attitudeset=attitude.fits \ 
    #     pimin='300 2000' pimax='2000 10000' likemin=10 witheexpmap=yes \
    #     ecf='0.878 0.220' ebox1_list=eboxlist_1.fits \
    #     eboxm_list=eboxlist_m.fits em1_list=em1list.fits esp_withootset=no

    # srcdisplay boxlistset=em1list.fits imageset=MOS1_S001-s.fits  regionfile=regionfile.txt sourceradius=0.01 withregionfile=yes

    # #EXTRACT THE SOURCE AND BACKGROUND SPECTRA 6.7

    # evselect table='MOS1_S001_filt_time.fits' energycolumn='PI' withfilteredset=yes filteredset='MOS1_S001_filtered.fits' keepfilteroutput=yes filtertype='expression' expression='((X,Y) in CIRCLE(25553.5,23925.5,300))' withspectrumset=yes spectrumset='MOS1_S001_pi.fits' spectralbinsize=5 withspecranges=yes specchannelmin=0 specchannelmax=11999

    # evselect table='MOS1_S001_filt_time.fits' energycolumn='PI' withfilteredset=yes filteredset='MOS1_S001_bkg_filtered.fits' keepfilteroutput=yes filtertype='expression' expression='((X,Y) in CIRCLE(25553.5,23925.5,1500))&&!((X,Y) in CIRCLE(25553.5,23925.5,500))' withspectrumset=yes spectrumset='MOS1_S001_bkg_pi.fits' spectralbinsize=5 withspecranges=yes specchannelmin=0 specchannelmax=11999

    # #6.10

    # backscale spectrumset=MOS1_S001_pi.fits badpixlocation=MOS1_S001_filt_time.fits

    # backscale spectrumset=MOS1_S001_bkg_pi.fits badpixlocation=MOS1_S001_filt_time.fits

    # #6.11

    # rmfgen rmfset=MOS1_S001_rmf.fits spectrumset=MOS1_S001_pi.fits

    # arfgen arfset=MOS1_S001_arf.fits spectrumset=MOS1_S001_pi.fits withrmfset=yes rmfset=MOS1_S001_rmf.fits withbadpixcorr=yes badpixlocation=MOS1_S001_filt_time.fits

    # #13



else
    echo No
    return 1 2> /dev/null || exit 1
fi

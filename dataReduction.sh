#!/bin/bash

# Adapts region files listed in named file for every detector/exposure in current folder

# Requires wcstools
detector=${1:-"all"}

region_files_list=${2:-"reg_files.txt"}
## Check if input file exists

####
elo=300
ehi=7000


_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR != "analysis" ]; then
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
    return 1 2> /dev/null || exit 1
fi

if [[ ! -f $region_files_list ]]; then
    echo "Text file containing region file names not found."
    echo "Either create file reg_files.txt and populate with [region_file].reg;"
    echo "or check that $region_files_list exists."
    return 1 2> /dev/null || exit 1
fi



pushd ..
if [[ ! -d spectral_products ]]; then
    mkdir spectral_products
fi
if [[ ! -d intermediates ]]; then
    mkdir intermediates
fi
# if [[ ! -d logs ]]; then
#     mkdir logs
# fi
popd

##
##

echo
echo "Region Files Listed in $region_files_list:"
echo

# List region files in file
while read -r line
do
    ## Check if file found
    found=""

    ## If extract end after . is empty
    ## append .reg and check if exists

    echo "$line$found"
done < "$region_files_list"

echo
echo -n "Continue with the listed regions files?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
else
    echo No
    return 1 2> /dev/null || exit 1
fi

# List detectors and exposures found
echo
echo "Detectors and Exposures Found:"
echo

# Get list of files containing *-obj-image-sky.fits
det_files=( *-obj-image-sky.fits )
exp_select=()
#echo ${mosFiles[@]}
for f in ${det_files[@]}; do

    instrume=$(gethead INSTRUME "$f") # EMOS1, EMOS2, EPN
    instrume="${instrume:1}" # MOS1, MOS2, PN
    instrume=$(echo "$instrume" | tr '[:upper:]' '[:lower:]') # mos1, mos2, pn
    expid=$(gethead EXPIDSTR "$f")

    if [[ "$instrume" == "$detector" || "$detector" == "all" ]]; then
        echo "$instrume$expid"
        exp_select+="$instrume$expid"
    fi

done

# List detectors and exposures found
echo
echo "Detectors and Exposures Selected for Detector <$detector>."
echo

echo
echo -n "Continue with the selected detector(s) and exposure(s)?"
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
    echo Yes
    echo
else
    echo No
    return 1 2> /dev/null || exit 1
fi

ls >> pre_inventory.txt

# mos-spectra prefix=1S001 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=mos1reg.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1
# pn-spectra prefix=S003 caldb=$ESAS_CALDB region=pnS003_backtest.txt mask=0 elow=300 ehigh=5000 quad1=1 quad2=1 quad3=1 quad4=1

while read -r -u 3 line
do
    for e in ${exp_select[@]}; do
        sched_flag=${e: -4:1} # S for Scheduled, U for Unscheduled, X for multi-exposure?
        exposure=""
        spectra_continue=false

        # echo
        # echo "sched $sched_flag"
        # echo "det ${e%%$sched_flag*}"
        # echo 

        detector=${e%%$sched_flag*}

        # MOS1
        if [[ "$detector" == "mos1" || "$detector" == "mos2" ]]; then
            # Since we know detector is mosX; get XXX-spectra prefix by creating substring
            #exposure="${e:3}"
            exposure="${e#*$detector}"

            if [[ -f "$e-obj.pi" ]]; then

                echo "Found $e-obj.pi"
                echo "Skipping run of mos-spectra as it won't overwrite."
                echo "Either clear all mos-spectra output or start over."

            elif [[ -f "$e-obj-$line.pi" ]]; then

                echo "Found $e-obj-$line.pi. This will be overwritten if script continues."
                echo -n "Continue and overwrite $e-obj-$line.pi?"
                read -p "" answer

                if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
                    echo Yes
                    spectra_continue=true
                else
                    echo No
                    return 1 2> /dev/null || exit 1
                fi

            else
                spectra_continue=true
            fi

            if [[ $spectra_continue == true ]]; then
                if [[ "${e:3:1}" == 1 ]]; then
                    mos-spectra prefix=$exposure caldb=$ESAS_CALDB region="${e}_${line}.txt" mask=0 elow=$elo ehigh=$ehi ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1 | tee ./_log_mos1-spectra_$line.txt
                elif [[ "${e:3:1}" == 2 ]]; then
                    mos-spectra prefix=$exposure caldb=$ESAS_CALDB region="${e}_${line}.txt" mask=0 elow=$elo ehigh=$ehi ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1 | tee ./_log_mos2-spectra_$line.txt
                fi
            fi

            wait $!

            if [[ ! -f "$e-obj.pi" ]]; then
                echo "Output from mos-spectra not found for $e. Aborting mos_back and script."
                return 1 2> /dev/null || exit 1
            fi    

            if [[ "${e:3:1}" == 1 ]]; then
                mos_back prefix=$exposure caldb=$ESAS_CALDB diag=0 elow=$elo ehigh=$ehi ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1 | tee ./_log_mos1_back_$line.txt
            elif [[ "${e:3:1}" == 2 ]]; then
                mos_back prefix=$exposure caldb=$ESAS_CALDB diag=0 elow=$elo ehigh=$ehi ccd1=1 ccd2=1 ccd3=1 ccd4=1 ccd5=1 ccd6=1 ccd7=1 | tee ./_log_mos2_back_$line.txt
            fi


            if [[ ! -f "$e-back.pi" ]]; then
                echo "Output from mos_back not found for $e. Aborting file renaming and grppha."
                return 1 2> /dev/null || exit 1
            fi

            mv $e-obj.pi "$e-obj-$line.pi"
            mv $e-back.pi "$e-back-$line.pi"
            mv $e.rmf "$e-$line.rmf"
            mv $e.arf "$e-$line.arf"
            mv $e-obj-im-sp-det.fits "$e-sp-$line.fits"

            . groupy.sh $e "-$line"

            ## This far only products, regions, and logs have been saved with $line specifier
            ## Ignore txt since they will be moved at end and not overwritten; region files are _$line and so are skipped here too
            #mv *-$line.* ../spectral_products
            find . -maxdepth 1 -type f -iname "*-$line.*" ! -iname "" | xargs -I '{}' mv {} ../spectral_products

        fi

        # pn
        if [[ "$detector" == "pn" ]]; then
            # Since we know detector is pn; get XXX-spectra prefix by creating substring
            #exposure="${e:2}"
            exposure="${e#*$detector}"

            if [[ -f "$e-obj.pi" ]]; then

                echo "Found $e-obj.pi"
                echo "Skipping run of pn-spectra as it won't overwrite."
                echo "Either clear all pn-spectra output or start over."

            elif [[ -f "$e-obj-$line.pi" ]]; then

                echo "Found $e-obj-$line.pi. This will be overwritten if script continues."
                echo -n "Continue and overwrite $e-obj-$line.pi?"
                read -p "" answer

                if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
                    echo Yes
                    spectra_continue=true
                else
                    echo No
                    return 1 2> /dev/null || exit 1
                fi

            else
                spectra_continue=true
            fi

            if [[ $spectra_continue == true ]]; then
                pn-spectra prefix=$exposure caldb=$ESAS_CALDB region="${e}_${line}.txt" mask=0 elow=$elo ehigh=7000 quad1=1 quad2=1 quad3=1 quad4=1 | tee ./_log_pn-spectra_$line.txt
            fi

            wait $!

            if [[ ! -f "$e-obj.pi" ]]; then
                echo "Output from pn-spectra not found. Aborting mos_back and script."
                return 1 2> /dev/null || exit 1
            fi  

            pn_back prefix=$exposure caldb=$ESAS_CALDB diag=0 elow=$elo ehigh=$ehi quad1=1 quad2=1 quad3=1 quad4=1 | tee ./_log_pn_back_$line.txt

            wait $!

            if [[ ! -f "$e-back.pi" ]]; then
                echo "Output from pn_back not found. Aborting file renaming and grppha."
                return 1 2> /dev/null || exit 1
            fi

            mv $e-obj.pi "$e-obj-$line.pi"
            mv $e-back.pi "$e-back-$line.pi"
            mv $e.rmf "$e-$line.rmf"
            mv $e.arf "$e-$line.arf"
            mv $e-obj-im-sp-det.fits "$e-sp-$line.fits"
            mv $e-obj-os.pi "$e-obj-os-$line.pi"

            . groupy.sh $e "-$line"

            ## This far only products, regions, and logs have been saved with $line specifier
            ## Ignore txt since they will be moved at end and not overwritten; region files are _$line and so are skipped here too
            #mv *-$line.* ../spectral_products
            find . -maxdepth 1 -type f -iname "*-$line.*" ! -iname "" | xargs -I '{}' mv {} ../spectral_products
        fi


        ####
        ##  Copy intermediate files and move spectra-related products
        ####

        if [[ -f $e-obj-image-sky.fits && ! -f ../intermediates/$e-obj-image-sky.fits ]]; then
            cp $e-obj-image-sky.fits ../intermediates
            ## DS9 export images
            ds9 "./$e-obj-image-sky.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$e-obj-image-sky.png" -exit &
            wait $!
            ##
        elif [[ ! -f $e-obj-image-sky.fits ]]; then
            echo "$e-obj-image-sky.fits not found in analysis dir; not copied to intermediates"
        fi

        if [[ -f $e-obj-image-det.fits && ! -f ../intermediates/$e-obj-image-det.fits ]]; then
            cp $e-obj-image-det.fits ../intermediates
            ## DS9 export images
            ds9 "./$e-obj-image-det.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$e-obj-image-det.png" -exit &
            wait $!
            ##
        elif [[ ! -f $e-obj-image-det.fits ]]; then
            echo "$e-obj-image-det.fits not found in analysis dir; not copied to intermediates"
        fi

        if [[ -f $e-clean.fits && ! -f ../intermediates/$e-clean.fits ]]; then
            cp $e-clean.fits ../intermediates
            ## DS9 export images
            ds9 "./$e-clean.fits" -scale log -cmap heat -bin to fit -zoom to fit -saveimage png "../intermediates/$e-clean.fits.png" -exit &
            wait $!
            ##
        elif [[ ! -f $e-clean.fits ]]; then
            echo "$e-clean.fits not found in analysis dir; not copied to intermediates"
        fi

        if [[ -f $e-mask-im-det-$elo-$ehi.fits && ! -f ../intermediates/$e-mask-im-det-$elo-$ehi.fits ]]; then
            cp $e-mask-im-det-$elo-$ehi.fits ../intermediates/$e-mask-im-det-$elo-$ehi.fits
            ## DS9 export images
            ds9 "./$e-mask-im-det-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$e-mask-im-det-$elo-$ehi.png" -exit &
            wait $!
            ##
        elif [[ ! -f $e-clean.fits ]]; then
            echo "$e-mask-im-det-$elo-$ehi.fits not found in analysis dir; not copied to intermediates"
        fi

        cp $e-obj-im-$elo-$ehi.fits ../intermediates/$e-obj-im-$elo-$ehi-$line.fits
        ## DS9 export images
        ds9 "./$e-obj-im-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$e-obj-im-det-$elo-$ehi-$line.png" -exit &
        wait $!
        ##

        cp $e-obj-im-det-$elo-$ehi.fits ../intermediates/$e-obj-im-det-$elo-$ehi-$line.fits
        ## DS9 export images
        ds9 "./$e-obj-im-det-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$e-obj-im-det-$elo-$ehi-$line.png" -exit &
        wait $!
        ##

        cp *.jpeg ../intermediates
        cp *.png ../intermediates
        cp *.jpg ../intermediates

        cp *.txt ../intermediates
        cp *.reg ../intermediates

        cp "$region_files_list" ../spectral_products

        ####

        ####
        ##  Clean up directory by deleting any files made since the script began running
        ####

        ls >> post_inventory.txt

        grep -Fxv -f pre_inventory.txt post_inventory.txt >> diff_inventory.txt

        while read -r file_to_remove
        do
            echo "$file_to_remove"
            rm "$file_to_remove"
        done < "diff_inventory.txt"

        rm diff_inventory.txt

        ####

    done


done 3< "$region_files_list"



# https://stackoverflow.com/questions/11704353/bash-nested-interactive-read-within-a-loop-thats-also-using-read
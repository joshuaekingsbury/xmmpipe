
#!/bin/bash


det=$1
reg=$2
elo=$3
ehi=$4
region_files_list=${5:-"reg_files.txt"}


_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR != "analysis" ]; then
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
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


cp $det-obj.pi "$det-obj-$reg.pi"
cp $det-back.pi "$det-back-$reg.pi"
cp $det.rmf "$det-$reg.rmf"
cp $det.arf "$det-$reg.arf"
cp $det-obj-im-sp-det.fits "$det-sp-$reg.fits"
cp $det-obj-os.pi "$det-obj-os-$reg.pi"
. groupy.sh "$det" "-$reg"


## This far only products, regions, and logs have been saved with $reg specifier
## Ignore txt since they will be moved at end and not overwritten; region files are _$reg and so are skipped here too
#mv *-$reg.* ../spectral_products
find . -maxdepth 1 -type f -iname "*-$reg.*" ! -iname "" | xargs -I '{}' cp {} ../spectral_products


####
##  Copy intermediate files and move spectra-related products
####

if [[ -f $det-obj-image-sky.fits && ! -f ../intermediates/$det-obj-image-sky.fits ]]; then
    cp $det-obj-image-sky.fits ../intermediates
    ## DS9 export images
    ds9 "./$det-obj-image-sky.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$det-obj-image-sky.png" -exit &
    wait $!
    ##
elif [[ ! -f $det-obj-image-sky.fits ]]; then
    echo "$det-obj-image-sky.fits not found in analysis dir; not copied to intermediates"
fi

if [[ -f $det-obj-image-det.fits && ! -f ../intermediates/$det-obj-image-det.fits ]]; then
    cp $det-obj-image-det.fits ../intermediates
    ## DS9 export images
    ds9 "./$det-obj-image-det.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$det-obj-image-det.png" -exit &
    wait $!
    ##
elif [[ ! -f $det-obj-image-det.fits ]]; then
    echo "$det-obj-image-det.fits not found in analysis dir; not copied to intermediates"
fi

if [[ -f $det-clean.fits && ! -f ../intermediates/$det-clean.fits ]]; then
    cp $det-clean.fits ../intermediates
    ## DS9 export images
    ds9 "./$det-clean.fits" -scale log -cmap heat -bin to fit -zoom to fit -saveimage png "../intermediates/$det-clean.fits.png" -exit &
    wait $!
    ##
elif [[ ! -f $det-clean.fits ]]; then
    echo "$det-clean.fits not found in analysis dir; not copied to intermediates"
fi

if [[ -f $det-mask-im-det-$elo-$ehi.fits && ! -f ../intermediates/$det-mask-im-det-$elo-$ehi.fits ]]; then
    cp $det-mask-im-det-$elo-$ehi.fits ../intermediates/$det-mask-im-det-$elo-$ehi.fits
    ## DS9 export images
    ds9 "./$det-mask-im-det-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$det-mask-im-det-$elo-$ehi.png" -exit &
    wait $!
    ##
elif [[ ! -f $det-clean.fits ]]; then
    echo "$det-mask-im-det-$elo-$ehi.fits not found in analysis dir; not copied to intermediates"
fi

cp $det-obj-im-$elo-$ehi.fits ../intermediates/$det-obj-im-$elo-$ehi-$reg.fits
## DS9 export images
ds9 "./$det-obj-im-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$det-obj-im-det-$elo-$ehi-$reg.png" -exit &
wait $!
##

cp $det-obj-im-det-$elo-$ehi.fits ../intermediates/$det-obj-im-det-$elo-$ehi-$reg.fits
## DS9 export images
ds9 "./$det-obj-im-det-$elo-$ehi.fits" -scale log -cmap heat -zoom to fit -saveimage png "../intermediates/$det-obj-im-det-$elo-$ehi-$reg.png" -exit &
wait $!
##

cp *.jpeg ../intermediates
cp *.png ../intermediates
cp *.jpg ../intermediates

cp *.txt ../intermediates
cp *.reg ../intermediates

cp "$region_files_list" ../spectral_products

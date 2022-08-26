
# After regular group.sh has run during normal processing, can run this to clean up and create background subtracted files
# Is a temp fix since all data has already been reduced
# Next is to update groupy.sh and groupy_back.sh to rename files this way directly after processing
# . id_products.sh <observation id> <detectorExposure> <energy low ev> <energy high ev>
# . id_products.sh 0657802301 pnS003 300 7000

obs=$1
det=$2
elo=$3
ehi=$4
region_files_list=${5:-"reg_files.txt"}

_CURRENT_DIR=${PWD##*/}

if [ $_CURRENT_DIR != "spectral_products" ]; then
    echo
    echo "Current directory is not 'spectral_products'. Try again. ;)"
    echo
    return 1 2> /dev/null || exit 1
fi

if [[ ! -f $region_files_list ]]; then
    echo "Text file containing region file names not found."
    echo "Either create file reg_files.txt and populate with [region_file].reg;"
    echo "or check that $region_files_list exists."
    return 1 2> /dev/null || exit 1
fi

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

while read -r reg
do

    # cp $det-obj.pi "$det-obj-$reg.pi"
    # cp $det-back.pi "$det-back-$reg.pi"
    # cp $det.rmf "$det-$reg.rmf"
    # cp $det.arf "$det-$reg.arf"
    # cp $det-obj-im-sp-det.fits "$det-sp-$reg.fits"
    # cp $det-obj-os.pi "$det-obj-os-$reg.pi"
    # . groupy.sh "$det" "-$reg"

    #Probably not set up for MOS, just PN

    cp "$det-obj-$reg.pi" "${obs}-obj-$reg.pi" 
    cp "$det-back-$reg.pi" "${obs}-back-$reg.pi" 
    cp "$det-$reg.rmf" "${obs}-$reg.rmf" 
    cp "$det-$reg.arf" "${obs}-$reg.arf" 
    cp "$det-sp-$reg.fits" "${obs}-sp-$reg.fits"
    cp "$det-obj-os-$reg.pi" "${obs}-obj-os-$reg.pi" 
    . groupy.sh "${obs}" "-$reg"

done < "$region_files_list"

. groupy_back.sh "${det}" $elo $ehi


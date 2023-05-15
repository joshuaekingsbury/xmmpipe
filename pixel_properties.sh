

####
##  Make sure to use detector image; mask image?
####

# Get count of non-zero pixels
getpix -g 0 pnS003-obj-im-det-300-7000-back.fits 0 0 | wc -l

# Get count of 0-valued pixels
getpix -l 1 pnS003-obj-im-det-300-7000-back.fits 0 0 | wc -l

# Get total pixel count of image
getpix -g -1 pnS003-obj-im-det-300-7000-back.fits 0 0 | wc -l

# Get count of allowed mask pixels
getpix -g 0 pnS003-mask-im-det-300-7000-back.fits 0 0 | wc -l

# Count of allowed mask pixels - count of non-zero = allowed pixel with zero value

# Get image dimensions in pixels
gethead NAXIS1 pnS003-obj-im-det-300-7000-back.fits
gethead NAXIS2 pnS003-obj-im-det-300-7000-back.fits
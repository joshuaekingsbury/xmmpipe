# xmmpipe

Scripts for working through XMM-Newton observation processing pipelines

## Usage
- EPIC detector (PN/MOS1/MOS2) exposures in IMAGING mode
## Setup
### Pre-Requisites
- Add the folder of these scripts to PATH and restart shell if necessary.
- HEAsoft v6.30.1
- SAS v21.0.0
- WCStools v3.9.6
	- used by many of these scripts to read/update FITS headers
- bc v4.0.2
	- used for calculations in conversion of region files between
		- sky->det coords
		- sky->physical coords
- SAOImage ds9 v8.3
#### Observation Files and Working Directory
Observation files are expected to all be extracted inside the odf folder: ../<obs_id>/odf
To begin, the current working directory should be titled "analysis" and located alongside odf folder: ../<obs_id>/analysis

### Script Adjustments
- \<Any hardcoded changes that should be made prior to running?>
### Before Running Scripts
1. Scripts may not behave properly if not in Bash shell
	- ```$ echo $0```
	- ```$ bash```
2. Not necessary for general use of these scripts; if python version/env used for HEAsoft is from (Ana)Conda, and expecting to use PyXspec:
	- activate (Ana)Conda before initializing HEAsoft.
3. Initialize HEAsoft
4. Initialize SAS

## Begin Pipeline Processing

### SAS Path
From inside analysis folder; always run as first pipeline script of session especially if moving around observation folder containing *odf* & *analysis* directories. 

Exports SAS_CCF and SAS_ODF, updates cif file, and replaces ODF summary file
```
$ . sas_path.sh
```

### Initial reduction
Prompt options for choosing detector(s) and CCDs (MOS only)
- Currently, all exposures for any/all detectors selected during prompting are processed
- logs are recorded of each process and stored in ```../analysis/logs```
- diagnostic images, properties of exposures and some pipeline warnings, and \<espfilt\> images, fits, and histograms are collected in ```../analysis/diagnostics```
- <emchain/epchain\> FIT output files and \<espfilt\> products are saved in ```../analysis/intermediates```
- sky and detector images at multiple stages of processing are stored in ```../analysis/images```
```
$ . esas_initial_reduction.sh
```
### Manual Soft Proton Flare (SPF) Filtering
In the case where \<espfilt\> does not work, the interactive script below will use a combination of prompts and ```fv``` tool for manual filtering.

Resulting filtered file will be placed in ```../analysis/rates``` directory

```
$ . sas_manual_flare.sh
```
* *manually copy resulting\* _filtered.fits into the analysis directory for use in subsequent steps in place of \*_allevc.fits files*

### Vignetting Correction
When prompted, enter either the appropriate file name suffix to identify files for correction prior to extracting spectra
- "filtered" (if manual)
- "allevc" (if \<espfilt\>)
- "allevc-cut" (if energy cuts made and \<espfilt\>)

Prior to this step, if Soft Proton Filtering was carried out manually:
*manually copy \*_filtered.fits into the analysis directory and **when prompted** use \* _filtered.fits file in analysis directory instead of \*_allevc.fits

```
. sas_evigweight.sh
```

### Region Conversion
Need to convert regions from ds9 to xmm-pipeline compatible

Uses text file ```../analysis/reg_files.txt``` with each line a single ds9 sky region file name string without file extension

Outputs:
- Boolean logic string in .txt file
- ds9 formatted region file

May fail if ds9 is already open prior to run; closing ds9 has always solved the issue on repeat execution (so far)

#### SAS; Sky -> Physical
```
. adapt_sky_region_files_to_phys.sh
```
#### ESAS; Sky -> Detector
```
. adapt_sky_region_files_to_det.sh
```

### Extract Spectra
Uses text file ```../analysis/reg_files.txt``` with each line a single ds9 sky region file name string without file extension
```
. sas_extract_spectra.sh
```
### Troubleshooting
#### SAOImage ds9
- Need to be able to call \<ds9\> from command line and pass arguments, ie:
```
$ ds9
```
- On OSX, I add the following command to my .bash_profile or equivalent
```
ds9(){
	
	open -n -W -a /Applications/SAOImageDS9.app/Contents/MacOS/ds9 --args "${@}"

}
```
#### Initial Reduction Aborts
##### Unexpected Missing Data While Reducing
- With 2 observations I ran into issues with processing
	- With one, I had downloaded a single observation which failed to extract in finder but extracted with ```tar xvzf```. epchain and emchain failed unable to find data. Downloaded file was 14.7 MB of 44.7 MB expected (size specified in archival request email) [0112290801]
		- Re-adding to basket, selecting "Retrieve data in TAR.GZ format" (instead of default TAR), and redownloading from new archive link on a different network downloaded properly and allowed for reduction
	- With the other troublesome observation, it was downloaded as part of a group of other observations. No other observations from the same TAR file had issues in processing. Observation failed epchain and emchain again after re-downloading from new archive request. As observation was short and much other data existed, troubleshooting this observation further was reserved for a future time. [0112280101]

## Potential Future Work
### Scripts for Source Detection
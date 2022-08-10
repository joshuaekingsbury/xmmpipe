#!/bin/bash

# Make sure to *source* and not just run script
# $. sassyPath.sh
# NOT
# $sassyPath.sh

_CURRENT_DIR=${PWD##*/}

if [[ !$_CURRENT_DIR == "analysis" ]]; then
    echo
    echo "Current directory is not 'analysis'. Try again. ;)"
    echo
fi

SAS_VERBOSITY=5

sasversion >& mysassetup.log
uname -a >> mysassetup.log
env >> mysassetup.log

## The commands below are actually mostly using default values; the simpler versions should be executing the same.
cifbuild withccfpath=no analysisdate=now category=XMMCCF calindexset=$SAS_CCF fullpath=yes >& cifbuild.log
#cifbuild fullpath=yes >& cifbuild.log

odfingest odfdir=$SAS_ODF outdir=$SAS_ODF >& odfingest.log
#odfingest outdir=$SAS_ODF

epchain withoutoftime=true >& epchainoot.log

epchain >& epchain.log

pn-filter >& pn-filter.log

pn-spectra prefix=S001 caldb=$ESAS_CALDB region="pnS001_n1.txt" mask=0 elow=300 ehigh=7000 quad1=1 quad2=1 quad3=1 quad4=1 >& pn-spectra.log

#!/bin/sh
#
# Finnish Meteorological Institute / Mikko Rauhala (2015-2017)
#
# SmartMet Data Ingestion Module for HIRLAM Model
#

# Load Configuration 
if [ -s /smartmet/cnf/data/hirlam.cnf ]; then
    . /smartmet/cnf/data/hirlam.cnf
fi

if [ -s hirlam.cnf ]; then
    . hirlam.cnf
fi

# Setup defaults for the configuration

if [ -z "$AREA" ]; then
    AREA=europe
fi

if [ -z "$PROJECTION" ]; then
    PROJECTION="stereographic,15,90,60:-5,40,65,70:319,351"
fi

while getopts  "a:dp:" flag
do
  case "$flag" in
        a) AREA=$OPTARG;;
        d) DRYRUN=1;;
        p) PROJECTION=$OPTARG;;
  esac
done

STEP=6
# Model Reference Time
RT=`date -u +%s -d '-2 hours'`
RT="$(( $RT / ($STEP * 3600) * ($STEP * 3600) ))"
RT_HOUR=`date -u -d@$RT +%H`
RT_DATE_MMDD=`date -u -d@$RT +%Y%m%d`
RT_DATE_MMDDHH=`date -u -d@$RT +%m%d%H`
RT_DATE_HH=`date -u -d@$RT +%Y%m%d%H`
RT_DATE_HHMM=`date -u -d@$RT +%Y%m%d%H%M`
RT_ISO=`date -u -d@$RT +%Y-%m-%dT%H:%M:%SZ`

if [ -d /smartmet ]; then
    BASE=/smartmet
else
    BASE=$HOME/smartmet
fi

IN=$BASE/data/incoming/hirlam
OUT=$BASE/data/hirlam/$AREA
CNF=$BASE/run/data/hirlam/cnf
EDITOR=$BASE/editor/in
TMP=$BASE/tmp/data/hirlam_${AREA}_${RT_DATE_HHMM}
LOGFILE=$BASE/logs/data/hirlam_${AREA}_${RT_HOUR}.log

OUTNAME=${RT_DATE_HHMM}_hirlam_$AREA

OUTFILE_SFC=$OUT/surface/querydata/${OUTNAME}_surface.sqd
OUTFILE_PL=$OUT/pressure/querydata/${OUTNAME}_pressure.sqd
OUTFILE_ML=$OUT/hybrid/querydata/${OUTNAME}_hybrid.sqd

# Use log file if not run interactively
if [ $TERM = "dumb" ]; then
    exec &> $LOGFILE
fi

echo "Model Reference Time: $RT_ISO"
echo "Projection: $PROJECTION"
echo "Temporary directory: $TMP"
echo "Input directory: $IN"
echo "Output directory: $OUT"
echo "Output surface level file: ${OUTNAME}_surface.sqd"
echo "Output pressure level file: ${OUTNAME}_pressure.sqd"
echo "Output hybrid level file: ${OUTNAME}_hybrid.sqd"


if [ -z "$DRYRUN" ]; then
    mkdir -p $OUT/{surface,pressure,hybrid}/querydata
    mkdir -p $EDITOR 
    mkdir -p $TMP
fi

if [ -n "$DRYRUN" ]; then
    exit
fi

function log {
    echo "$(date -u +%H:%M:%S) $1"
}

#
# Surface Data
#
if [ ! -s $OUTFILE_SFC ]; then
    # Convert
    log "Converting surface grib files to qd files.."
    gribtoqd -d -t -L 1 -c $CNF/hirlam-sfc.conf \
	-p "230,HIRLAM Surface" -P $PROJECTION \
	-o $TMP/$(basename $OUTFILE_SFC) \
	$IN/fc${RT_DATE_MMDD}_${RT_HOUR}*md

    # Post Process
    if [ -s $TMP/$(basename $OUTFILE_SFC) ]; then
	log "Post processing: $(basename $OUTFILE_SFC)"
	mv -f  $TMP/$(basename $OUTFILE_SFC) $TMP/$(basename $OUTFILE_SFC).tmp
    fi

    if [ -s $TMP/$(basename $OUTFILE_SFC).tmp ]; then
	log "Creating Wind and Weather objects: $(basename $OUTFILE_SFC)"
	qdversionchange -a 7 < $TMP/$(basename $OUTFILE_SFC).tmp > $TMP/$(basename $OUTFILE_SFC)
    fi

    # Distribute
    if [ -s $TMP/$(basename $OUTFILE_SFC) ]; then
	log "Testing: $(basename $OUTFILE_SFC)"
	if qdstat $TMP/$(basename $OUTFILE_SFC); then
	    log "Compressing: $(basename $OUTFILE_SFC)"
	    lbzip2 -k $TMP/$(basename $OUTFILE_SFC)
	    log "Moving: $(basename $OUTFILE_SFC) to $OUT/surface/querydata/"
	    mv -f $TMP/$(basename $OUTFILE_SFC) $OUT/surface/querydata/
	    log "Moving $(basename $OUTFILE_SFC).bz2 to $EDITOR"
	    mv -f $TMP/$(basename $OUTFILE_SFC).bz2 $EDITOR/
	else
	    log "File $TMP/$(basename $OUTFILE_SFC) is not valid qd file."
	fi
    fi
fi # surface

#
# Pressure Levels
#
if [ ! -s $OUTFILE_PL ]; then
    # Convert
    log "Converting pressure grib files to $(basename $OUTFILE_PL)"
    gribtoqd -d -t -L 100 -c $CNF/hirlam-pl.conf \
	-p "230,HIRLAM Pressure" -P $PROJECTION \
	-o $TMP/$(basename $OUTFILE_PL) \
	$IN/fc${RT_DATE_MMDD}_${RT_HOUR}*ve

    # Post Process
    if [ -s $TMP/$(basename $OUTFILE_PL) ]; then
	log "Post processing: $(basename $OUTFILE_PL)"
	mv -f $TMP/$(basename $OUTFILE_PL) $TMP/$(basename $OUTFILE_PL).tmp
    fi

    if [ -s $TMP/$(basename $OUTFILE_PL).tmp ]; then
	log "Creating Wind and Weather objects: $(basename $OUTFILE_PL)"
	qdversionchange -w 0 7 < $TMP/$(basename $OUTFILE_PL).tmp > $TMP/$(basename $OUTFILE_PL)
    fi

    # Distribute
    if [ -s $TMP/$(basename $OUTFILE_PL) ]; then
	log "Testing: $(basename $OUTFILE_PL)"
	if qdstat $TMP/$(basename $OUTFILE_PL); then
	    log  "Compressing: $(basename $OUTFILE_PL)"
	    lbzip2 -k $TMP/$(basename $OUTFILE_PL)
	    log "Moving: $(basename $OUTFILE_PL) to $OUT/pressure/querydata/"
	    mv -f $TMP/$(basename $OUTFILE_PL) $OUT/pressure/querydata/
	    log "Moving: $(basename $OUTFILE_PL).bz2 to $EDITOR/"
	    mv -f $TMP/$(basename $OUTFILE_PL).bz2 $EDITOR/
	else
	    log "File $TMP/$(basename $OUTFILE_PL) is not valid qd file."
	fi
    fi
fi # pressure

#
# Hybrid Levels
# 
if [ ! -s $OUTFILE_ML ]; then
    # Convert
    log "Converting hybrid grib files to $(basename $OUTFILE_ML)"
    gribtoqd -d -t -L 109 -c $CNF/hirlam-ml.conf \
	-p "230,HIRLAM Hybrid" -P $PROJECTION \
	-o $TMP/$(basename $OUTFILE_ML) \
	$IN/fc${RT_DATE_MMDD}_${RT_HOUR}+???

    # Post Process
    if [ -s $TMP/$(basename $OUTFILE_ML) ]; then
	log "Post processing: $(basename $OUTFILE_ML)"
	mv -f  $TMP/$(basename $OUTFILE_ML) $TMP/$(basename $OUTFILE_ML).tmp
    fi

    if [ -s $TMP/$(basename $OUTFILE_ML).tmp ]; then
	log "Creating Wind and Weather objects: $(basename $OUTFILE_ML)"
	qdversionchange -w 0 7 < $TMP/$(basename $OUTFILE_ML).tmp > $TMP/$(basename $OUTFILE_ML)
    fi

    # Distribute
    if [ -s $TMP/$(basename $OUTFILE_ML) ]; then
	log "Testing: $(basename $OUTFILE_ML)"
	if qdstat $TMP/$(basename $OUTFILE_ML); then
	    log "Compressing: $(basename $OUTFILE_ML)"
	    lbzip2 -k $TMP/$(basename $OUTFILE_ML)
	    log "Moving: $(basename $OUTFILE_ML) to $OUT/hybrid/querydata/"
	    mv -f $TMP/$(basename $OUTFILE_ML) $OUT/hybrid/querydata/
	    log "Moving: $(basename $OUTFILE_ML).bz2 to $EDITOR"
	    mv -f $TMP/$(basename $OUTFILE_ML).bz2 $EDITOR/
	else
	    log "File $TMP/$(basename $OUTFILE_ML) is not valid qd file."
	fi
    fi # distribute
fi # hybrid

log "Cleaning temporary directory $TMP"
rm -f $TMP/*_hirlam_*
rmdir $TMP

#
# Post process some parameters 
#
#qdscript $CNF/hirlam.st < $TMP/${OUTNAME}_surface.sqd > $TMP/${OUTNAME}_surface.sqd.tmp

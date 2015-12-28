#!/bin/bash
#
#
# This script will create a bundle file given an existing kit.
#
# See usage for parameters that must be passed to this script.
#
# We expect this script to run from the BUILD directory (i.e. scxcore/build).
# Directory paths are hard-coded for this location.

# Notes for file bundle_skel.sh (included here since we don't want to ship
# these comments in shell bundle):
#
# The bundle_skel.sh file is a shell bundle for all platforms (Redhat, SUSE,
# AIX, HP, and Solaris), as well as universal Linux platforms.
#
# Use this script by concatenating it with some binary package.
#
# The bundle is created by cat'ing the script in front of the binary, so for
# the gzip'ed tar example, a command like the following will build the bundle:
#
#     tar -czvf - <target-dir> | cat sfx.skel - > my.bundle
#
# The bundle can then be copied to a system, made executable (chmod +x) and
# then run.
#
# This script has some useful helper options to split out the script and/or
# binary in place, and to turn on shell debugging.
#
# This script is paired with create_bundle.sh, which will edit constants in
# this script for proper execution at runtime.  The "magic", here, is that
# create_bundle.sh encodes the length of this script in the script itself.
# Then the script can use that with 'tail' in order to strip the script from
# the binary package.
#
# Developer note: A prior incarnation of this script used 'sed' to strip the
# script from the binary package.  That didn't work on AIX 5, where 'sed' did
# strip the binary package - AND null bytes, creating a corrupted stream.


SOURCE_DIR=`(cd ../installer/bundle; pwd -P)`
INTERMEDIATE_DIR=`(cd ../installer/intermediate; pwd -P)`

# Exit on error
set -e

# Don't display output
set +x

usage()
{
    echo "usage: $0 platform directory tar-file scx-package-name omi-package-name <provider-only>"
    echo "  where"
    echo "    platform is one of: linux, aix, hpux, sun"
    echo "    directory is directory path to package file"
    echo "    tar-file is the name of the tar file that contains the following packages"
    echo "    scx-package-name is the name of the scx installation package"
    echo "    omi-package-name is the name of the omi installation package"
    echo "    provider-only is 1 (scx-cimprov style kit) or 0 (scx combined kit)"
    echo "  If omi-package-name is empty, then we assume universal SSL directories for OMI"
    exit 1
}

# Validate parameters

PLATFORM_TYPE="$1"
if [ -z "$PLATFORM_TYPE" ]; then
    echo "Missing parameter: Platform type" >&2
    echo ""
    usage
    exit 1
fi

case "$PLATFORM_TYPE" in
    Linux|AIX|HPUX|SunOS)
	;;

    *)
	echo "Invalid platform type specified: $PLATFORM_TYPE" >&2
	exit 1
esac

if [ -z "$2" ]; then
    echo "Missing parameter: Directory to platform file" >&2
    echo ""
    usage
    exit 1
fi

if [ ! -d "$2" ]; then
    echo "Directory \"$2\" does not exist" >&2
    exit 1
fi

if [ -z "$3" ]; then
    echo "Missing parameter: tar-file" >&2
    echo ""
    usage
    exit 1
fi

if [ -z "$4" ]; then
    echo "Missing parameter: scx-package-name" >&2
    echo ""
    usage
    exit 1
fi

if [ -z "$6" ]; then
    echo "Missing parameter: provider-only" >&2
    echo ""
    usage
    exit 1
fi

SCX_PACKAGE=`echo $4 | sed -e 's/.rpm$//' -e 's/.deb$//'`
OMI_PACKAGE=`echo $5 | sed -e 's/.rpm$//' -e 's/.deb$//'`
PROVIDER_ONLY=$6

if [ ! -f "$2/$3" ]; then
    echo "Tar file \"$2/$3\" does not exist"
    exit 1
fi

# Determine the output file name
OUTPUT_DIR=`(cd $2; pwd -P)`

# Work from the temporary directory from this point forward

cd $INTERMEDIATE_DIR

# Fetch the bundle skeleton file
cp $SOURCE_DIR/bundle_skel.sh .
chmod u+w bundle_skel.sh

# Edit the bundle file for hard-coded values
sed -i "s/PLATFORM=<PLATFORM_TYPE>/PLATFORM=$PLATFORM_TYPE/" bundle_skel.sh
sed -i "s/TAR_FILE=<TAR_FILE>/TAR_FILE=$3/" bundle_skel.sh
sed -i "s/OM_PKG=<OM_PKG>/OM_PKG=$SCX_PACKAGE/" bundle_skel.sh
sed -i "s/OMI_PKG=<OMI_PKG>/OMI_PKG=$OMI_PACKAGE/" bundle_skel.sh

sed -i "s/PROVIDER_ONLY=0/PROVIDER_ONLY=$PROVIDER_ONLY/" bundle_skel.sh


SCRIPT_LEN=`wc -l < bundle_skel.sh | sed -e 's/ //g'`
SCRIPT_LEN_PLUS_ONE="$((SCRIPT_LEN + 1))"

sed -i "s/SCRIPT_LEN=<SCRIPT_LEN>/SCRIPT_LEN=${SCRIPT_LEN}/" bundle_skel.sh
sed -i "s/SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>/SCRIPT_LEN_PLUS_ONE=${SCRIPT_LEN_PLUS_ONE}/" bundle_skel.sh


# Fetch the kit
cp $OUTPUT_DIR/$3 .

# Build the bundle
case "$PLATFORM_TYPE" in
    Linux)
	BUNDLE_FILE=`echo $3 | sed -e "s/.rpm//" -e "s/.deb//" -e "s/.tar//"`.sh
	gzip -c $3 | cat bundle_skel.sh - > $BUNDLE_FILE
	;;

    NEVERNEVERLAND_Linux_ULINUX)
        BUNDLE_FILE=${SCX_PACKAGE}.sh
        gzip -c $3 | cat bundle_skel.sh - > $BUNDLE_FILE
        ;;

    AIX)
	BUNDLE_FILE=`echo $3 | sed -e "s/.lpp//" -e "s/.tar//"`.sh
	gzip -c $3 | cat bundle_skel.sh - > $BUNDLE_FILE
	;;

    HPUX)
	BUNDLE_FILE=`echo $3 | sed -e "s/.depot//" -e "s/.tar//"`.sh
	compress -c $3 | cat bundle_skel.sh - > $BUNDLE_FILE
	;;

    SunOS)
	BUNDLE_FILE=`echo $3 | sed -e "s/.pkg//" -e "s/.tar//"`.sh
	compress -c $3 | cat bundle_skel.sh - > $BUNDLE_FILE
	;;

    *)
	echo "Invalid platform encoded in variable \$PACKAGE; aborting" >&2
	exit 2
esac

chmod +x $BUNDLE_FILE
rm bundle_skel.sh

# Remove the kit and copy the bundle to the kit location
rm $3
mv $BUNDLE_FILE $OUTPUT_DIR/

exit 0

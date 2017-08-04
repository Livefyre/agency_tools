#!/bin/bash
#
# upload_to_s3.sh: A program to upload content to S3.

#
# $rc usage()
#

function usage {
    # Print the usage information, for this program.

    echo "Usage:
    upload_to_s3.sh -h
    upload_to_s3.sh -b <bucket> -s <source> [-p <prefix>] [-m <age>] [-e <encoding>] [-c <config>] [-r <regex>] [-n <regex>]

    -h: display this help
    -b: bucket (S3 destination)
    -s: source (Where to copy from)
    -p: prefix (String to prepend to s3 path)
    -m: age (How long assets live in the cache)
    -i: invalidation (Where to put an invalidation list file)
    -e: header encoding (i.e. pass gzip if you want it)
    -c: s3cmd configuration
    -r: regex exclude
    -n: regex include"

    return 0

}

#
# $rc set_options( <arg> [ <arg> ... ] )
#

function set_options {
    # Set global vars from commandline options and validation options given

    export MAX_AGE="300"
    export ENCODING=""
    export PREFIX=""
    export CONFIG_FILE=~/.s3cfg
    while getopts ":hs:p:b:m:e:i:c:r:n:" opt
    do
        case $opt in
        h)
            usage
            exit 0
            ;;
        b)
            export DST_BUCKET="$OPTARG"
            ;;
        s)
            export SRC_DIR="$OPTARG"
            ;;
        p)
            export PREFIX="$OPTARG"
            ;;
        m)
            export MAX_AGE="$OPTARG"
            ;;
        e)
            export ENCODING="$OPTARG"
            ;;
        i)
            export INVALIDATION_FILE="$PWD/$OPTARG"
            ;;
        c)
            export CONFIG_FILE="$OPTARG"
            ;;
        r)
            export REXCLUDE_PATTERN="--rexclude $OPTARG"
            ;;
        n)
            export RINCLUDE_PATTERN="--rinclude $OPTARG"
            ;;
        \?)
            echo "$0: error - unrecognized option $1"
            usage
            return 1
            ;;
        :)
            echo "$0: error - option -$OPTARG requires an argument."
            usage
            return 1
            ;;
        esac
    done

   if [ $# -eq 0 ]
       then
       echo "One or more arguments must be specified."
       usage
       return 1
   fi

   if [ -z $DST_BUCKET ]
       then
       echo "Option -b is required."
       usage
       return 1
   fi

   if [ -z $SRC_DIR ]
   then
     echo "Option -s is required."
     usage
     return 1
   fi

   return 0

}

set_options $*

# Without the options set, it won't be possible to upload content.
# Error messages are printed by set_options function
[ "$?" -ne 0 ] && exit 1

BUCKET_URL="s3://$DST_BUCKET/"

#
# Assets are present
#

# Asset path must exist to upload resources
if [ ! -d $SRC_DIR ]
then
    echo "Could not find assets to upload in '$SRC_DIR'"
    exit 1
fi


#
# Check that the correct config is loaded
#
if [[ $(s3cmd info --config $CONFIG_FILE $BUCKET_URL 2>&1 > /dev/null) =~ ^ERROR ]]
then
    echo "Error running s3cmd, do you have the correct config installed?"
    exit 1
fi

TEMPDIR=$(mktemp -dt jsdeploy.XXXXX)
mkdir -p "$TEMPDIR/$PREFIX"
cp -R "$SRC_DIR"/* "$TEMPDIR/$PREFIX"
if [ -n $INVALIDATION_FILE ]
then
    echo "Saving invalidation file to $INVALIDATION_FILE"

    pushd $TEMPDIR
    find * -type f > $INVALIDATION_FILE
    popd
fi

MAXAGE_HEADER="Cache-Control:max-age=$MAX_AGE"

if [ -z "$ENCODING" ]
then
    ENCODING_HEADER=""
else
    ENCODING_HEADER="--add-header Content-Encoding:$ENCODING "

    if [ "$ENCODING" == "gzip" ]
    then
        find $TEMPDIR -type f -print0 | xargs -0 gzip
        find $TEMPDIR -type f -name '*.gz' | while read f; do mv "$f" "${f%.gz}"; done
    fi
fi

s3cmd sync --config "$CONFIG_FILE" ${REXCLUDE_PATTERN} ${RINCLUDE_PATTERN} -f -M --no-mime-magic --acl-public --add-header $MAXAGE_HEADER $ENCODING_HEADER "$TEMPDIR/" "$BUCKET_URL"
rm -rf $TEMPDIR

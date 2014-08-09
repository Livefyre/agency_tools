#!/bin/bash

set -e

all_same=0

for url in $*
  do output=$(curl --compressed -s $url | tail -1 | perl -pe "s/fyre.conv.config.set\('assetVersion', (\d+)\);/\$1/")
  echo "$output $url"
  if [[ -n "$last" ]]
  then
    if [[ "$output" != "$last" ]]
    then all_same=1
    fi
  fi
  last=$output
done

if [[ "$all_same" -ne 0 ]]
then
  echo "FAILURE: Version Mismatch!"
  exit $all_same
else
  echo "Success: All Versions Match"
  exit 0
fi

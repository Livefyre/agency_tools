#!/bin/bash

set -e

all_same=0

for url in $*
  do output=$(curl -s --compressed $url | tail -5 | perl -ne "/fyre.conv.config.set\('assetVersion', (\d+)\);/ && print \"\$1\n\"")
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

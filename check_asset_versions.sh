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

exit $all_same

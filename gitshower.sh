#!/bin/bash

for dir in $(ls -d -1 python3-*); do
    pushd $dir > /dev/null
    echo "Lets see $dir"
    read line
    git show
    popd > /dev/null
done

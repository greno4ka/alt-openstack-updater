#!/bin/bash

for dir in $(ls -d python3-module-*); do
pushd $dir
gear --commit -v --hasher -- hsh -v ~/hasher 2>&1 | tee log
popd > /dev/null
done

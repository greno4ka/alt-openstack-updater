#!/bin/bash

for dir in $(ls -d python3-module-*); do
pushd $dir
gear --commit -v --hasher -- hsh --build-args "--with docs --with check" -v ~/hasher 2>&1 | tee log0
gear --commit -v --hasher -- hsh --build-args "--with docs --without check" -v ~/hasher 2>&1 | tee log1
gear --commit -v --hasher -- hsh --build-args "--without docs --with check" -v ~/hasher 2>&1 | tee log2
gear --commit -v --hasher -- hsh --build-args "--without docs --without check" -v ~/hasher 2>&1 | tee log3
popd > /dev/null
done

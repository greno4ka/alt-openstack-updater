#!/bin/bash

ssh gyle task new < /dev/null

for dir in $(ls -d python3-module-*); do
pushd $dir
srpmName=$(gear-rpm -bs --nodeps | cut -d":" -f2 | cut -d" " -f2 )
rpm --addsign $srpmName
rsync -aP $srpmName gyle:
ssh gyle task add srpm $(basename $srpmName) < /dev/null
popd > /dev/null
done

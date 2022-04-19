#!/bin/bash -u

source versionDiagnostics.sh
source updatePackage.sh

release=$1

rsync -aP basalt-home:/space/ALT/Sisyphus/files/list/src.list .

touch scrapped.list
#for section in "library-projects" "service-projects" "service-client-projects"; do
for section in "library-projects"; do
    ./scrap.py $release $section >> scrapped.list
done

for theirModuleName in $(cat scrapped.list | cut -d" " -f1); do
    # TODO: rename these packages!
    # oslo crutch
    fixedModuleName=$(sed "s/oslo-/oslo\./" <<< $theirModuleName)
    #Sisyphus names' templates
    python3moduleName=$(sed "s/^\(python3\?-\)\?/python3-module-/" <<< $fixedModuleName)
    openstackName=$(sed "s/^/openstack-/" <<< $fixedModuleName)


    sisyphusName=$(grep "$python3moduleName" src.list | cut -f1) ||
    sisyphusName=$(grep "$openstackName" src.list | cut -f1) ||
    sisyphusName=""
    if [ -z "$sisyphusName" ]; then
        echo "$sisyphusName is not found in repo!"
        continue
    fi

    sisyphusVersion=$(grep "$sisyphusName[[:space:]]" src.list \
            | cut -f2 | cut -d"-" -f1 | cut -d":" -f2 )
    upstreamVersion=$(grep "^$theirModuleName[[:space:]]" scrapped.list | cut -d" " -f3)
    versionDiagnostics "$sisyphusVersion" "$upstreamVersion" "$theirModuleName"
        if [ $? == 2 ]; then
            updatePackage "$theirModuleName" "$sisyphusName"
        fi
done

rm -f scrapped.list

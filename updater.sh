#!/bin/bash -u

source versionDiagnostics.sh
source updatePackage.sh

release=$1

rsync -aP basalt-home:/space/ALT/Sisyphus/files/list/src.list .

touch scrapped.list
for section in "library-projects" "service-projects" "service-client-projects"; do
    ./scrap.py $release $section >> scrapped.list
done

for originalModuleName in $(cat scrapped.list | cut -d" " -f1); do
    # oslo crutch
    fixedModuleName=$(sed "s/oslo-/oslo\./" <<< $originalModuleName)
    #Sisyphus names' templates
    policyName3=$(sed "s/^\(python3\?-\)\?/python3-module-/" <<< $fixedModuleName)
    openstackName=$(sed "s/^/openstack-/" <<< $fixedModuleName)
    sisyphusNames="$policyName3 $openstackName"

    sisyphusVersion=""
    for possibleName in $sisyphusNames; do
        if [ -z $sisyphusVersion ]; then
            sisyphusVersion=$(grep "$possibleName[[:space:]]" src.list \
            | cut -f2 | cut -d"-" -f1 | cut -d":" -f2 )
        fi
    done

    upstreamVersion=$(grep "^$originalModuleName[[:space:]]" scrapped.list | cut -d" " -f3)
    if [ -n "$sisyphusVersion" ]; then
        versionDiagnostics "$sisyphusVersion" "$upstreamVersion" "$originalModuleName"
        if [ $? == 2 ]; then
            updatePackage "$originalModuleName" "$sisyphusNames"
        fi
    fi
done

rm -f scrapped.list

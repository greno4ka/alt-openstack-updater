#!/bin/bash -u

source versionDiagnostics.sh
source updatePackage.sh

originalModuleName="$1"

#Sisyphus names' templates
policyName=$(sed "s/^\(python3\?-\)\?/python-module-/" <<< $originalModuleName)
policyName3=$(sed "s/^\(python3\?-\)\?/python3-module-/" <<< $originalModuleName)
openstackName=$(sed "s/^/openstack-/" <<< $originalModuleName)
sisyphusNames="$policyName $policyName3 $openstackName"

# rsync -aP basalt-home:/space/ALT/Sisyphus/files/list/src.list .

sisyphusVersion=""
for possibleName in $sisyphusNames; do
if [ -z $sisyphusVersion ]; then
    sisyphusVersion=$(grep "$possibleName[[:space:]]" src.list \
    | cut -f2 | cut -d"-" -f1 | cut -d":" -f2 )
fi
done

upstreamVersion=$(grep "^$originalModuleName[[:space:]]" lol | cut -d" " -f3)

if [ -n "$sisyphusVersion" ]; then
    versionDiagnostics "$sisyphusVersion" "$upstreamVersion" "$originalModuleName"

    if [ $? == 2 ]; then
        updatePackage "$originalModuleName" "$sisyphusNames"
    fi
fi

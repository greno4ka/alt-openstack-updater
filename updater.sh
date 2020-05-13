#!/bin/bash -u

source version_diagnostics.sh

# 1. Clone git repo
# 2. ? Rename spec file
# 3. ? Creating watch file
# 4. Download tarball
# 5. Generate changelog
# 6. Make upgrade
# 7. Update build requires
# 8. ???
# 9. PROFIT!!!

moduleName="$1"

#Sisyphus names' templates
policyName=$(sed "s/^\(python3\?-\)\?/python-module-/" <<< $moduleName)
policyName3=$(sed "s/^\(python3\?-\)\?/python3-module-/" <<< $moduleName)
openstackName=$(sed "s/^/openstack-/" <<< $moduleName)
sisyphusNames="$policyName $policyName3 $openstackName"

# rsync -aP basalt-home:/space/ALT/Sisyphus/files/list/src.list .

sisyphusVersion=""
for possibleName in $sisyphusNames; do
if [ -z $sisyphusVersion ]; then
    sisyphusVersion=$(grep "$possibleName[[:space:]]" src.list \
    | cut -f2 | cut -d"-" -f1 | cut -d":" -f2 )
fi
done

upstreamVersion=$(grep "^$moduleName[[:space:]]" lil | cut -d" " -f3)

if [ -n "$sisyphusVersion" ]; then
    versionDiagnostics "$sisyphusVersion" "$upstreamVersion" "$moduleName"
fi

exit 0

# 8<----------------------------------------------------------------------------

echo "*** Cloning git repo ***"
for possibleName in $possibleNames; do
    if [ -d "$possibleName" ]; then
        echo "$possibleName exists. Skip clonning."
        moduleDir=$(pwd)/"$possibleName"
        break
    fi
    girar-get-upload-method "$possibleName" --no-output || packageExists="$?"
    if [ "$packageExists" -lt 4 ]; then
        echo "Cloning $possibleName"
        moduleDir=$(pwd)/"$possibleName"
        if [ "$packageExists" = "3" ]; then
            git clone --quiet git:/srpms/"${possibleName:0:1}"/"$possibleName"
        else
            git clone --quiet git:/gears/"${possibleName:0:1}"/"$possibleName"
        fi
    fi
done

# 8<----------------------------------------------------------------------------

pushd "$moduleDir" > /dev/null
moduleName=$(echo "$moduleDir" | rev | cut -f1 -d"/" | rev | sed -e "s/python3\?-module-\|openstack-//")
cuttedModuleName=$(sed "s/^os[-_]//" <<< $moduleName)

# Renaming of spec file before update if nessesary
specRenamed=0
specFileLocation=$(find $moduleDir -name "*.spec")
correctSpecLocation="$(dirname $specFileLocation)/$moduleName.spec"
if [ ! $specFileLocation == $correctSpecLocation ]; then
    echo "*** Renaming spec file ***"
    git mv $specFileLocation $correctSpecLocation
    git commit -am "Renamed spec file"
    specRenamed=1
fi

# 8<----------------------------------------------------------------------------

watchFileGenerated=0
if [ ! -f ".gear/$moduleName.watch" ]; then
    echo "*** Creating watch file ***"
    cat <<EOF > ".gear/$moduleName.watch"
version=3
http://tarballs.openstack.org/(.*)$moduleName/(.*)$moduleName-([\d.]+)\.tar\.gz
EOF
sed -i -E "s/(Source:.*)/\1\nSource1: $moduleName.watch/g" "$correctSpecLocation"
echo "copy: .gear/$moduleName.watch" >> ".gear/rules"
watchFileGenerated=1
git add ".gear/$moduleName.watch"
git commit -am "Added watch file"
fi

# 8<----------------------------------------------------------------------------

echo "*** Downloading source tarball ***"
wget --quiet --show-progress $(grep "http" <<< $(rpm-uscan --no-verbose --skip-signature --report))

# 8<----------------------------------------------------------------------------

echo "*** Generating changelog ***"

changelogEntry="- Automatically updated to $version."
if [ $watchFileGenerated == 1 ]; then
    changelogEntry=$changelogEntry"\n- Added watch file."
fi
if [ $specRenamed == 1 ]; then
    changelogEntry=$changelogEntry"\n- Renamed spec file."
fi
changelogEntry=$(echo -e $changelogEntry)

# 8<----------------------------------------------------------------------------

echo "*** Updating repo ***"
tarball=$(find . -name "*.tar.gz")
version="$(sed -e "s/.*-\(.*\)\.tar\.gz/\1/" <<< "$tarball")"
gear-uupdate -q "$tarball" "$version" --changelog "$changelogEntry"

# 8<----------------------------------------------------------------------------

echo "*** Updating build requires ***"
# split BR each on own line
sed -i -E '/^BuildRequires:/s/(BuildRequires:[[:space:]]*)?([^[:space:]]+([[:space:]]*>=[[:space:]]*?[0-9.]+)?)/BuildRequires: \2/g' "$correctSpecLocation"
sed -i -E 's/[[:space:]]+(BuildRequires:)/\n\1/g' "$correctSpecLocation"

# git repo of modules always contains . .gear .git and our destination
pushd "$(find -maxdepth 1 -type d | grep -v ".git" | \
        grep -v ".gear" | grep "/")" > /dev/null
cat "requirements.txt" | while read reqLine; do
    if [[ "$reqLine" =~ ">" ]]; then
        reqName=$(tr [:upper:] [:lower:] <<< \
            $(echo "$reqLine" | cut -d"!" -f1 | cut -d">" -f1))
        reqVersion=$(sed -nE "s/$reqName[^ ;]*>=?([0-9.]+).*/\1/p" <<< $reqLine)
        [ -z $reqVersion ] || sed -Ei "s/(python3?-module-$reqName)([[:space:]]|$).*/\1 >= $reqVersion/" "$correctSpecLocation"
    fi
done
popd > /dev/null

# 8<----------------------------------------------------------------------------

git commit -am "tmp"
gear-commit -a --amend --no-edit
srpmName=$(gear-rpm -bs --nodeps | cut -d":" -f2)
rpm --addsign $srpmName
rsync -aP $srpmName gyle:
git clean -fdx
popd > /dev/null

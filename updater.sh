#!/bin/bash -eu

moduleName="$1"

echo "*** Let's clone git repo ***"

policyName=$(sed "s/^\(python3\?-\)\?/python-module-/" <<< $moduleName)
policyName3=$(sed "s/^\(python3\?-\)\?/python3-module-/" <<< $moduleName)
openstackName=$(sed "s/^/openstack-/" <<< $moduleName)
possibleNames="$policyName $policyName3 $moduleName $openstackName"
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

pushd "$moduleDir" > /dev/null
moduleName=$(echo "$moduleDir" | rev | cut -f1 -d"/" | rev | sed -e "s/python3\?-module-\|openstack-//")
cuttedModuleName=$(sed "s/^os[-_]//" <<< $moduleName)

watchFileGenerated=0
if [ ! -f ".gear/$moduleName.watch" ]; then
    echo "*** Creating watch file ***"
    cat <<EOF > ".gear/$moduleName.watch"
version=3
http://tarballs.openstack.org/(.*)$moduleName/(.*)$moduleName-([\d.]+)\.tar\.gz
EOF
watchFileGenerated=1
git add ".gear/$moduleName.watch"
git commit -am "Added watch file"
fi

echo "*** Downloading source tarball ***"
wget --quiet --show-progress $(grep "http" <<< $(rpm-uscan --no-verbose --skip-signature --report))

tarball=$(find . -name "*.tar.gz")
version="$(sed -e "s/.*-\(.*\)\.tar\.gz/\1/" <<< "$tarball")"

# Preprocessing of spec file before update
specRenamed=0
specFileLocation=$(find $moduleDir -name "*.spec")
correctSpecLocation="$(dirname $specFileLocation)/$moduleName.spec"
if [ ! $specFileLocation == $correctSpecLocation ]; then
    echo "*** Renaming spec file ***"
    git mv $specFileLocation $correctSpecLocation
    git commit -am "Renamed spec file"
    specRenamed=1
fi

changelogEntry="- Automatically updated to $version."
if [ $watchFileGenerated == 1 ]; then
    changelogEntry=$changelogEntry"\n- Added watch file."
fi
if [ $specRenamed == 1 ]; then
    changelogEntry=$changelogEntry"\n- Renamed spec file."
fi

changelogEntry=$(echo -e $changelogEntry)

echo "*** Updating repo ***"
gear-uupdate -q "$tarball" "$version" --changelog "$changelogEntry"

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

git commit -am "tmp"
gear-commit -a --amend --no-edit
srpmName=$(gear-rpm -bs --nodeps | cut -d":" -f2)
rpm --addsign $srpmName
rsync -aP $srpmName gyle:
git clean -fdx
popd > /dev/null

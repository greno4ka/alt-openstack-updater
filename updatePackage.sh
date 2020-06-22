#!/bin/bash -u

# 1. Clone git repo
# 2. ? Rename spec file
# 3. Download tarball
# 4. Generate changelog
# 5. Make upgrade
# 6. Update build requires
# 7. ???
# 8. PROFIT!!!

updatePackage() {
    # $1 - originalModuleName
    # $2 - sisyphusNames
    originalModuleName=$1
    sisyphusNames=$2

echo "*** Cloning git repo ***"
for possibleName in $sisyphusNames; do
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

echo "*** Downloading source tarball ***"
wget --quiet --show-progress \
    $(grep "^$originalModuleName " ../scrapped.list | cut -d" " -f4)
tarball=$(find . -name "*.tar.gz")
version="$(sed -e "s/.*-\(.*\)\.tar\.gz/\1/" <<< "$tarball")"

# 8<----------------------------------------------------------------------------

echo "*** Generating changelog ***"

changelogEntry="- Automatically updated to $version."
if [ $specRenamed == 1 ]; then
    changelogEntry=$changelogEntry"\n- Renamed spec file."
fi
changelogEntry=$(echo -e $changelogEntry)

# 8<----------------------------------------------------------------------------

echo "*** Updating repo ***"
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

}

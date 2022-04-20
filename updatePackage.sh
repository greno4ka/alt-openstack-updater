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
    # $1 - theirModuleName
    # $2 - sisyphusName
    theirModuleName="$1"
    sisyphusName="$2"

# 8<----------------------------------------------------------------------------
# 1. Clone git repo

echo "*** Cloning git repo ***"
if [ -d "$sisyphusName" ]; then
    echo "$sisyphusName directory exists. Skip clonning."
    break
fi

girar-get-upload-method "$sisyphusName" --no-output
packageExists="$?"
if [ "$packageExists" -lt 4 ]; then
    echo "Cloning $sisyphusName..."
    if [ "$packageExists" = "3" ]; then
        git clone --quiet git:/srpms/"${sisyphusName:0:1}"/"$sisyphusName"
    else # "$packageExists" = "0"
        git clone --quiet git:/gears/"${sisyphusName:0:1}"/"$sisyphusName"
    fi
fi

# 8<----------------------------------------------------------------------------
# 2. Rename spec file

moduleDir=$(pwd)/"$sisyphusName"
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
# 3. Download tarball

echo "*** Downloading source tarball ***"
wget --quiet --show-progress \
    $(grep "^$theirModuleName " ../scrapped.list | cut -d" " -f4)
tarball=$(find . -name "*.tar.gz")
version="$(sed -e "s/.*-\(.*\)\.tar\.gz/\1/" <<< "$tarball")"

# 8<----------------------------------------------------------------------------
# 4. Generate changelog

echo "*** Generating changelog ***"

changelogEntry="- Automatically updated to $version."
if [ $specRenamed == 1 ]; then
    changelogEntry=$changelogEntry"\n- Renamed spec file."
fi
changelogEntry=$(echo -e $changelogEntry)

# 8<----------------------------------------------------------------------------
# 5. Make upgrade

echo "*** Updating repo ***"
gear-uupdate -q "$tarball" "$version" --changelog "$changelogEntry"

# 8<----------------------------------------------------------------------------
# 6. Update build requires

echo "*** Updating build requires ***"
# split BR each on own line
sed -i -E '/^BuildRequires:/s/(BuildRequires:[[:space:]]*)?([^[:space:]]+([[:space:]]*>=?[[:space:]]*?[0-9.]+)?)/BuildRequires: \2/g' "$correctSpecLocation"
sed -i -E 's/[[:space:]]+(BuildRequires:)/\n\1/g' "$correctSpecLocation"

# git repo of modules always contains . .gear .git and our destination
sourceDir="$(find -maxdepth 1 -type d | grep -v ".git" | grep -v ".gear" | grep "/")"

# Verify BuildRequires

# Remove absolutely useless BuildRequires
sed -i -E '/^BuildRequires: python3-devel/d' "$correctSpecLocation"
sed -i -E '/^BuildRequires: python3-dev/d' "$correctSpecLocation"
sed -i -E '/^BuildRequires: python3-module-setuptools/d' "$correctSpecLocation"

# Rewrite build requires in normal mode
grep "BuildRequires:" "$correctSpecLocation" | while read buildRequirementLine; do
    buildRequirement=$(echo $buildRequirementLine | cut -d" " -f2)

    if [ $(echo "$buildRequirement" | grep python3-module-) ]; then
        noarchPath=/space/ALT/Sisyphus/noarch/RPMS.classic/$buildRequirement-[0123456789]*
        x86_64Path=/space/ALT/Sisyphus/x86_64/RPMS.classic/$buildRequirement-[0123456789]*
        [ -f $noarchPath ] && rpmPath=$noarchPath
        [ -f $x86_64Path ] && rpmPath=$x86_64Path
        buildReqNormalized=$(rpm -q --provides -p $rpmPath | sort -u | \
            grep -v python3-module- | head -n1)
        [ -n "$buildReqNormalized" ] && \
            sed -i -E "s/$buildRequirement([[:space:]]|$)/$buildReqNormalized\1/" "$correctSpecLocation"
    fi

git commit -am "tmp"



#    grep -r "import.*$buildRequirement" $sourceDir || \
#        grep -r "from.*$buildRequirement.*import" $sourceDir || \
#        sed -i -E "/$buildRequirementLine/d" "$correctSpecLocation"
done

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
#rpm --addsign $srpmName
#rsync -aP $srpmName gyle:
#git clean -fdx
popd > /dev/null

}

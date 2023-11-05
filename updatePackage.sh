#!/bin/bash -u

# 1. Clone git repo
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
else
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
fi

moduleDir=$(pwd)/"$sisyphusName"
pushd "$moduleDir" > /dev/null
specFileLocation=$(find $moduleDir -name "*.spec")

# 8<----------------------------------------------------------------------------
# 3. Download tarball

echo "*** Downloading source tarball ***"
if [ -f "$moduleName.watch" ]; then
    echo "Watch file exist!"
else
    tarballUrl=$(grep "^$theirModuleName " ../scrapped.list | cut -d" " -f4)
    echo "version=3" > $moduleName.watch
    echo $tarballUrl | sed -E 's/[0-9]+(\.[0-9]+)*/(\\d[[:digit:].]+)/' >> $moduleName.watch
fi
rpm-uscan
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
sed -i -E '/^BuildRequires:/s/(BuildRequires:[[:space:]]*)?([^[:space:]]+([[:space:]]*>=?[[:space:]]*?[0-9.]+)?)/BuildRequires: \2/g' "$specLocation"
sed -i -E 's/[[:space:]]+(BuildRequires:)/\n\1/g' "$specLocation"

# Verify BuildRequires

# Remove absolutely useless BuildRequires
sed -i -E '/^BuildRequires: python3-devel/d' "$specLocation"
sed -i -E '/^BuildRequires: python3-dev/d' "$specLocation"

grep "BuildRequires:" "$specLocation" | while read buildRequirementLine; do
    buildRequirement=$(echo $buildRequirementLine | cut -d" " -f2)
    if [ $(echo "$buildRequirement" | grep -c python3-module-) ]; then
        noarchPath=/space/ALT/Sisyphus/noarch/RPMS.classic/$buildRequirement-[0123456789]*
        x86_64Path=/space/ALT/Sisyphus/x86_64/RPMS.classic/$buildRequirement-[0123456789]*
        [ -f $noarchPath ] && rpmPath=$noarchPath
        [ -f $x86_64Path ] && rpmPath=$x86_64Path
        buildReqNormalized=$(rpm -q --provides -p $rpmPath | sort -u | \
            grep -v python3-module- | head -n1)
# Rewrite build requires in normal mode (off)
        [ -z "x" ] && \
        [ -n "$buildReqNormalized" ] && \
            sed -i -E "s/$buildRequirement([[:space:]]|$)/$buildReqNormalized\1/" "$specLocation"

        moduleRequirement=$(echo $buildReqNormalized | sed -E 's/python3\((.*)\)/\1/')
# Filter useless extra build requires
        [ $(find . -name '*.py' | \
            xargs grep "import.* $moduleRequirement\|from.* $moduleRequirement.*import" | wc -l) == 0 ] \
        && [ $(find . -name '*.ini' -o -name 'conf.py' -o -name 'setup.py' | \
        xargs grep "$moduleRequirement" | wc -l) == 0 ] && \
            sed -i "/$buildRequirementLine/d" "$specLocation"
    fi
done

# Bring back setuptools and wheel, as they are nessesary for new macros
sed -i "s,BuildRequires(pre): rpm-build-python3,BuildRequires(pre): rpm-build-python3\nBuildRequires: python3-module-setuptools\nBuildRequires: python3-module-wheel," $specLocation

# git repo of modules always contains . .gear .git and our destination
sourceDir="$(find -maxdepth 1 -type d | grep -v ".git" | grep -v ".gear" | grep "/")"

cat "$sourceDir/requirements.txt" "$sourceDir/test-requirements.txt" | while read reqLine; do
    if [[ "$reqLine" =~ ">" ]] && [ ! $(echo $reqLine | grep -q "^#" && echo $?) ]; then
        reqName=$(tr [:upper:] [:lower:] <<< \
            $(echo "$reqLine" | cut -d"!" -f1 | cut -d">" -f1))
        if [ ! $(grep -q python3-module-$reqName "$specLocation" && echo $?) ]; then
        # Count line number to input new build requirement
            brStarted=""
            lineNumber=0
            cooldownFlag=2
            while read line; do
            if [ -z "$brStarted" ] && [ ! $(echo $line | grep -q 'BuildRequires:' && echo $?) ]; then
                echo "Skip first strings" > /dev/null
            elif [ -z "$brStarted" ] && [ $(echo $line | grep -q 'BuildRequires:' && echo $?) ]; then
                brStarted="x"
            elif [ "$brStarted" == "x" ] && [ $(echo $line | grep -q 'BuildRequires:' && echo $?) ]; then
                cooldownFlag=2
            elif [ "$brStarted" == "x" ] && [ $cooldownFlag -gt 0 ] && [ ! "$(echo $line | grep -q 'BuildRequires:' && echo $?)" ] ; then
                let "cooldownFlag-=1"
            else
                break
            fi

            let "lineNumber+=1"
            echo ${lineNumber}
            done < "$specLocation"

            let "lineNumber-=2"

            noarchPath=/space/ALT/Sisyphus/noarch/RPMS.classic/python3-module-$reqName-[0123456789]*
            x86_64Path=/space/ALT/Sisyphus/x86_64/RPMS.classic/python3-module-$reqName-[0123456789]*

            if [ -f $noarchPath -o -f $x86_64Path ]; then
                sed -Ei "${lineNumber}aBuildRequires: python3-module-$reqName" "$specLocation"
            fi
        fi
        reqVersion=$(sed -nE "s/$reqName[^ ;]*>=?([0-9.]+).*/\1/p" <<< $reqLine)
        [ -z $reqVersion ] || sed -Ei "s/(python3-module-$reqName)([[:space:]]|$).*/\1 >= $reqVersion/" "$specLocation"
    fi
done

# 8<----------------------------------------------------------------------------

git commit -am "tmp"
gear-commit -a --amend --no-edit
srpmName=$(gear-rpm -bs --nodeps | cut -d":" -f2)
#rpm --addsign $srpmName
#rsync -aP $srpmName gyle:
#git clean -fdx
popd > /dev/null

}

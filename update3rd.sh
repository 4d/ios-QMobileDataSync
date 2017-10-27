#!/bin/bash

# first get last
rm -Rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/QMobile*
# rm -f Cartfile.resolved

file=Cartfile.resolved
url=https://gitfusion.wakanda.io/qmobile/

echo "- before:"
cat $file

sed -i '' '/QMobile/d' $file

for f in ../QMobile*; do
    if [[ -d $f ]]; then
          hash=`git -C $f rev-parse HEAD`

        f="$(basename $f)"
        if grep -q $f "Cartfile"; then
            line="git \"$url$f.git\" \"$hash\""

            echo "$line" >> "$file"
        fi
    fi
done
echo "- after:"
cat $file

# checkout
carthage checkout --no-use-binaries

# Remove Reactivate extension from Moya

## Sources
rm -Rf Carthage/Checkouts/Reactive*
rm -Rf Carthage/Checkouts/Rx*

## Build artifact
rm -Rf Carthage/Build/Reactive*
rm -Rf Carthage/Build/Rx*

## Build scheme
rm -Rf Carthage/Checkouts/Moya/Moya.xcodeproj/xcshareddata/xcschemes/Reactive*
rm -Rf Carthage/Checkouts/Moya/Moya.xcodeproj/xcshareddata/xcschemes/Rx*


## In Cartfile (mandatory or carthage will try to compile or resolve dependencies)
sed -i '' '/Reactive/d' Cartfile.resolved
sed -i '' '/Rx/d' Cartfile.resolved

sed -i '' '/Reactive/d' Carthage/Checkouts/Moya/Cartfile.resolved
sed -i '' '/Rx/d' Carthage/Checkouts/Moya/Cartfile.resolved

sed -i '' '/Reactive/d' Carthage/Checkouts/Moya/Cartfile
sed -i '' '/Rx/d' Carthage/Checkouts/Moya/Cartfile

# build
carthage build --platform iOS --cache-builds --log-path "build/log"

#  https://github.com/Carthage/Carthage/issues/1986?

cat "build/log" | xcpretty

sdk=`xcrun -sdk iphonesimulator -show-sdk-path`
sdkVersion=`echo $sdk | sed -E 's/.*iPhoneSimulator(.*)\.sdk/\1/'`
swift build  -Xswiftc "-sdk" -Xswiftc "$sdk" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios$sdkVersion-simulator"

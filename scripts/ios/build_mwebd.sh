#!/bin/bash
if [[ "$1" == "--dont-install" ]]; then
  echo "Skipping Go installation as per --dont-install flag"
else
  # install go > 1.23:
  brew install go
  export PATH=$PATH:~/go/bin
  go install golang.org/x/mobile/cmd/gomobile@latest
  gomobile init
fi

# build mwebd:
git clone https://github.com/ltcmweb/mwebd
cd mwebd
git reset --hard 555349415f76a42ec5c76152b64c4ab9aabc448f
gomobile bind -target=ios .
mv -fn ./Mwebd.xcframework ../../../cw_mweb/ios/
# cleanup:
cd ..
rm -rf mwebd
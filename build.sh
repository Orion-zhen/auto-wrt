#!/bin/bash

git clone -b master --single-branch https://github.com/immortalwrt/immortalwrt.git

cp .config immortalwrt/

cd immortalwrt

./scripts/feeds update -a
./scripts/feeds install -a

make -ja
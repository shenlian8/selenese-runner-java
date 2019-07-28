#!/bin/bash

set -eu

version="master"

base_url="https://raw.githubusercontent.com/SeleniumHQ/selenium-ide/$version/packages/side-model/src"

cd $(dirname "$0")/../src/main/resources/selenium-ide
for f in ArgTypes.js Commands.js; do
  ( set -x; curl -LO $base_url/$f )
done

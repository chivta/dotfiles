#!/bin/bash
# Turns the empty eval workspace (cwd) into amo_cms at a pinned commit.
set -euo pipefail

SOURCE_REPO=/Users/vlasenko.artem/Projects/cms/.bare
# origin/HEAD (stage) of SOURCE_REPO when the suite was written; bump it on purpose
PINNED_SHA=261f5f293f1583aeb14d8da20bb9ca8894defdf4

git clone --quiet --shared --no-checkout "$SOURCE_REPO" .
git checkout --quiet --detach "$PINNED_SHA"
# Runs have no network anyway; dropping origin keeps agents from trying to fetch or push
git remote remove origin

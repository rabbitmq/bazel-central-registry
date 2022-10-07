#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -euxo pipefail

# set NAME and VERSION in env
NAME_DASH_VERSION=${NAME}-${VERSION}

WORKDIR="$(mktemp -d)"

cd ${WORKDIR}
curl -LO https://repo.hex.pm/tarballs/${NAME_DASH_VERSION}.tar
mkdir ${NAME_DASH_VERSION}
cd ${NAME_DASH_VERSION}
tar -xf ../${NAME_DASH_VERSION}.tar

${SCRIPT_DIR}/hex_metadata_to_json \
    metadata.config > metadata.json

cp ${SCRIPT_DIR}/WORKSPACE.tpl \
    WORKSPACE

cat << EOF > MODULE.bazel
module(
    name = "${NAME}",
    version = "${VERSION}",
    compatibility_level = 1,
)

bazel_dep(
    name = "rules_erlang",
    version = "3.8.0",
)
EOF

python3 ${SCRIPT_DIR}/gen_build_file.py \
    metadata.json > BUILD.bazel

buildifier WORKSPACE MODULE.bazel BUILD.bazel

cd ${SCRIPT_DIR}/..

cat << EOF > ${NAME_DASH_VERSION}.json
{
    "build_file": "${WORKDIR}/${NAME_DASH_VERSION}/BUILD.bazel",
    "build_targets": [
        "@${NAME}//:${NAME}",
        "@${NAME}//:erlang_app"
    ],
    "compatibility_level": "1",
    "deps": [],
    "module_dot_bazel": "${WORKDIR}/${NAME_DASH_VERSION}/MODULE.bazel",
    "name": "${NAME}",
    "patch_strip": 0,
    "patches": [],
    "presubmit_yml": null,
    "strip_prefix": null,
    "test_module_build_targets": [],
    "test_module_path": null,
    "test_module_test_targets": [],
    "url": "https://repo.hex.pm/tarballs/${NAME_DASH_VERSION}.tar",
    "version": "${VERSION}"
}
EOF

python3 ./tools/add_module.py \
    --input=${NAME_DASH_VERSION}.json

#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -euxo pipefail

# set NAME, VERSION and WORKDIR in env
NAME_DASH_VERSION=${NAME}-${VERSION}

mkdir -p ${WORKDIR}
cd ${WORKDIR}
if [[ ! -f ${NAME_DASH_VERSION}.tar ]]; then
    curl -LO https://repo.hex.pm/tarballs/${NAME_DASH_VERSION}.tar
fi
mkdir -p ${NAME_DASH_VERSION}
cd ${NAME_DASH_VERSION}
if [[ ! -f VERSION ]]; then
    tar -xf ../${NAME_DASH_VERSION}.tar
fi

if [[ ! -f WORKSPACE ]]; then
    cp ${SCRIPT_DIR}/WORKSPACE.tpl \
        WORKSPACE
fi

if [[ ! -f MODULE.bazel ]]; then
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
fi

cd ${SCRIPT_DIR}/..
bazel run //:gazelle ${WORKDIR}/${NAME_DASH_VERSION}

cd ${WORKDIR}/${NAME_DASH_VERSION}

buildifier WORKSPACE MODULE.bazel BUILD.bazel

bazel build //... \
    --experimental_enable_bzlmod

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

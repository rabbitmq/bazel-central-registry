load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib",
    sha256 = "af87959afe497dc8dfd4c6cb66e1279cb98ccc84284619ebfec27d9c09a903de",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "rules_erlang",
    remote = "https://github.com/rabbitmq/rules_erlang.git",
    tag = "3.8.0",
)

load(
    "@rules_erlang//:rules_erlang.bzl",
    "erlang_config",
    "rules_erlang_dependencies",
)

erlang_config()

rules_erlang_dependencies()

load("@erlang_config//:defaults.bzl", "register_defaults")

register_defaults()

import json
import sys

BUILD_FILE_LOADS = """\
load("@rules_erlang//:untar.bzl", "untar")
load("@rules_erlang//:app_file.bzl", "app_file")
load("@rules_erlang//:erlang_bytecode.bzl", "erlang_bytecode")
load("@rules_erlang//:erlang_app_info.bzl", "erlang_app_info")
"""

def existing(contents, name):
    # print("existing", contents, name)
    for item in contents:
        if isinstance(item, str):
            if item == name:
                return item
        else:
            if item[0] == name:
                return item

def tree_insert(files_tree, components):
    # print("tree_insert", files_tree, components)
    assert len(components) > 0
    if len(components) == 1:
        if existing(files_tree, components[0]) == None:
            files_tree.append(components[0])
    else:
        directory = existing(files_tree, components[0])
        if directory == None:
            directory = (components[0], [])
            files_tree.append(directory)
        tree_insert(directory[1], components[1:])

def as_tree(tar_entries):
    files_tree = []
    for entry in tar_entries:
        parts = entry.split("/")
        tree_insert(files_tree, parts)
    return files_tree

def as_list(files_tree, files, parent):
    # print("as_list", files_tree, files, parent)
    for item in files_tree:
        if isinstance(item, str):
            if parent != None:
                files.append("/".join([parent, item]))
            else:
                files.append(item)
        else:
            if parent != None:
                as_list(item[1], files, "/".join([parent, item[0]]))
            else:
                as_list(item[1], files, item[0])

def select(files_tree, ks):
    # print("SELECT", files_tree, ks)
    assert len(ks) > 0
    e = existing(files_tree, ks[0])
    # print("found", e)
    if len(ks) == 1:
        return [e]
    else:
        return [(ks[0], select([ks[1]], ks[1:]))]

# def select_file(files_tree, ks, name):
#     return None

# def child(files_tree_selection):
#     print(files_tree_selection)
#     for item in files_tree_selection.values():
#         return item

def untar_rule(files_tree):
    files = []
    as_list(files_tree, files, None)

    return """\
untar(
    name = "contents",
    outs = {},
)
""".format(files)

def erlang_bytecode_rule(files_tree):
    include = select(files_tree, ["include"])
    src = select(files_tree, ["src"])

    # print("include", include)
    # print("src", src)

    hdrs = []
    as_list(include, hdrs, None)
    as_list(src, hdrs, None)
    hdrs = [f for f in hdrs if f.endswith(".hrl")]

    srcs = []
    as_list(src, srcs, None)
    srcs = [f for f in srcs if f.endswith(".erl")]

    return """\
erlang_bytecode(
    name = "beam_files",
    hdrs = {hdrs},
    srcs = {srcs},
    erlc_opts = select({{
        "@rules_erlang//:debug_build": ["+debug_info"],
        "//conditions:default": ["+deterministic", "+debug_info"],
    }}),
    dest = "ebin",
)
""".format(
    hdrs = hdrs,
    srcs = srcs,
)

def app_file_rule(name, version, description, files_tree):
    # print("files_tree", files_tree)
    # print(select(files_tree, ["src", name + ".app.src"]))
    app_src = []
    as_list(
        select(files_tree, ["src", name + ".app.src"]),
        app_src,
        None,
    )

    return """\
app_file(
    name = "app_file",
    app_name = "{name}",
    app_version = "{version}",
    app_description = "{description}",
    app_src = {app_src},
    modules = [":beam_files"],
    dest = "ebin",
    stamp = 0,
)
""".format(
    name = name,
    version = version,
    description = description,
    app_src = app_src,
)

def erlang_app_info_rule(name, files_tree):
    include = select(files_tree, ["include"])
    src = select(files_tree, ["src"])

    hdrs = []
    as_list(include, hdrs, None)
    hdrs = [f for f in hdrs if f.endswith(".hrl")]

    srcs = []
    as_list(include, srcs, None)
    as_list(src, srcs, None)

    return """\
erlang_app_info(
    name = "{name}",
    app_name = "{name}",
    hdrs = {hdrs},
    app = ":app_file",
    beam = [":beam_files"],
    license_files = [
        "LICENSE",
    ],
    srcs = {srcs},
    visibility = ["//visibility:public"],
)
""".format(
    name = name,
    hdrs = hdrs,
    srcs = srcs,
)

def alias_rule(name):
    return """\
alias(
    name = "erlang_app",
    actual = ":{name}",
    visibility = ["//visibility:public"],
)
""".format(name = name)

def _print_tree(files_tree, indent):
    for item in files_tree:
        if isinstance(item, str):
            print(indent, item)
        else:
            print(indent, item[0], "->")
            _print_tree(item[1], indent + "\t")

def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    hex_metadata_json_file = argv[0]

    hex_metadata = json.load(open(hex_metadata_json_file))

    files_tree = as_tree(sorted(hex_metadata["files"], key=len, reverse=True))

    # _print_tree(files_tree, indent = "\t")

    name = hex_metadata["name"]
    version = hex_metadata["version"]
    description = hex_metadata["description"]

    sections = [BUILD_FILE_LOADS]

    sections.append(untar_rule(files_tree))

    sections.append(erlang_bytecode_rule(files_tree))

    sections.append(app_file_rule(name, version, description, files_tree))

    sections.append(erlang_app_info_rule(name, files_tree))

    sections.append(alias_rule(name))

    build_file_content = "\n\n".join(sections)

    print(build_file_content)

if __name__ == "__main__":
  sys.exit(main())

#
# Key targets in this Makefile:
#
# Note:
# * The `all` and `install` targets require `swift` command-line tools
#   be installed, but nothing else.
# * Other targets require protoc be already installed, `update` requires
#   a source checkout of Google's protobuf project.
#
# make all
#   Build protoc-gen-swift from current sources
# make install BINDIR=/usr/local/bin
#   Copy protoc-gen-swift to BINDIR
# make regenerate
#   Rebuild Swift source used by protoc-gen-swift from proto files
#   (requires protoc-gen-swift be already compiled and protoc is in the $PATH)
# make update PROTOBUF_PROJECT_DIR=../protobuf
#   Copy useful proto files from Google's protobuf project
#   (requires a source checkout of Google's protobuf project)
#   (only needed if Google's descriptor or plugin protos have changed)
# make test
#   Check generated Swift by comparing output to stored reference files
#   (Requires protoc-gen-swift be already compiled and protoc is in $PATH)
# make reference
#   Replace reference files
#   (Requires protoc-gen-swift be already compiled and protoc is in $PATH)
#   WARNING:  You must MANUALLY verify the updated files before committing them
#

#
# How to build and test this project:
#
# 0. Install protoc (recent 3.0.0 or later)
# 1. Build the project
#    $ make
# 2. Check that the generated output is unchanged
#    $ make test
# 3. If no changes, install
#    $ make install BINDIR=/usr/local/bin
#
# If the generated output has changed,
#
# 1. Update the reference files
#    $ make reference
# 2. MANUALLY verify that the changes are correct
#    $ git diff Test/reference
# 3. Commit the changed reference files
#    $ git commit Test/reference
#
# If protobuf project has changed descriptor.proto or plugin.proto,
#
# 1. Get the new proto files
#    $ make update PROTOBUF_PROJECT_DIR=../protobuf
# 2. Regenerate the protos used by protoc-gen-swift
#    $ make regenerate
# 3. Rebuild and test as above
#
#

# How to run a 'swift' executable that supports the 'swift build' command.
SWIFT=swift

# How to run a working version of protoc
PROTOC=protoc

# Path to a source checkout of Google's protobuf project, used
# by the 'update' target.
PROTOBUF_PROJECT_DIR=../protobuf

# Installation directory
BINDIR=/usr/local/bin

INSTALL=install

PROTOC_GEN_SWIFT=.build/debug/protoc-gen-swift

# Source code for the plugin
SOURCES= \
	Sources/CodePrinter.swift \
	Sources/Context.swift \
	Sources/EnumGenerator.swift \
	Sources/ExtensionGenerator.swift \
	Sources/FileGenerator.swift \
	Sources/FileIo.swift \
	Sources/MessageFieldGenerator.swift \
	Sources/MessageGenerator.swift \
	Sources/OneofGenerator.swift \
	Sources/ReservedWords.swift \
	Sources/StringUtils.swift \
	Sources/Version.swift \
	Sources/descriptor.pb.swift \
	Sources/main.swift \
	Sources/plugin.pb.swift \
	Sources/swift-options.pb.swift

# Protos from Google's source that are used for testing purposes
# All are in Protos/google/protobuf
GOOGLE_PROTOS= \
	any \
	any_test \
	api \
	descriptor \
	duration \
	empty \
	field_mask \
	map_lite_unittest \
	map_proto2_unittest \
	map_unittest \
	map_unittest_proto3 \
	source_context \
	struct \
	timestamp \
	type \
	unittest \
	unittest_arena \
	unittest_custom_options \
	unittest_drop_unknown_fields \
	unittest_embed_optimize_for \
	unittest_empty \
	unittest_import \
	unittest_import_lite \
	unittest_import_proto3 \
	unittest_import_public \
	unittest_import_public_lite \
	unittest_import_public_proto3 \
	unittest_lite \
	unittest_lite_imports_nonlite \
	unittest_mset \
	unittest_mset_wire_format \
	unittest_no_arena \
	unittest_no_arena_import \
	unittest_no_arena_lite \
	unittest_no_field_presence \
	unittest_no_generic_services \
	unittest_optimize_for \
	unittest_preserve_unknown_enum \
	unittest_preserve_unknown_enum2 \
	unittest_proto3 \
	unittest_proto3_arena \
	unittest_proto3_arena_lite \
	unittest_proto3_lite \
	unittest_well_known_types \
	wrappers

# Extra test Protos used to validate various features
# All are in Protos/test
TEST_PROTOS= \
	option_apple_swift_prefix \
	test_names

.PHONY: default all build check clean install test update update-ref

default: build

all: build

build: protoc-gen-swift

protoc-gen-swift: $(PROTOC_GEN_SWIFT)
	cp $< $@

$(PROTOC_GEN_SWIFT): ${SOURCES}
	${SWIFT} build

install:
	${INSTALL} ${PROTOC_GEN_SWIFT} ${BINDIR}

check: test

clean:
	rm -f protoc-gen-swift
	rm -rf .build
	rm -rf Test/_generated

# Verifies that the output of protoc-gen-test exactly matches
# the master reference files stored in the Test directory.
#
# This assumes, of course, that the various *.pb.swift-ref files
# contain exactly the output that protoc-gen-swift should generate.
# This is a good test if you are refactoring the code in ways
# that should not affect the output.  Otherwise, you will need to:
#  * Manually check the differences and run 'update-ref' to update the
#    reference files when you are convinced the changes are correct
#  * Run the test suite included in SwiftProtobufRuntime to verify that
#    the functionality is still correct.
test: build
	rm -rf Test/_generated && mkdir -p Test/_generated
	ABS_TOPDIR=`pwd`; \
	for t in ${GOOGLE_PROTOS}; do \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=Test/_generated -I Protos Protos/google/protobuf/$$t.proto; \
		diff -bBu Test/reference/$$t.pb.swift Test/_generated/$$t.pb.swift | head -n 50; \
	done; \
	for t in ${TEST_PROTOS}; do \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=Test/_generated -I Protos Protos/test/$$t.proto; \
		diff -bBu Test/reference/$$t.pb.swift Test/_generated/$$t.pb.swift | head -n 50; \
	done

#
# Regenerates plugin.pb.swift and descriptor.pb.swift from protobuf sources.
# This defines the communications between protoc and the plugin.
#
# This could be a prerequisite for 'build' except that it requires
# the plugin to already be built and also requires protoc to be installed.
#
regenerate:
	${PROTOC} --plugin=$(PROTOC_GEN_SWIFT) --swift_out=Sources -I Protos Protos/google/protobuf/descriptor.proto Protos/google/protobuf/compiler/plugin.proto Protos/swift-options.proto

#
# Updates the local copy of Google test protos
#
# Note: It is not necessary to do this regularly.  If you do,
# you should also `make update-ref` to update the corresponding
# *.pb.swift-ref files to reflect any changes in the original protos.
update:
	ABS_PBDIR=`cd ${PROTOBUF_PROJECT_DIR}; pwd`; \
	for t in ${GOOGLE_PROTOS}; do cp $${ABS_PBDIR}/src/google/protobuf/$$t.proto Protos/google/protobuf; done; \
	cp $${ABS_PBDIR}/src/google/protobuf/compiler/plugin.proto Protos/google/protobuf/compiler

#
# Rebuild all of the *.pb.swift reference files by
# running the current version of protoc-gen-swift against
# the captured request protos
#
# If you do this, you MUST MANUALLY verify these files
# before checking them in, since the new checkin will
# become the new master reference.
#
reference:
	ABS_TOPDIR=`pwd`; \
	for t in ${GOOGLE_PROTOS}; do \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=Test/reference -I Protos Protos/google/protobuf/$$t.proto; \
	done; \
	for t in ${TEST_PROTOS}; do \
		${PROTOC} --plugin=$${ABS_TOPDIR}/protoc-gen-swift --swift_out=Test/reference -I Protos Protos/test/$$t.proto; \
	done

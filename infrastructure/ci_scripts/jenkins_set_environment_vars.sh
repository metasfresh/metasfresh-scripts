#!/bin/bash
#
# determine which maven artifact version we will set this build to
# This script is intended to be called from withing CI (jenkins) build jobs
# Also see https://github.com/metasfresh/metasfresh-documentation/blob/master/infrastructure/CI_infrastructure.md
#

# example "origin/FRESH-123" => "FRESH-123"
GIT_BRANCH_LOCALNAME=${GIT_BRANCH#*/}

# set the version prefix, 1 for "master", 2 for "not-master" a.k.a. feature
if [["${GIT_BRANCH_LOCALNAME}" == "master" ]]; then BUILD_MAVEN_VERSION_PREFIX="1"; else BUILD_MAVEN_VERSION_PREFIX="2"; fi

# examples: "1-master-SNAPSHOT", "2-FRESH-123-SNAPSHOT"
BUILD_MAVEN_VERSION_LOCAL="${BUILD_MAVEN_VERSION_PREFIX}-${GIT_BRANCH_LOCALNAME}-SNAPSHOT"

# use the maven version we got from the outside, or fallback to our self-build BUILD_MAVEN_VERSION_LOCAL
BUILD_MAVEN_VERSION=${PARAM_BUILD_MAVEN_VERSION:-${BUILD_MAVEN_VERSION_LOCAL}} 

# examples: "[1-master-SNAPSHOT],[2-FRESH-123-SNAPSHOT], "[1-master-SNAPSHOT],[1-master-SNAPSHOT]"
BUILD_MAVEN_METASFRESH_DEPENDENCY_VERSION="[1-master-SNAPSHOT],[${BUILD_MAVEN_VERSION}]"

# output them to make things more clear
echo GIT_BRANCH_LOCALNAME=${GIT_BRANCH_LOCALNAME}
echo BUILD_MAVEN_VERSION_LOCAL=${BUILD_MAVEN_VERSION_LOCAL}
echo BUILD_MAVEN_METASFRESH_DEPENDENCY_VERSION=${BUILD_MAVEN_METASFRESH_DEPENDENCY_VERSION}
echo BUILD_MAVEN_VERSION=${BUILD_MAVEN_VERSION}

# write them to a txt file that can in the next step be loaded by the inject-environment-variables-plugin
echo BUILD_MAVEN_VERSION=${BUILD_MAVEN_VERSION} > BUILD_ENVIRONMENT_VARS.txt
echo BUILD_MAVEN_METASFRESH_DEPENDENCY_VERSION=${BUILD_MAVEN_METASFRESH_DEPENDENCY_VERSION} >> BUILD_ENVIRONMENT_VARS.txt

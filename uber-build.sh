#!/bin/bash -e

if [ -n "$DEBUG" ]
then
  set -x
fi

# Initialize file descriptors. May be modified later.
exec 6>&1 7>&1

#################################################################
# Unification script
#
# This script was created to support multiple test cases:
# * generating Scala IDE + plugins releases
# * being run during Scala PR validation
# * being run locally to reproduce Scala PR validation results
# * run every night to check the script itself
#
# Main features:
# * rebuilds and cache each piece as required
# * gets instructions from a 'config' file
##################################################################

# temp dir were all 'non-build' operation are performed
TMP_ROOT_DIR=$(mktemp -d -t uber-build.XXXX)
TMP_DIR="${TMP_ROOT_DIR}/tmp"
TMP_CACHE_DIR="${TMP_ROOT_DIR}/cacheLink"
mkdir "${TMP_DIR}"

# Timestamp used for logging and marking zip files
TIMESTAMP=`date '+%Y%m%d-%H%M'`

# ant options. The Scala build needs a fair amount of memory
export ANT_OPTS="-Xms512M -Xmx2048M -Xss1M -XX:MaxPermSize=128M"

####################
# logging functions
####################

# Logging about step being performed
# $1 - title
function printStep () {
  echo ">>>>> $1" >&6
}

# General logging
# $* - message
function info () {
  echo ">> $*" >&6
}

# Debug logging for variable
# $1 - variable name
function debugValue () {
  echo "----- $1=${!1}"
}

# General debug logging
# $* - message
function debug () {
  echo "----- $*"
}

# General error logging
# $* - message
function error () {
  echo "!!!!! $*" >&2
  exit 3
}

# Error logging for wrong variable value
# $1 - variable name
# $2 - possible choices
function missingParameterChoice () {
  echo "!!!!! Bad value for $1. Was '${!1}', should be one of: $2." >&2
  exit 2
}

#########
# Checks
#########

# Check if the given parameters are defined
# $* - parameter names to check non-empty
function checkParameters () {
  for i in $*
  do
    if [ -z "${!i}" ]
    then
      echo "!!!!! Bad value for $i. It should be defined." >&2
      exit 2
    fi
  done
}

# Check if an artifact is available
# $1 - groupId
# $2 - artifacId
# $3 - version
# $4 - extra repository to look in (optional)
# return value is 0 if the artifact is available
function checkAvailability () {
  cd "${TMP_DIR}"
  rm -rf *

# pom file for the test project
  cat > pom.xml << EOF
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.typesafe</groupId>
  <artifactId>typesafeDummy</artifactId>
  <packaging>war</packaging>
  <version>1.0-SNAPSHOT</version>
  <name>Dummy</name>
  <url>http://127.0.0.1</url>
  <dependencies>
    <dependency>
      <groupId>$1</groupId>
      <artifactId>$2</artifactId>
      <version>$3</version>
    </dependency>
  </dependencies>
  <repositories>
    <repository>
      <id>sonatype.snapshot</id>
      <name>Sonatype maven snapshot repository</name>
      <url>https://oss.sonatype.org/content/repositories/snapshots</url>
      <snapshots>
        <updatePolicy>daily</updatePolicy>
      </snapshots>
    </repository>
EOF

  if [ -n "$4" ]
  then
# adds the extra repository
    cat >> pom.xml << EOF
    <repository>
      <id>extrarepo</id>
      <name>extra repository</name>
      <url>$4</url>
    </repository>
EOF
  fi

  cat >> pom.xml << EOF
  </repositories>
</project>
EOF

  set +e
  mvn "${MAVEN_ARGS[@]}" compile >&7 2>&7
  RES=$?
  set -e

# log the result
  if [ ${RES} == 0 ]
  then
    debug "$1:$2:jar:$3 found !"
  else
    debug "$1:$2:jar:$3 not found !"
  fi

  return ${RES}
}

# Like check availability, but fail if not available.
# $1 - groupId
# $2 - artifactId
# $3 - version
# $4 - extra repository (optional)
function checkNeeded () {
  if ! checkAvailability "$1" "$2" "$3" "$4"
  then
    error "$1:$2:jar:$3 is needed !!!"
  fi
}

# Check if the given executable is in the PATH.
# $1 - executable
# return value is 0 if the executable was found.
function checkExecutableOnPath () {
  BIN_LOCATION=$(which $1)
}

########################
# cache support
########################

# Check if a directory is available in the cache.
# $1 - cache id
# $2 - force cache usage ("true"|"false", optional)
# return values
#   0 - found
#   1 - not found
#   2 - caching disabled
function checkCache () {
  FORCE_CACHE="${2:-false}"
  if ${FORCE_CACHE} || ${WITH_CACHE}
  then
    if [ -d "${P2_CACHE_DIR}/$1" ]
    then
      debug "$1 found !"
      return 0
    else
      debug "$1 not found !"
      return 1
    fi
  else
    debug "caching disabled"
    return 2
  fi
}

# Store a directory in the cache.
# $1 - cache id
# $2 - directory to cache
# $3 - force cache usage ("true"|"false", optional)
function storeCache () {
  FORCE_CACHE="${3:-false}"
  if ${FORCE_CACHE} || ${WITH_CACHE}
  then
    mkdir -p "$(dirname "${P2_CACHE_DIR}/$1")"
    cp -r "$2" "${P2_CACHE_DIR}/$1"
    debug "$1 cached !"
  else
# only caching the original location
    mkdir -p "${TMP_CACHE_DIR}/$1"
    echo -n "$2" > "${TMP_CACHE_DIR}/$1/link"
  fi
}

# Return the location in the file system of the cached p2 repo.
# $1 - p2 cache id
# $2 - force cache usage ("true"|"false", optional)
function getCacheLocation () {
  FORCE_CACHE="${2:-false}"
  if ${FORCE_CACHE} || ${WITH_CACHE}
  then
    echo "${P2_CACHE_DIR}/$1"
  else
    cat "${TMP_CACHE_DIR}/$1/link"
  fi
}

# Return the location in the file system of the cached p2 repo.
# $1 - p2 cache id
# $2 - force cache usage ("true"|"false", optional)
function getCacheURL () {
  FORCE_CACHE="${2:-false}"
  if ${FORCE_CACHE} || ${WITH_CACHE}
  then
    FOLDER="${P2_CACHE_DIR}/$1"
  else
    FOLDER=$(cat "${TMP_CACHE_DIR}/$1/link")
  fi
  echo "file://${FOLDER/ /%20}"
}

# Merge a p2 repo into an other one.
# $1 - repository to merge
# $2 - location to merge it to
function mergeP2Repo () {
  BUILD_TOOLS_DIR="${BUILD_DIR}/build-tools"
  fetchGitBranch "$BUILD_TOOLS_DIR" "git://github.com/scala-ide/build-tools.git" master

  cd "$BUILD_TOOLS_DIR/maven-tool/merge-site/"
  mvn ${MAVEN_ARGS[@]} -Drepo.source="$1" -Drepo.dest="$2" package
}

############
# m2 + osgi
############

# Extract the osgi version form a META-INF/MANIFEST.MF file
# in the current directory.
function extractOsgiVersion () {
  # used \r as an extra field separator, to avoid problem with Windows style new lines.
  grep Bundle-Version META-INF/MANIFEST.MF | awk -F '[ \r]' '{printf $2;}'
}

# Extract the osgi version from the MANIFEST.MF file
# of an artifact available in the local m2 repo.
# $1 - groupId
# $2 - artifactId
# $3 - version
function osgiVersion () {
  cd "${TMP_DIR}"
  rm -rf *
  unzip -q "${LOCAL_M2_REPO}/${1//\.//}/$2/$3/$2-$3.jar"
  extractOsgiVersion
}

# Extract the osgi version from the MANIFEST.MF file of a jar.
# $1 - jar location
function osgiVersionFromJar () {
  cd "${TMP_DIR}"
  rm -rf *
  unzip -q "$1" "META-INF/MANIFEST.MF"
  extractOsgiVersion
}

##############
# GIT support
##############

# Checkout the given branch. Clone and fetch the remote repo as needed.
# $1 - local dir
# $2 - remote repo
# $3 - branch, tag or hash
# $4 - depth (TODO: really needed?)
# $5 - extra fetch (optional)
function fetchGitBranch () {
  if [ ! -d "$1/.git" ]
  then
    info "Cloning git repo $2"
    REMOTE_ID="remote01"
    rm -rf "$1"
    git clone -o ${REMOTE_ID} "$2" "$1"
    cd "$1"
  else
    cd "$1"
    # check if the remote repo is already defined
    REMOTE_ID=$(git config --get-regexp 'remote\..*\.url' | grep "$2" | awk -F '.' '{print $2;}')
    if [ -z "${REMOTE_ID}" ]
    then
      info "Adding remote git repo $2"
      LAST_REMOTE_ID=$(git config --get-regexp 'remote\.remote..\.url' | awk -F '.' '{print $2;}' | sort | tail -1)
      NEW_INDEX=$(( ${LAST_REMOTE_ID:6} + 1 ))
      REMOTE_ID="remote"$(printf '%02d' ${NEW_INDEX})
      git remote add ${REMOTE_ID} $2
    fi
    info "Fetching update for $2"
    git fetch --tag ${REMOTE_ID}
    git fetch ${REMOTE_ID}
  fi

  # add extra fetch config if needed
  if [ -n "$5" ]
  then
    FETCH_STRING="+refs/pull/*/head:refs/remotes/${REMOTE_ID}/$5/*"
    if git config --get-all "remote.${REMOTE_ID}.fetch" | grep -Fc "${FETCH_STRING}"
    then
      :
    else
      info "Add extra fetch config"
      git config --add "remote.${REMOTE_ID}.fetch" ${FETCH_STRING}
      git fetch ${REMOTE_ID}
    fi
  fi

  info "Checking out $3"
  IS_A_REMOTE_BRANCH=$(git branch -r | grep -q " ${REMOTE_ID}/$3\$"; echo $?)
  if [ $IS_A_REMOTE_BRANCH == 0 ]
  then
# it is a known remote branch
    git checkout -f -q ${REMOTE_ID}/$3
  else
# assumes it is a tag or a hash
    git checkout -f -q $3
  fi
  git clean -d -f -q

}

# Pulls the local zinc build from our directory into the target directory to actually execute.
# $1 - The directory into which we copy zinc.
function fetchLocalZinc() {
  if [ ! -x "$1/bin/dbuild" ]
  then
    rm -rf "$1"
    mkdir -p "$(dirname "$1")"
    if [ ! -x "${ZINC_DIR}/bin/dbuild"]
    then
      error "No local zinc build found!  Required in ${ZINC_DIR}."
    fi

    cp -R "${ZINC_DIR}" "$1"
  else
    # We recopy over the scripts only to make sure they're up-to-date
    cp ${ZINC_DIR}/*.properties "$1/"
    cp ${ZINC_DIR}/sbt-on-* "$1/"
  fi

}

##################
# Properties Helpers
##################

# Reads the given property value from a properties file.  Intended to be used as:
#   $(readProperty <file> <prop>)
# $1 The property file
# $2 The property
function readProperty() {
  local prop="$2"
  echo $(grep -x "sbt-version=.*" "$1" | awk '{ split($0,a,"="); print a[2] }')
}


##################
##################
# The build steps
##################
##################

##################
# Check arguments
##################

# $1 - error message
function printErrorUsageAndExit () {
  echo "$1" >&2
  echo "Usage:" >&2
  echo "  $0 <config_file> [scala_git_hash]" >&2
  exit 1
}

# $* - arguments
function stepCheckArguments () {
  printStep "Check arguments"

  if [ $# -gt 3 ]
  then
    printErrorUsageAndExit "Wrong arguments"
  fi

  CONFIG_FILE="$1"
  ARG_GIT_HASH=$2
  ARG_SCALA_VERSION=$3

  if [ ! -f "${CONFIG_FILE}" ]
  then
    printErrorUsageAndExit "'${CONFIG_FILE}' doesn't exists or is not a file"
  fi
}

####################
# Build parameters
####################

function stepLoadConfig () {
  printStep "Load config"

# set the working folders
  CURRENT_DIR=$(pwd)
  SCRIPT_DIR=$(cd "$( dirname "$0" )" && pwd)

# load the default parameters

  . "${SCRIPT_DIR}/config/default.conf"

# load the config

  . "${CONFIG_FILE}"

# override the git hash with the one given as argument, if available
  if [ -n "${ARG_GIT_HASH}" ]
  then
    SCALA_GIT_HASH="${ARG_GIT_HASH}"
  fi

# override the Scala version with the one given as argument, if available
  if [ -n "${ARG_SCALA_VERSION}" ]
  then
    SCALA_VERSION="${ARG_SCALA_VERSION}"
  fi

}

################
# Setup logging
################

function stepSetupLogging () {
  printStep "Setup logging"

  if [ -z "${DEBUG}" ]
# enable in file logging only if not in debug mode
  then
    mkdir -p "${BUILD_DIR}"
    # 1 - command standard output
    # 2 - command error output
    # 3 - log file
    # 4 - renamed general standard output
    # 5 - renamed general standard error
    # 6 - fd always pushed to general standard output
    # 7 - extra log file
    case "${LOGGING}" in
      file )
        LOG_FILE="${BUILD_DIR}/log-${TIMESTAMP}.txt"
        > "${LOG_FILE}"
        rm -rf "${BUILD_DIR}/log.txt"
        ln -s "${LOG_FILE}" "${BUILD_DIR}/log.txt"
        exec 3>> "${LOG_FILE}" 4>&1 5>&2 6>&1

        exec 1>&3 2> >(tee -a /dev/fd/3 >&5) 6> >(tee -a /dev/fd/3 >&4)
        ;;
      console)
        ;;
      * )
        missingParameterChoice "LOGGING" "file, console"
        ;;
    esac
    exec 7> "${BUILD_DIR}/log-extra.txt"
    echo "############################################################" >&7
    echo "#### Log file containing usually non-interesting output ####" >&7
    echo "#### look for '>&7' in uber-build.sh                    ####" >&7
    echo "############################################################" >&7
    echo "" >&7
  fi
}

############
# Set flags
############

function stepSetFlags () {
  printStep "Set flags"

# the flags
  RELEASE=false
  DRY_RUN=true
  IDE_BUILD=false
  SCALA_RELEASE=false
  SCALA_VALIDATOR=false
  SCALA_REBUILD=false
  SBT_RELEASE=false
  SBT_REBUILD=false
  SBT_ALWAYS_BUILD=false
  SIGN_ARTIFACTS=false
  WORKSHEET_PLUGIN=false
  PLAY_PLUGIN=false
  SEARCH_PLUGIN=false
  PUBLISH=false
# set in during check configuration 
  USE_SCALA_VERSIONS_PROPERTIES_FILE=false

# Check what to do
  case "${OPERATION}" in
    release )
      RELEASE=true
      DRY_RUN=false
      SIGN_ARTIFACTS=true
      SBT_REBUILD=true
      IDE_BUILD=true
      ;;
    release-dryrun )
      RELEASE=true
      DRY_RUN=true
      SBT_REBUILD=true
      IDE_BUILD=true
      SIGN_ARTIFACTS=true
      ;;
    nightly )
      RELEASE=true
      DRY_RUN=true
      IDE_BUILD=true
      SIGN_ARTIFACTS=false
      ;;
    scala-pr-validator )
      SCALA_VALIDATOR=true
      SBT_REBUILD=true
      IDE_BUILD=true
      ;;
    scala-pr-rebuild )
      SCALA_VALIDATOR=true
      SCALA_REBUILD=true
      SBT_REBUILD=true
      ;;
    scala-local-build )
      SCALA_REBUILD=true
      SBT_REBUILD=true
      IDE_BUILD=true
      ;;
    sbt-nightly )
      RELEASE=true
      DRY_RUN=true
      SBT_REBUILD=true
      SBT_ALWAYS_BUILD=true
      ;;
    * )
      missingParameterChoice "OPERATION" "release, release-dryrun, scala-pr-validator, scala-pr-rebuild, scala-local-build"
      ;;
  esac

  if ${RELEASE}
  then
# Check the plugins to build.
    for PLUGIN in ${PLUGINS}
    do
      case "${PLUGIN}" in
        worksheet )
          WORKSHEET_PLUGIN=true
          ;;
        play )
          PLAY_PLUGIN=true
          ;;
        search )
          SEARCH_PLUGIN=true
          ;;
        * )
          error "Unknown value in PLUGINS. Should be one of: worksheet play search."
      esac
    done

# Check the type of release.
    case "${BUILD_TYPE}" in
      dev | stable )
        if ${DRY_RUN}
        then
          PUBLISH=false
        else
          PUBLISH=true
        fi
        ;;
      * )
        missingParameterChoice "PUBLISH" "dev, stable"
        ;;
    esac
  fi

# Check the cache flag
  case "${WITH_CACHE}" in
    true | false )
      ;;
    * )
      missingParameterChoice "WITH_CACHE" "true, false"
      ;;
  esac
}

#################
# Pre-requisites
#################

function stepCheckPrerequisites () {
  printStep "Check prerequisites"

  JAVA_VERSION=$(java -version 2>&1 | grep 'java version' | awk -F '"' '{print $2;}')
  JAVA_SHORT_VERSION=${JAVA_VERSION:0:3}
  if [ "1.6" != "${JAVA_SHORT_VERSION}" ]
  then
    error "Please run the script with Java 1.6. Current version is: ${JAVA_VERSION}."
  fi

# ant is need to rebuild Scala
  if ${SCALA_REBUILD}
  then
    if [ -n "${ANT}" ]
    then
      if [ -x "${ANT}" ]
      then
        ANT_BIN="${ANT}"
      else
        error "The variable ANT is set, but doesn't point to an executable."
      fi
    else
      if ! checkExecutableOnPath "ant"
      then
        error "To be able to rebuild a special version of Scala, 'ant' should be in the PATH, or the variable ANT should be set"
      else
        ANT_BIN=$(which ant)
      fi
    fi
  fi

# eclipse and keytool are needed to sign the jars
  if ${SIGN_ARTIFACTS}
  then
    if ! checkExecutableOnPath "keytool"
    then
      error "'keytool' is required on PATH to sign the jars"
    fi

    if [ -n "${ECLIPSE}" ]
    then
      if [ -x "${ECLIPSE}" ]
      then
        export ECLIPSE="${ECLIPSE}"
      else
        error "The variable ECLIPSE is set, but doesn't point to an executable."
      fi
    else
      if ! checkExecutableOnPath "eclipse"
      then
        error "to sign the jars, 'eclipse' should be in the PATH, or the variable ECLIPSE should be set."
      else
        export ECLIPSE=$(which eclipse)
      fi
    fi
  fi

# maven is used in most of the phases
  if ! checkExecutableOnPath "mvn"
  then
    error "'mvn' is required on PATH for any build."
  fi
}

######################
# Check configuration
######################

# Checks that all needed parameters are correctly defined.
function stepCheckConfiguration () {
  printStep "Check configuration"

  if echo "${BUILD_DIR}" | grep -c ' '
  then
    error "BUILD_DIR contains space characters. This is not correctly supported by some of the builds. Please set BUILD_DIR to a different location: '${BUILD_DIR}'."
  fi

  checkParameters "SCRIPT_DIR" "BUILD_DIR" "LOCAL_M2_REPO" "P2_CACHE_DIR"

# configure maven here. Needed for some checks
# preserve MAVEN_ARGS coming in from outside
  MAVEN_ARGS=(${MAVEN_ARGS} -e -B -U "-Dmaven.repo.local=${LOCAL_M2_REPO}")

  mkdir -p "${BUILD_DIR}"

  checkParameters "SCALA_VERSION"

  if ${SCALA_REBUILD}
  then
    checkParameters "SCALA_GIT_REPO" "SCALA_GIT_HASH" "SCALA_DIR"
  fi

  checkParameters "SBT_VERSION"

  if ${SBT_REBUILD}
  then
    checkParameters "ZINC_BUILD_DIR"
    if [ -n "${prRepoUrl}" ]
    then
      ZINC_BUILD_ARGS="-DprRepoUrl=${prRepoUrl}"
    fi
  fi

  checkParameters "ECLIPSE_PLATFORM"
  checkParameters "SCALA_IDE_DIR" "SCALA_IDE_GIT_REPO" "SCALA_IDE_GIT_BRANCH" "SCALA_IDE_VERSION_TAG"
  checkParameters "SCALA_REFACTORING_DIR" "SCALA_REFACTORING_GIT_REPO" "SCALA_REFACTORING_GIT_BRANCH"
  checkParameters "SCALARIFORM_DIR" "SCALARIFORM_GIT_REPO" "SCALARIFORM_GIT_BRANCH"

  if ${WORKSHEET_PLUGIN}
  then
    checkParameters "WORKSHEET_PLUGIN_DIR" "WORKSHEET_PLUGIN_GIT_REPO" "WORKSHEET_PLUGIN_GIT_BRANCH" "WORKSHEET_PLUGIN_VERSION_TAG"
  fi

  if ${PLAY_PLUGIN}
  then
    checkParameters "PLAY_PLUGIN_DIR" "PLAY_PLUGIN_GIT_REPO" "PLAY_PLUGIN_GIT_BRANCH" "PLAY_PLUGIN_VERSION_TAG"
  fi

  if ${SEARCH_PLUGIN}
  then
    checkParameters "SEARCH_PLUGIN_DIR" "SEARCH_PLUGIN_GIT_REPO" "SEARCH_PLUGIN_GIT_BRANCH" "SEARCH_PLUGIN_VERSION_TAG"
  fi

  if ${PRODUCT}
  then
    checkParameters "PRODUCT_DIR" "PRODUCT_GIT_REPO" "PRODUCT_GIT_BRANCH" "PRODUCT_VERSION_TAG"
  fi

  if ${SIGN_ARTIFACTS}
  then
    checkParameters "KEYSTORE_DIR" "KEYSTORE_PASS"

# clone the keystore repo. Needed to check if the pass is fine.
    if [ ! -d "${KEYSTORE_DIR}" ]
    then
      checkParameters "KEYSTORE_GIT_REPO"

      fetchGitBranch "${KEYSTORE_DIR}" "${KEYSTORE_GIT_REPO}" master
    fi

    cd "$KEYSTORE_DIR"
    keytool -list -keystore "${KEYSTORE_DIR}/typesafe.keystore" -storepass "${KEYSTORE_PASS}" -alias typesafe

    MAVEN_SIGN_ARGS=("-Djarsigner.storepass=${KEYSTORE_PASS}" -Djarsigner.keypass=${KEYSTORE_PASS} -Djarsigner.keystore=${KEYSTORE_DIR}/typesafe.keystore)
  fi

# set extra variables. There are different ways to reference the Scala and Eclipse versions.
  SCALA_210_OR_LATER=false
  SCALA_211_OR_LATER=false
  case "${SCALA_VERSION}" in
    2.10.* )
      SCALA_PROFILE="scala-2.10.x"
      SCALA_REPO_SUFFIX="210x"
      ECOSYSTEM_SCALA_VERSION="scala210"
      SHORT_SCALA_VERSION="2.10"
      USE_SCALA_VERSIONS_PROPERTIES_FILE=false
      SCALA_210_OR_LATER=true
      ;;
    2.11.* )
      SCALA_PROFILE="scala-2.11.x"
      SCALA_REPO_SUFFIX="211x"
      ECOSYSTEM_SCALA_VERSION="scala211"
      SHORT_SCALA_VERSION="2.11"
      USE_SCALA_VERSIONS_PROPERTIES_FILE=true
      SCALA_210_OR_LATER=true
      SCALA_211_OR_LATER=true
      ;;
    * )
      error "Not supported version of Scala: ${SCALA_VERSION}."
      ;;
  esac

  case "${ECLIPSE_PLATFORM}" in
    indigo )
      ECLIPSE_PROFILE="eclipse-indigo"
      ECOSYSTEM_ECLIPSE_VERSION="e37"
      ;;
    juno )
      ECLIPSE_PROFILE="eclipse-juno"
      ECOSYSTEM_ECLIPSE_VERSION="e38"
      ;;
    * )
      error "Not supported eclipse platform: ${ECLIPSE_PLATFORM}."
      ;;
  esac
}

########
# Scala
########

function stepScala () {
  printStep "Scala"

  if ${SCALA_VALIDATOR}
  then
    # for Scala pr validation, version.properties file is provided.
    SCALA_VERSIONS_PROPERTIES_PATH=${CURRENT_DIR}/versions.properties
  fi

  if ${SCALA_REBUILD}
  then
    fetchGitBranch "${SCALA_DIR}" "${SCALA_GIT_REPO}" "${SCALA_GIT_HASH}" NaN "pr"

    SCALA_UID=$(git rev-parse HEAD)

    FULL_SCALA_VERSION="${SCALA_VERSION}-${SCALA_UID}-SNAPSHOT"
    SCALA_VERSION_SUFFIX="-${SCALA_UID}-SNAPSHOT"

    SCALA_P2_ID=scala/${SCALA_UID}

    if checkAvailability "org.scala-lang" "scala-compiler" "${FULL_SCALA_VERSION}"
    then
      if ${USE_SCALA_VERSIONS_PROPERTIES_FILE}
      then
        if ! checkCache ${SCALA_P2_ID} "true"
        then
          error "Cannot find cached version of versions.properties for ${SCALA_P2_ID}"
        fi
        SCALA_VERSIONS_PROPERTIES_PATH=$(getCacheLocation ${SCALA_P2_ID} "true")/versions.properties
      fi
    else
      info "Building Scala from source"

      cd "${SCALA_DIR}"

      # full clean
      ${ANT_BIN} -Divy.cache.ttl.default=eternal all.clean
      git clean -fxd

      if ${SCALA_211_OR_LATER}
      then
        ${ANT_BIN} \
            publish-local-opt \
            -Darchives.skipxz=true \
            -Dlocal.snapshot.repository="${LOCAL_M2_REPO}" \
            -Dversion.suffix="${SCALA_VERSION_SUFFIX}"
      else
        # before 2.11.0
        ${ANT_BIN} \
            distpack-maven-opt \
            -Darchives.skipxz=true \
            -Dlocal.snapshot.repository="${LOCAL_M2_REPO}" \
            -Dversion.suffix="${SCALA_VERSION_SUFFIX}"

        cd dists/maven/latest
        ${ANT_BIN} \
            -Dlocal.snapshot.repository="${LOCAL_M2_REPO}" \
            -Dmaven.version.suffix="-${SCALA_VERSION_SUFFIX}" \
            deploy.local
      fi

      if ${USE_SCALA_VERSIONS_PROPERTIES_FILE}
      then
        # caching the versions file
        cd "${TMP_DIR}"
        rm -rf *
        mkdir tmp
        cp ${SCALA_DIR}/buildcharacter.properties tmp/versions.properties
        storeCache ${SCALA_P2_ID} tmp "true"
        SCALA_VERSIONS_PROPERTIES_PATH=$(getCacheLocation ${SCALA_P2_ID} "true")/versions.properties
      fi

    fi

  else
    # already existing Scala binaries are used.
    FULL_SCALA_VERSION=${SCALA_VERSION}
  fi

  # Here we attempt to grab the version.properties file from the zinc nightly build rather
  # than scala, as we're not rebuilding scala.
  # TODO - This should pull version.properties for the scala we're building against.
  if ${SBT_ALWAYS_BUILD} && ${USE_SCALA_VERSIONS_PROPERTIES_FILE}
  then
    # If we haven't built scala, this will copy the default properties file.
    if [ ! -f "${SCALA_VERSIONS_PROPERTIES_PATH}" ]
    then
      SCALA_VERSIONS_PROPERTIES_PATH="${ZINC_DIR}/versions.properties"
    fi
  fi

  if ${SBT_REBUILD} && ${USE_SCALA_VERSIONS_PROPERTIES_FILE}
  then
    if [ ! -f "${SCALA_VERSIONS_PROPERTIES_PATH}" ]
    then
      error "unable to find the versions file at '${SCALA_VERSIONS_PROPERTIES_PATH}'"
    fi
  fi

  checkNeeded "org.scala-lang" "scala-compiler" "${FULL_SCALA_VERSION}"

  SCALA_UID=$(osgiVersion "org.scala-lang" "scala-compiler" "${FULL_SCALA_VERSION}")
}

#######
# Zinc
#######

# Constructs a zinc properties file in ZINC_DIR and gives the name of it.
function makeZincPropertiesFile() {
  local filename="current-zinc-build.properties"
  local properties_file="${ZINC_BUILD_DIR}/${filename}"
  info "Writing properties: ${properties_file}"
  echo > "${properties_file}"
  echo "publish-repo=http://private-repo.typesafe.com/typesafe/ide-2.11" >> "${properties_file}"
  echo "sbt-version=${FULL_SBT_VERSION}" >> "${properties_file}"
  info "$(cat "${properties_file}")"
  echo "${filename}"
}

function stepZinc () {
  printStep "Zinc"

  # for Scala pr validation, custom build sbt binaries are used.
  if ${SBT_REBUILD}
  then
    # TODO - if release, no -SNAPSHOT.
    FULL_SBT_VERSION="${SBT_VERSION}-on-${FULL_SCALA_VERSION}-for-IDE-SNAPSHOT"

    # TODO - Only check availability if we're not in sbt nightly mode.
    if ${SBT_ALWAYS_BUILD} || ! checkAvailability "com.typesafe.sbt" "incremental-compiler" "${FULL_SBT_VERSION}"
    then
      info "Building Zinc using dbuild"

      fetchLocalZinc "${ZINC_BUILD_DIR}"

      # TODO - Allow the properties file to be configured or automatically set.
      if [ -z "$ZINC_PROPERTIES_FILE" ]
      then 
        ZINC_PROPERTIES_FILE=$(makeZincPropertiesFile)
      fi

      info "Detected sbt version: ${FULL_SBT_VERSION}"
      # TODO - pushd/popd?
      cd "${ZINC_BUILD_DIR}"

      if $USE_SCALA_VERSIONS_PROPERTIES_FILE
      then
        cp "${SCALA_VERSIONS_PROPERTIES_PATH}" .
      fi
      # TODO - Check to see if we need to download Scala version.properties from 
      #        raw.github.com...

      # TODO - publish repo should be the default one if we're in release mode.
      SBT_VERSION_PROPERTIES_FILE="file:${ZINC_PROPERTIES_FILE}" \
      SCALA_VERSION="${FULL_SCALA_VERSION}" \
        PUBLISH_REPO="file://${LOCAL_M2_REPO}" \
        LOCAL_M2_REPO="${LOCAL_M2_REPO}" \
        bin/dbuild ${ZINC_BUILD_ARGS} sbt-on-${SHORT_SCALA_VERSION}.x

      # TODO - We should either skip or fix this when trying to do an sbt release.
      checkNeeded "com.typesafe.sbt" "incremental-compiler" "${FULL_SBT_VERSION}"
    fi
  else
    # already existing sbt binaries are used.
    FULL_SBT_VERSION="${SBT_VERSION}-on-${FULL_SCALA_VERSION}-for-IDE${ZINC_BUILD_VERSION_SUFFIX}"
    IDE_M2_REPO="http://typesafe.artifactoryonline.com/typesafe/ide-${SHORT_SCALA_VERSION}"
    checkNeeded "com.typesafe.sbt" "incremental-compiler" "${FULL_SBT_VERSION}" "${IDE_M2_REPO}"
  fi

  SBT_UID=${FULL_SBT_VERSION}
}

####################
# Scala Refactoring
####################

function stepScalaRefactoring () {
  printStep "Scala Refactoring"

  fetchGitBranch "${SCALA_REFACTORING_DIR}" "${SCALA_REFACTORING_GIT_REPO}" "${SCALA_REFACTORING_GIT_BRANCH}" NaN

  cd "${SCALA_REFACTORING_DIR}"

  SCALA_REFACTORING_UID=$(git rev-parse HEAD)

  SCALA_REFACTORING_P2_ID=scala-refactoring/${SCALA_REFACTORING_UID}/${SCALA_UID}

  if ! checkCache ${SCALA_REFACTORING_P2_ID}
  then
    info "Building Scala Refactoring"

    mvn "${MAVEN_ARGS[@]}" \
      -P ${SCALA_PROFILE} \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Dgit.hash=${SCALA_REFACTORING_UID} \
      clean \
      verify

    storeCache ${SCALA_REFACTORING_P2_ID} "${SCALA_REFACTORING_DIR}/org.scala-refactoring.update-site/target/site"
  fi
}

##############
# Scalariform
##############

function stepScalariform () {
  printStep "Scalariform"

  fetchGitBranch "${SCALARIFORM_DIR}" "${SCALARIFORM_GIT_REPO}" "${SCALARIFORM_GIT_BRANCH}" NaN

  cd "${SCALARIFORM_DIR}"

  SCALARIFORM_UID=$(git rev-parse HEAD)

  SCALARIFORM_P2_ID=scalariform/${SCALARIFORM_UID}/${SCALA_UID}

  if ! checkCache ${SCALARIFORM_P2_ID}
  then
    info "Building Scalariform"

    mvn "${MAVEN_ARGS[@]}" \
      -P ${SCALA_PROFILE} \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Dgit.hash=${SCALARIFORM_UID} \
      clean \
      verify

    storeCache ${SCALARIFORM_P2_ID} "${SCALARIFORM_DIR}/scalariform.update/target/site"
  fi
}

############
# Scala IDE
############

function stepScalaIDE () {
  printStep "Scala IDE"

  fetchGitBranch "${SCALA_IDE_DIR}" "${SCALA_IDE_GIT_REPO}" "${SCALA_IDE_GIT_BRANCH}" NaN

  cd "${SCALA_IDE_DIR}"

  SCALA_IDE_UID="$(git rev-parse HEAD)${SCALA_IDE_VERSION_TAG}"

  if $SIGN_ARTIFACTS
  then
    SCALA_IDE_P2_ID=scala-ide/${SCALA_IDE_UID}-S/${SCALA_UID}/${SBT_UID}/${SCALA_REFACTORING_UID}/${SCALARIFORM_UID}
  else
    SCALA_IDE_P2_ID=scala-ide/${SCALA_IDE_UID}/${SCALA_UID}/${SBT_UID}/${SCALA_REFACTORING_UID}/${SCALARIFORM_UID}
  fi

  if ! checkCache ${SCALA_IDE_P2_ID}
  then
    info "Building Scala IDE"

    if $RELEASE
    then
      # TODO: remove the condition. The only reason it is here is because the tool
      # is not able to correctly read long Scala version string of MANIFEST.MF :(
      export SET_VERSIONS=true
    fi

    ./build-all.sh \
      "${MAVEN_ARGS[@]}" \
      -P${ECLIPSE_PROFILE} \
      -P${SCALA_PROFILE} \
      -Psbt-new \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Dversion.tag=${SCALA_IDE_VERSION_TAG} \
      -Dsbt.version=${SBT_VERSION} \
      -Dsbt.ide.version=${FULL_SBT_VERSION} \
      -Drepo.scala-refactoring=$(getCacheURL ${SCALA_REFACTORING_P2_ID}) \
      -Drepo.scalariform=$(getCacheURL ${SCALARIFORM_P2_ID}) \
      clean \
      install

    cd "${SCALA_IDE_DIR}/org.scala-ide.sdt.update-site"

    if $SIGN_ARTIFACTS
    then
      ./plugin-signing.sh "${KEYSTORE_DIR}/typesafe.keystore" typesafe ${KEYSTORE_PASS} ${KEYSTORE_PASS}
    fi

    storeCache ${SCALA_IDE_P2_ID} "${SCALA_IDE_DIR}/org.scala-ide.sdt.update-site/target/site"
  fi

  # set the code name according to the version of Scala IDE which is used

  SCALA_IDE_VERSION=$(osgiVersionFromJar "$(getCacheLocation ${SCALA_IDE_P2_ID})/plugins/org.scala-ide.sdt.core_*")

  case "${SCALA_IDE_VERSION}" in
    3.* )
      ECOSYSTEM_SCALA_IDE_CODE_NAME="helium"
      ;;
    4.* )
      ECOSYSTEM_SCALA_IDE_CODE_NAME="lithium"
      ;;
    * )
      error "Not supported version of Scala IDE: ${SCALA_IDE_VERSION}."
      ;;
  esac

}

##################
# Plugin
##################

# $1 - pretty name
# $2 - logic name
# $3 - var prefix
# $4 - repo dir
# $5 - git repo
# $6 - git branch
# $7 - version tag
function stepPlugin () {
  printStep "$1"

  fetchGitBranch "$4" "$5" "$6" NaN

  cd "$4"

  P_UID=$(git rev-parse HEAD)

  eval $3_UID=${P_UID}

  P2_ID=$2/${P_UID}/${SCALA_IDE_UID}/${SCALA_UID}

  eval $3_P2_ID=${P2_ID}

  if ! checkCache ${P2_ID}
  then
    info "Building $1"


    mvn ${MAVEN_ARGS[@]} \
      -Dtycho.localArtifacts=ignore \
      -Pset-versions \
      -P${ECLIPSE_PROFILE} \
      -P${SCALA_PROFILE} \
      -Drepo.scala-ide=$(getCacheURL ${SCALA_IDE_P2_ID}) \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Dtycho.style=maven \
      --non-recursive \
      exec:java

    mvn ${MAVEN_ARGS[@]} \
      -Dtycho.localArtifacts=ignore \
      -P${ECLIPSE_PROFILE} \
      -P${SCALA_PROFILE} \
      -Drepo.scala-ide=$(getCacheURL ${SCALA_IDE_P2_ID}) \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Dversion.tag=$7 \
      ${MAVEN_SIGN_ARGS[@]} \
      dependency:tree \
      clean \
      verify

    storeCache ${P2_ID} *update-site/target/site
  fi
}

###########
# Product
###########

function stepProduct () {
  printStep "Product"

  fetchGitBranch "${PRODUCT_DIR}" "${PRODUCT_GIT_REPO}" "${PRODUCT_GIT_BRANCH}" NaN

  cd "${PRODUCT_DIR}"

  PRODUCT_UID=$(git rev-parse HEAD)

  PRODUCT_P2_ID=product/${PRODUCT_UID}/${SCALA_IDE_UID}/${SCALA_UID}

  if ${WORKSHEET_PLUGIN}
  then
    PRODUCT_P2_ID=${PRODUCT_P2_ID}/W-${WORKSHEET_PLUGIN_UID}
  fi

  if ${PLAY_PLUGIN}
  then
    PRODUCT_P2_ID=${PRODUCT_P2_ID}/P-${PLAY_PLUGIN_UID}
  fi

  if ${SEARCH_PLUGIN}
  then
    PRODUCT_P2_ID=${PRODUCT_P2_ID}/S-${SEARCH_PLUGIN_UID}
  fi

  if ! checkCache ${PRODUCT_P2_ID}
  then
    info "Generate merged update site for Product build"

    rm -rf "${TMP_DIR}"/*
    PRODUCT_BUILD_P2_REPO="${TMP_DIR}/p2-repo-for-product"

    cp -r "$(getCacheLocation ${SCALA_IDE_P2_ID})" "${PRODUCT_BUILD_P2_REPO}"

    if ${WORKSHEET_PLUGIN}
    then
      mergeP2Repo "$(getCacheURL ${WORKSHEET_PLUGIN_P2_ID})" "${PRODUCT_BUILD_P2_REPO}"
    fi

    if ${PLAY_PLUGIN}
    then
      mergeP2Repo "$(getCacheLocation ${PLAY_PLUGIN_P2_ID})" "${PRODUCT_BUILD_P2_REPO}"
    fi

    if ${SEARCH_PLUGIN}
    then
      mergeP2Repo "$(getCacheLocation ${SEARCH_PLUGIN_P2_ID})" "${PRODUCT_BUILD_P2_REPO}"
    fi

    info "Build Product"

    cd "${PRODUCT_DIR}"

    REPO_PATH_ECLIPSE="/sdk/${ECOSYSTEM_SCALA_IDE_CODE_NAME}/${ECOSYSTEM_ECLIPSE_VERSION}"
    REPO_PATH_SCALA="/${ECOSYSTEM_SCALA_VERSION}/${BUILD_TYPE}/site"

    mvn ${MAVEN_ARGS[@]}\
      -Dtycho.localArtifacts=ignore \
      --non-recursive \
      -Pconfigure \
      -P${SCALA_PROFILE} \
      -P${ECLIPSE_PLATFORM} \
      -Dversion.tag=${PRODUCT_VERSION_TAG} \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Drepopath.platform="${REPO_PATH_ECLIPSE}" \
      -Drepopath.scala-ide.ecosystem="${REPO_PATH_SCALA}" \
      process-resources

    mvn ${MAVEN_ARGS[@]} \
      -Dtycho.localArtifacts=ignore  \
      -P${SCALA_PROFILE} \
      -P${ECLIPSE_PLATFORM} \
      -Dversion.tag=${PRODUCT_VERSION_TAG} \
      -Dscala.version=${FULL_SCALA_VERSION} \
      -Drepopath.scala-ide.ecosystem="" \
      -Drepopath.platform="" \
      -Drepo.scala-ide.root="file://${PRODUCT_BUILD_P2_REPO}" \
      ${MAVEN_SIGN_ARGS[@]} \
      clean \
      package

    storeCache ${PRODUCT_P2_ID} "${PRODUCT_DIR}/org.scala-ide.product/target/repository"
  fi
}

##########
# Publish
##########

# $1 - pretty name
# $2 - logic name
# $3 - var prefix
function publishPlugin () {
  info "uploading $1"

  cd "${TMP_DIR}"
  rm -rf *
  P2_ID_VAR_NAME=$3_P2_ID
  cp -r "$(getCacheLocation ${!P2_ID_VAR_NAME})" site
  ZIP_NAME=site-${TIMESTAMP}.zip
  zip -rq ${ZIP_NAME} site

  PLUGIN_UPLOAD_DIR="scala-ide.dreamhosters.com/plugins/$2/releases/${ECOSYSTEM_ECLIPSE_VERSION}/${SHORT_SCALA_VERSION}.x"
  scp ${ZIP_NAME} ${SSH_ACCOUNT}:${PLUGIN_UPLOAD_DIR}
  ssh ${SSH_ACCOUNT} "cd ${PLUGIN_UPLOAD_DIR}; rm -rf site; unzip -q ${ZIP_NAME}"

}

function stepPublish () {
  printStep "Publish"

  SSH_ACCOUNT="scalaide@scala-ide.dreamhosters.com"

  info "generate base ecosystem repo"

  rm -rf "${TMP_DIR}"/*
  ECOSYSTEM_P2_REPO="${TMP_DIR}/p2-repo-for-ecosystem"
  mkdir -p "${ECOSYSTEM_P2_REPO}"

  cp -r "$(getCacheLocation ${SCALA_IDE_P2_ID})" "${ECOSYSTEM_P2_REPO}/base"

  if ${PRODUCT}
  then
    mergeP2Repo "$(getCacheLocation ${PRODUCT_P2_ID})" "${ECOSYSTEM_P2_REPO}/base"
  fi

  info "uploading base ecosystem"

  cd "${ECOSYSTEM_P2_REPO}"

  ZIP_NAME=base-${TIMESTAMP}.zip
  zip -qr ${ZIP_NAME} base

  ECOSYSTEM_UPLOAD_DIR="scala-ide.dreamhosters.com/sdk/next/${ECOSYSTEM_SCALA_IDE_CODE_NAME}/${ECOSYSTEM_ECLIPSE_VERSION}/${ECOSYSTEM_SCALA_VERSION}/${BUILD_TYPE}"
  scp ${ZIP_NAME} ${SSH_ACCOUNT}:${ECOSYSTEM_UPLOAD_DIR}
  ssh ${SSH_ACCOUNT} "cd ${ECOSYSTEM_UPLOAD_DIR}; rm -rf base; unzip -q ${ZIP_NAME}"

  if ${WORKSHEET_PLUGIN}
  then
    publishPlugin "Worksheet" "worksheet" "WORKSHEET_PLUGIN"
  fi

  if ${PLAY_PLUGIN}
  then
    publishPlugin "Play" "scala-ide-play2" "PLAY_PLUGIN"
  fi

  if ${SEARCH_PLUGIN}
  then
    publishPlugin "Search" "scala-search" "SEARCH_PLUGIN"
  fi

}

##############
##############
# MAIN SCRIPT
##############
##############

stepCheckArguments $*

stepLoadConfig
stepSetupLogging
stepSetFlags

stepCheckPrerequisites
stepCheckConfiguration

stepScala

stepZinc

if ${IDE_BUILD}
then 
  stepScalaRefactoring
  stepScalariform

  stepScalaIDE
fi

if ${WORKSHEET_PLUGIN}
then
  stepPlugin "Scala Worksheet" "worksheet" "WORKSHEET_PLUGIN" "${WORKSHEET_PLUGIN_DIR}" "${WORKSHEET_PLUGIN_GIT_REPO}" "${WORKSHEET_PLUGIN_GIT_BRANCH}" "${WORKSHEET_PLUGIN_VERSION_TAG}"
fi

if ${PLAY_PLUGIN}
then
  stepPlugin "Play" "play" "PLAY_PLUGIN" "${PLAY_PLUGIN_DIR}" "${PLAY_PLUGIN_GIT_REPO}" "${PLAY_PLUGIN_GIT_BRANCH}" "${PLAY_PLUGIN_VERSION_TAG}"
fi

if ${SEARCH_PLUGIN}
then
  stepPlugin "Scala Search" "search" "SEARCH_PLUGIN" "${SEARCH_PLUGIN_DIR}" "${SEARCH_PLUGIN_GIT_REPO}" "${SEARCH_PLUGIN_GIT_BRANCH}" "${SEARCH_PLUGIN_VERSION_TAG}"
fi

if ${PRODUCT}
then
  stepProduct
fi

if ${PUBLISH}
then
  stepPublish
fi

######
# END
######

printStep "Build succesful"

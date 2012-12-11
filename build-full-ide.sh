#!/bin/bash -e

# Warning: This script has been tested wit Mac OSX only.

# Usage Examples
# Unsigned Build: SCALA_VERSION=2.11.0-SNAPSHOT SCALARIFORM_GIT_REPO=git://github.com/mdr/scalariform.git SCALA_REFACTORING_GIT_REPO=git://git.assembla.com/scala-refactoring.git SCALA_IDE_BRANCH=master SCALARIFORM_BRANCH=master SCALA_REFACTORING_BRANCH=master ./build-full-ide.sh
# Signed Build: VERSION_TAG=m3 SCALA_VERSION=2.10.0 SCALARIFORM_GIT_REPO=git://github.com/mdr/scalariform.git SCALA_REFACTORING_GIT_REPO=git://git.assembla.com/scala-refactoring.git SCALA_IDE_BRANCH=master SCALARIFORM_BRANCH=master SCALA_REFACTORING_BRANCH=master SIGN_BUILD=true KEYSTORE_GIT_REPO=<profive git url to keystore> KEYSTORE_PASS=<provide keystore password> ./build-full-ide.sh
#
# If you wish to skip tests when building scala-refactoring, you can do so by setting the value of REFACTORING_MAVEN_ARGS=-Dmaven.test.skip=true, and pass it to the script.

export MAVEN_OPTS="-Xmx1500m"

###############################################################
#               Overridable Environment Methods               #
###############################################################

: ${DEBUG:=true}                  # Prints some additional information 

: ${ECLIPSE:=eclipse}             # Eclipse executable
: ${SBT:=sbt}                     # Sbt executable
: ${MAVEN=mvn}                    # Mvn executable
: ${GIT=git}                      # Git executable
: ${KEYTOOL=keytool}              # Needed for signing the JARs

: ${SIGN_BUILD:=false}:           # Should the IDE and its dependencies be signed. If you enable this, make sure to also provide a value for KEYSTORE_GIT_REPO and KEYSTORE_PASS, or the script will ask the user for these inputs
: ${KEYSTORE_GIT_REPO:=}          # URL to the Keystore Git repository
: ${KEYSTORE_PASS=:=}             # Password for the Keystore

: ${VERSION_TAG:=}                # Version suffix to be appended to the IDE version number. When building a signed IDE, make sure to provide a value for the VERSION_TAG

: ${SCALA_VERSION:=}              # Scala version to use to build the IDE and all its dependencies         
: ${SCALA_IDE_BRANCH:=}           # Scala IDE branch/tag to build
: ${SCALARIFORM_GIT_REPO:=}       # Git repository to use to build scalariform
: ${SCALARIFORM_BRANCH:=}         # Scalariform branch/tag to build
: ${SCALA_REFACTORING_GIT_REPO:=} # Git repository to use to build scala-refactoring
: ${SCALA_REFACTORING_BRANCH:=}   # Scala-refactoring branch/tag to build
: ${REFACTORING_MAVEN_ARGS:=""}   # Pass some maven argument to the scala-refactoring build, e.g. -Dmaven.test.skip=true

###############################################################
#                          Global Methods                     #
###############################################################

function abort()
{
  MSG=$1
  if [ "$MSG" ]
  then 
    echo >&2 "$MSG"
  fi
  echo "Abort."
  exit 1
}

function print_step()
{
	cat <<EOF

==================================================================
                     Building $1
==================================================================

EOF
}

# Check that the VERSION_TspAG was provided. If not, abort.
function assert_version_tag_not_empty()
{
if [[ -z "$VERSION_TAG" ]]
  then
    abort "VERSION_TAG cannot be empty."
  fi
}

function debug()
{
  MSG=$1
  if [[ $DEBUG ]]
  then
    echo $MSG
  fi 
}

###############################################################
#                       SCALA VERSION                         #
###############################################################

if [[ -z "$SCALA_VERSION" ]]
then
  abort "SCALA_VERSION cannot be empty"
fi


case $SCALA_VERSION in

	2.9* )
		maven_toolchain_profile=sbt-2.9
		scala_profile_ide=scala-2.9.x
		REPO_SUFFIX=29x
		;;

	2.10.0-SNAPSHOT )
		maven_toolchain_profile=sbt-2.10
		scala_profile_ide=scala-2.10.x
		REPO_SUFFIX=210x
		;;

	2.10.0-M* )
		maven_toolchain_profile=sbt-2.10
		scala_profile_ide="scala-2.10.x"
		REPO_SUFFIX=210x
		;;

	2.10.0-RC* )
		maven_toolchain_profile=sbt-2.10
		scala_profile_ide="scala-2.10.x"
		REPO_SUFFIX=210x
		;;

    2.11.0-SNAPSHOT )
		maven_toolchain_profile=sbt-2.11
		scala_profile_ide=scala-2.11.x
		REPO_SUFFIX=211x
		;;

	*)
		abort "Unknown scala version ${SCALA_VERSION}"
esac


###############################################################
#      Checks that the needed executables are available       #
###############################################################

function validate_java()
{
	(java -version 2>&1 | grep \"1.6.*\")
	if [[ $? -ne 0 ]]; then
		java -version
		abort "Invalid Java version detected. Only java 1.6 is supported due to changes in jarsigner in 1.7"
	fi
}

# If passed executable's name is available return 0 (true), else return 1 (false).
# @param $1 The executable's name
function executable_in_path() 
{
  CMD=$1
  RES=$(which $CMD)
  if [ "$RES" ]
  then
    return 0
  else
    return 1
  fi
}

# Exit with code failure 1 if the executable is not available.
# @param $1 The executable's name
function assert_executable_in_path() 
{
  CMD=$1
  (executable_in_path $CMD) || {
    abort "$CMD is not available."
  }
}

# Checks that all executables needed by this script are available
validate_java
assert_executable_in_path ${MAVEN} # Check that maven executable is available
assert_executable_in_path ${ECLIPSE} # Check that eclipse executable is available
assert_executable_in_path ${GIT} # Check that git executable is available
assert_executable_in_path ${SBT} # Check that sbt executable is available

############## Helpers #######################

SCALAIDE_DIR=scala-ide
SCALARIFORM_DIR=scalariform
SCALA_REFACTORING_DIR=scala-refactoring
SBINARY_DIR=sbinary
SBT_DIR=xsbt

BASE_DIR=`pwd`

LOCAL_REPO=`pwd`/m2repo
SOURCE=${BASE_DIR}/p2-repo
PLUGINS=${SOURCE}/plugins
REPO_NAME=scala-eclipse-toolchain-osgi-${REPO_SUFFIX}
REPO=file:${SOURCE}/${REPO_NAME}

function build_sbinary()
{
	# build sbinary
	print_step "sbinary"

	cd ${SBINARY_DIR}

	# maven style for the toolchain build
	$SBT "reboot full" clean "show scala-instance" "set every crossScalaVersions := Seq(\"${SCALA_VERSION}\")" \
	 'set every publishMavenStyle := true' \
	 'set every resolvers := Seq("Sonatype OSS Snapshots" at "https://oss.sonatype.org/content/repositories/snapshots")' \
	 'set every publishTo := Some(Resolver.file("Local Maven",  new File(Path.userHome.absolutePath+"/.m2/repository")))' \
	 'set every crossPaths := true' \
	 +core/publish \
	 +core/publish-local # ivy style for xsbt


	cd ${BASE_DIR}
}

function build_xsbt()
{
	# build sbt
	print_step "xsbt"

	cd ${SBT_DIR}
	$SBT "reboot full" clean \
	"set every crossScalaVersions := Seq(\"${SCALA_VERSION}\")" \
	'set every publishMavenStyle := true' \
	'set every resolvers := Seq("Sonatype OSS Snapshots" at "https://oss.sonatype.org/content/repositories/snapshots")' \
	'set artifact in (compileInterfaceSub, packageBin) := Artifact("compiler-interface")' \
    'set every publishTo := Some(Resolver.file("Local Maven",  new File(Path.userHome.absolutePath+"/.m2/repository")))' \
	'set every crossPaths := true' \
	+classpath/publish +logging/publish +io/publish +control/publish +classfile/publish \
	+process/publish +relation/publish +interface/publish +persist/publish +api/publish \
	 +compiler-integration/publish +incremental-compiler/publish +compile/publish +compiler-interface/publish

	cd ${BASE_DIR}
}

function build_toolchain()
{
	# build toolchain
	print_step "build-toolchain"

	MAVEN_ARGS="-P ${scala_profile_ide} clean install"
	rm -rf ${SOURCE}/*

	cd ${SCALAIDE_DIR}
	mvn -Dscala.version=${SCALA_VERSION} ${MAVEN_ARGS}

	cd org.scala-ide.build-toolchain
	mvn -Dscala.version=${SCALA_VERSION} ${MAVEN_ARGS}

	cd ../org.scala-ide.toolchain.update-site
	mvn -Dscala.version=${SCALA_VERSION} ${MAVEN_ARGS}

	# make toolchain repo

	rm -Rf ${SOURCE}/plugins
	mkdir -p ${PLUGINS}

	cp org.scala-ide.scala.update-site/target/site/plugins/*.jar ${PLUGINS}
	
	print_step "p2 toolchain repo"

	$ECLIPSE \
	-debug \
	-consolelog \
	-nosplash \
	-verbose \
	-application org.eclipse.equinox.p2.publisher.FeaturesAndBundlesPublisher \
	-metadataRepository ${REPO} \
	-artifactRepository ${REPO} \
	-source ${SOURCE} \
	-compress \
	-publishArtifacts

	cd ${BASE_DIR}
}

function build_refactoring()
{
	# build scala-refactoring
	print_step "scala-refactoring"

	cd ${SCALA_REFACTORING_DIR}
	GIT_HASH="`git log -1 --pretty=format:"%h"`"
	${MAVEN} -P ${scala_profile_ide} -Dscala.version=${SCALA_VERSION} $REFACTORING_MAVEN_ARGS -Drepo.scala-ide="file:/${SOURCE}" -Dgit.hash=${GIT_HASH} clean package

	cd $BASE_DIR

	# make scala-refactoring repo

	REPO_NAME=scala-refactoring-${REPO_SUFFIX}
	REPO=file:${SOURCE}/${REPO_NAME}

	rm -Rf ${SOURCE}/plugins
	cp -R scala-refactoring/org.scala-refactoring.update-site/target/site/plugins ${SOURCE}/

	$ECLIPSE \
	-debug \
	-consolelog \
	-nosplash \
	-verbose \
	-application org.eclipse.equinox.p2.publisher.FeaturesAndBundlesPublisher \
	-metadataRepository ${REPO} \
	-artifactRepository ${REPO} \
	-source ${SOURCE} \
	-compress \
	-publishArtifacts

	cd ${BASE_DIR}
}

function build_scalariform()
{
	# build scalariform
	print_step "scalariform"
	cd ${SCALARIFORM_DIR}

	GIT_HASH="`git log -1 --pretty=format:"%h"`"
	
	${MAVEN} -P ${scala_profile_ide} -Dscala.version=${SCALA_VERSION} -Drepo.scala-ide="file:/${SOURCE}" -Dgit.hash=${GIT_HASH} clean package

	rm -rf ${SOURCE}/scalariform-${REPO_SUFFIX}
	mkdir ${SOURCE}/scalariform-${REPO_SUFFIX}
	cp -r scalariform.update/target/site/* ${SOURCE}/scalariform-${REPO_SUFFIX}/

	cd ${BASE_DIR}
}

function build_ide()
{
	print_step "Building the IDE"
	cd ${SCALAIDE_DIR}
    if $SIGN_BUILD
    then
      export SET_VERSIONS="true"
    fi
	./build-all.sh -P ${scala_profile_ide} -Dscala.version=${SCALA_VERSION} -Drepo.scala-ide.root="file:${SOURCE}" -Dversion.tag=${VERSION_TAG} clean install
	cd ${BASE_DIR}
}

function sign_plugins()
{
    print_step "Signing"
    
	cd ${SCALAIDE_DIR}/org.scala-ide.sdt.update-site
	ECLIPSE_ALIAS=$ECLIPSE
	ECLIPSE=$(which $ECLIPSE_ALIAS) ./plugin-signing.sh ${BASE_DIR}/${KEYSTORE_FOLDER}/typesafe.keystore typesafe ${KEYSTORE_PASS} ${KEYSTORE_PASS}
    cd ${BASE_DIR}
}


###############################################################
#                          GIT Helpers                        #
###############################################################

function clone_git_repo_if_needed()
{
  GITHUB_REPO=$1
  FOLDER_DIR=$2

  if [ ! -d "$FOLDER_DIR" ]
  then
      $GIT clone $GITHUB_REPO $FOLDER_DIR
  else
    cd $FOLDER_DIR
    git remote rm origin 
    git remote add origin $GITHUB_REPO
    git fetch $NAME_REMOTE > /dev/null # Swallow output
    cd $BASE_DIR
  fi
}

function exist_branch_in_repo()
{
  BRANCH=$1
  GIT_REPO=$2
  
  ESCAPED_BRANCH=`echo $BRANCH | sed -e 's/[\/&]/\\\&/g'`
  # Checks if it exists a remote branch that matches ESCAPED_BRANCH
  REMOTES=`$GIT ls-remote $GIT_REPO | awk '/'$ESCAPED_BRANCH'/ {print $2}'`
  if [[ "$REMOTES" ]]
  then
    return 0
  else
    return 1
  fi 
}

function exist_branch_in_repo_verbose()
{
  BRANCH=$1
  GIT_REPO=$2
  
  debug "Checking if branch $BRANCH exists in git repo ${GIT_REPO}..."
  if exist_branch_in_repo $BRANCH $GIT_REPO
  then
    debug "Branch found!"
    return 0
  else
    debug "Branch NOT found!"
    return 1
  fi
}

function assert_branch_in_repo_verbose()
{
  BRANCH=$1
  GIT_REPO=$2
  (exist_branch_in_repo_verbose $BRANCH $GIT_REPO) || abort
}

# Check that there are no uncommitted changes in $1
function validate()
{
  IGNORED_FILES_REGEX='\.classpath'
  (
    cd $1
    $GIT diff --name-only | grep -v ${IGNORED_FILES_REGEX} > /dev/null
  )
  RET=$?
  if [[ $RET -eq 0 ]]; then
  	echo -e "\nYou have uncommitted changes in $1:\n"
  	(cd $1 && git diff --name-status | grep -v ${IGNORED_FILES_REGEX})
  	abort
  fi 
}

function checkout_git_repo()
{
  GITHUB_REPO=$1
  FOLDER_DIR=$2
  BRANCH=$3

  cd $FOLDER_DIR
	
  REFS=`$GIT show-ref $BRANCH | awk '{split($0,a," "); print a[2]}' | awk '{split($0,a,"/"); print a[2]}'`
  if [[ "$REFS" = "tags" ]]
  then
    debug "In $FOLDER_DIR, checking out tag $BRANCH"
    $GIT checkout -q $BRANCH
  else
    FULL_BRANCH_NAME=origin/$BRANCH
    debug "In $FOLDER_DIR, checking out branch $FULL_BRANCH_NAME"
    $GIT checkout -q $FULL_BRANCH_NAME
  fi
  cd $BASE_DIR
  validate ${FOLDER_DIR}
}


###############################################################
#                          SIGNING                            #
###############################################################

KEYSTORE_FOLDER="typesafe-keystore"

if $SIGN_BUILD
then
  assert_executable_in_path ${KEYTOOL} # Check that keytool executable is available
  assert_version_tag_not_empty

  # Check if the keystore folder has been already pulled
  if [ ! -d "$KEYSTORE_FOLDER" ]
  then
    if [[ -z "$KEYSTORE_GIT_REPO" ]]
    then
      read -p "Please, provide the URL to the keystore git repository: " git_repo; echo
      KEYSTORE_GIT_REPO="$git_repo"
    fi
    clone_git_repo_if_needed $KEYSTORE_GIT_REPO $KEYSTORE_FOLDER
  fi
  
  # Password for using the keystore
  if [[ -z "$KEYSTORE_PASS" ]]
  then
    read -s -p "Please, provide the password for the keystore: " passw; echo
    KEYSTORE_PASS=$passw
  fi
  # Check that the password to the keystore is correct (or fail fast)
  $KEYTOOL -list -keystore ${BASE_DIR}/${KEYSTORE_FOLDER}/typesafe.keystore -storepass ${KEYSTORE_PASS} -alias typesafe
else
  echo "The IDE build will NOT be signed."
  if [[ -z $VERSION_TAG ]]; then
	VERSION_TAG=local
  fi
fi

###############################################################
#                            BUILD                            #
###############################################################

# At this point the version tag cannot be empty. Why? Because if the IDE build won't be signed, 
# then VERSION_TAG is set to `local`. Otherwise, if the IDE build will be signed, then the 
# VERSION_TAG must be set or the build will stop immediately.
# This is really just a sanity check.
assert_version_tag_not_empty

# These are currently non-overridable defaults
SBINARY_GIT_REPO=git://github.com/scala-ide/sbinary.git
SBT_GIT_REPO=git://github.com/harrah/xsbt.git
SCALA_IDE_GIT_REPO=git://github.com/scala-ide/scala-ide.git

if [[ ( -z "$SCALARIFORM_GIT_REPO" ) && ( -z "$SCALA_REFACTORING_GIT_REPO" ) ]]
then
  read -n1 -p "Do you want to build the IDE dependencies using the original repositories, or the GitHub forks under the scala-ide organization? (o/f): " original_or_fork; echo;
  case "$original_or_fork" in
	o ) 
		debug "Using the original repositories"
		SCALARIFORM_GIT_REPO=git://github.com/mdr/scalariform.git
		SCALA_REFACTORING_GIT_REPO=git://git.assembla.com/scala-refactoring.git
		;;
		
	f ) 
		debug "Using the GitHub forks for $SCALARIFORM_DIR and $SCALA_REFACTORING_DIR"
		SCALARIFORM_FORK_GIT_REPO=git://github.com/scala-ide/scalariform.git
		SCALA_REFACTORING_FORK_GIT_REPO=git://github.com/scala-ide/scala-refactoring.git
		SCALARIFORM_GIT_REPO=$SCALARIFORM_FORK_GIT_REPO
		SCALA_REFACTORING_GIT_REPO=$SCALA_REFACTORING_FORK_GIT_REPO
		;;
		
	*)
		abort "Unexpected input. Found '$original_or_fork', expected 'o', for the original repositories, or 'f' for the forks."
		;;
  esac
fi

clone_git_repo_if_needed ${SBINARY_GIT_REPO} ${SBINARY_DIR}
clone_git_repo_if_needed ${SBT_GIT_REPO} ${SBT_DIR}
clone_git_repo_if_needed ${SCALA_IDE_GIT_REPO} ${SCALAIDE_DIR}
clone_git_repo_if_needed ${SCALARIFORM_GIT_REPO} ${SCALARIFORM_DIR}
clone_git_repo_if_needed ${SCALA_REFACTORING_GIT_REPO} ${SCALA_REFACTORING_DIR}


# Selecting branches/tags to build

SBT_BRANCH=0.13
SBINARY_BRANCH=master

if [[ ( -z "$SCALA_IDE_BRANCH" ) ]]
then
  read -p "What branch/tag should I use for building the ${SCALAIDE_DIR}: " scala_ide_branch;
  SCALA_IDE_BRANCH=$scala_ide_branch
  assert_branch_in_repo_verbose $SCALA_IDE_BRANCH $SCALA_IDE_GIT_REPO
fi

if [[ ( -z "$SCALARIFORM_BRANCH" ) ]]
then
  read -p "What branch/tag should I use for building ${SCALARIFORM_DIR}: " scalariform_branch;
  SCALARIFORM_BRANCH=$scalariform_branch
  assert_branch_in_repo_verbose $SCALARIFORM_BRANCH $SCALARIFORM_GIT_REPO
fi

if [[ ( -z "$SCALA_REFACTORING_BRANCH" ) ]]
then
  read -p "What branch/tag should I use for building ${SCALA_REFACTORING_DIR}: " scala_refactoring_branch;
  SCALA_REFACTORING_BRANCH=$scala_refactoring_branch
  assert_branch_in_repo_verbose $SCALA_REFACTORING_BRANCH $SCALA_REFACTORING_GIT_REPO
fi

echo -e "Build configuration:"
echo -e "-----------------------\n"
echo -e "Sbt: \t\t\t${SBT}"
echo -e "Scala version: \t\t${SCALA_VERSION}"
echo -e "Version tag: \t\t${VERSION_TAG}"
echo -e "P2 repo: \t\t${SOURCE}"
echo -e "Toolchain repo: \t${REPO}"

echo -e "SBinary:\t\t${SBINARY_DIR}, branch: ${SBINARY_BRANCH}, repo: ${SBINARY_GIT_REPO}"
echo -e "Sbt:\t\t\t${SBT_DIR}, branch: ${SBT_BRANCH}, repo: ${SBT_GIT_REPO}"
echo -e "Scalariform:\t\t${SCALARIFORM_DIR}, branch: ${scalariform_branch}, repo: ${SCALARIFORM_GIT_REPO}"
echo -e "Scala-refactoring:\t${SCALA_REFACTORING_DIR}, branch: ${scala_refactoring_branch}, repo: ${SCALA_REFACTORING_GIT_REPO}"
echo -e "Scala IDE:  \t\t${SCALAIDE_DIR}, branch: ${scala_ide_branch}, repo: ${SCALA_IDE_GIT_REPO}"
echo -e "-----------------------\n"


checkout_git_repo ${SBINARY_GIT_REPO} ${SBINARY_DIR} ${SBINARY_BRANCH}
checkout_git_repo ${SBT_GIT_REPO} ${SBT_DIR} ${SBT_BRANCH}
checkout_git_repo ${SCALA_IDE_GIT_REPO} ${SCALAIDE_DIR} ${SCALA_IDE_BRANCH}
checkout_git_repo ${SCALARIFORM_GIT_REPO} ${SCALARIFORM_DIR} ${SCALARIFORM_BRANCH}
checkout_git_repo ${SCALA_REFACTORING_GIT_REPO} ${SCALA_REFACTORING_DIR} ${SCALA_REFACTORING_BRANCH}

build_sbinary
build_xsbt
build_toolchain
build_refactoring
build_scalariform
build_ide

if $SIGN_BUILD
then
  sign_plugins
fi
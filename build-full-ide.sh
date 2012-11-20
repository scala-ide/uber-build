#!/bin/bash -e

# Warning: This script has been tested wit Mac OSX only.


###############################################################
#                       SCALA VERSION                         #
###############################################################

if [[ -z "$SCALA_VERSION" ]]
then
  echo "SCALA_VERSION cannot be empty"
  aborting
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
		echo "Unknown scala version ${SCALA_VERSION}"
		exit 1
esac

###############################################################
#                          Global Methods                     #
###############################################################

function aborting()
{
  echo "Aborting."
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

# Check that the VERSION_TAG was provided. If not, abort.
function assert_version_tag_not_empty()
{
if [[ -z "$VERSION_TAG" ]]
  then
    echo "VERSION_TAG cannot be empty."
    aborting
  fi
}

###############################################################
#                           Global Variables                  #
###############################################################

: ${ECLIPSE:=eclipse} # ECLIPSE will take the declared value if not overridden
: ${SBT:=sbt}         # SBT will take the declared value if not overridden
MAVEN=mvn
: ${REFACTORING_MAVEN_ARGS:=""} # Pass some maven argument to the build, e.g. -Dmaven.test.skip=true
export MAVEN_OPTS="-Xmx1500m"
GIT=git
KEYTOOL=keytool       # Needed for signing the JARs

base_dir=`pwd`

###############################################################
#      Checks that the needed executables are available       #
###############################################################

function validate_java()
{
	(java -version 2>&1 | grep \"1.6.*\")
	if [[ $? -ne 0 ]]; then
		echo -e "Invalid Java version detected. Only java 1.6 is supported due to changes in jarsigner in 1.7\n"
		java -version
		exit 1
	fi
}

# If passed executable's name is available return 0 (true), else return 1 (false).
# @param $1 The executable's name
function executable_in_path() 
{
  COMMAND=$1
  RES=$(command -v $COMMAND)
  if [ "$RES" ]
  then
    echo "$COMMAND is available in the PATH."
    return 0
  else
    return 1
  fi
}

# Exit with code failure 1 if the executable is not available.
# @param $1 The executable's name
function assert_executable_in_path() 
{
  COMMAND=$1
  (executable_in_path $COMMAND) || {
    echo >&2 "Couldn't find $COMMAND in the PATH."
    aborting
  }
}

# Checks that all executables needed by this script are available
assert_executable_in_path ${MAVEN} # Check that maven executable is available
assert_executable_in_path ${ECLIPSE} # Check that eclipse executable is available
assert_executable_in_path ${GIT} # Check that git executable is available
assert_executable_in_path ${SBT} # Check that sbt executable is available

validate_java

###############################################################
#                          SIGNING                            #
###############################################################

KEYSTORE_FOLDER="typesafe-keystore"
KEYSTORE_GIT_REPO=
KEYSTORE_PASS=

read -n1 -p "Would you like to sign the IDE? [y/Y/n/N] " signing; echo

if [[ "$signing" == "y" ||  "$signing" == "Y" ]]
then
  assert_executable_in_path ${KEYTOOL} # Check that keytool executable is available
  assert_version_tag_not_empty

  # Check if the keystore folder has been already pulled
  if [ ! -d "$KEYSTORE_FOLDER" ]
  then
    read -p "Please, provide the URL to the keystore git repository: " git_repo; echo
    KEYSTORE_GIT_REPO="$git_repo"
    checkout_git_repo $KEYSTORE_GIT_REPO $KEYSTORE_FOLDER
  fi
  
  # Password for using the keystore
  read -s -p "Please, provide the password for the keystore: " passw; echo
  KEYSTORE_PASS=$passw
  # Check that the password to the keystore is correct (or fail fast)
  $KEYTOOL -list -keystore ${base_dir}/${KEYSTORE_FOLDER}/typesafe.keystore -storepass ${KEYSTORE_PASS} -alias typesafe
else
  echo "The IDE build will NOT be signed."
  if [[ -z $VERSION_TAG ]]; then
	VERSION_TAG=local
  fi
fi

############## Helpers #######################

SCALAIDE_DIR=scala-ide
SCALARIFORM_DIR=scalariform
SCALA_REFACTORING_DIR=scala-refactoring
SBINARY_DIR=sbinary
SBT_DIR=xsbt


LOCAL_REPO=`pwd`/m2repo
SOURCE=${base_dir}/p2-repo
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


	cd ${base_dir}
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

	cd ${base_dir}
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

	cd ${base_dir}
}

function build_refactoring()
{
	# build scala-refactoring
	print_step "scala-refactoring"

	cd ${SCALA_REFACTORING_DIR}
	GIT_HASH="`git log -1 --pretty=format:"%h"`"
	${MAVEN} -P ${scala_profile_ide} -Dscala.version=${SCALA_VERSION} $REFACTORING_MAVEN_ARGS -Drepo.scala-ide="file:/${SOURCE}" -Dgit.hash=${GIT_HASH} clean package

	cd $base_dir

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

	cd ${base_dir}
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

	cd ${base_dir}
}

function build_ide()
{
	print_step "Building the IDE"
	cd ${SCALAIDE_DIR}

	./build-all.sh -P ${scala_profile_ide} -Dscala.version=${SCALA_VERSION} -Drepo.scala-ide.root="file:${SOURCE}" -Dversion.tag=${VERSION_TAG} clean install
	cd ${base_dir}
}

function sign_plugins()
{
    print_step "Signing"
    
	cd ${SCALAIDE_DIR}/org.scala-ide.sdt.update-site
	ECLIPSE_ALIAS=$ECLIPSE
	ECLIPSE=$(which $ECLIPSE_ALIAS) ./plugin-signing.sh ${base_dir}/${KEYSTORE_FOLDER}/typesafe.keystore typesafe ${KEYSTORE_PASS} ${KEYSTORE_PASS}
    cd ${base_dir}
}


###############################################################
#                          GIT Helpers                        #
###############################################################

function clone_git_repo_if_needed()
{
  GITHUB_REPO=$1
  FOLDER_DIR=$2
  NAME_REMOTE=$3

  if [ ! -d "$FOLDER_DIR" ]
  then
    if [[ -z "$NAME_REMOTE" ]]
    then
      # Cloning as "origin"
      $GIT clone $GITHUB_REPO $FOLDER_DIR
    else
      # Cloning as "$NAME_REMOTE"
      $GIT clone $GITHUB_REPO $FOLDER_DIR -o $NAME_REMOTE
    fi
  else
    cd $FOLDER_DIR
    # If a remote with name "$NAME_REMOTE" doesn't exists yet, then add it
    REMOTES=`$GIT remote show | awk '/'$NAME_REMOTE'/ {print $1}'`
    if [[ -z "$REMOTES" ]]
    then
      git remote add $NAME_REMOTE $GITHUB_REPO
    fi
    # In all cases, make sure to bring all changes locally
    git fetch $NAME_REMOTE
    cd $base_dir
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
  
  echo "Checking if branch $BRANCH exists in git repo ${GIT_REPO}..."
  if exist_branch_in_repo $BRANCH $GIT_REPO
  then
    echo "Branch found!"
    return 0
  else
    echo "Branch NOT found!"
    return 1
  fi
}

function assert_branch_in_repo_verbose()
{
  BRANCH=$1
  GIT_REPO=$2
  (exist_branch_in_repo_verbose $BRANCH $GIT_REPO) || aborting
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
  	echo -e "\nAborting mission."
  	exit 1
  fi 
}

function checkout_git_repo()
{
  GITHUB_REPO=$1
  FOLDER_DIR=$2
  BRANCH=$3
  REMOTE_NAME=$4

  FULL_BRANCH_NAME=$BRANCH
  if [[ "$REMOTE_NAME" ]]
  then
    FULL_BRANCH_NAME= "$REMOTE_NAME/$BRANCH"
  fi

  cd $FOLDER_DIR
	
  REFS=`$GIT show-ref $BRANCH | awk '{split($0,a," "); print a[2]}' | awk '{split($0,a,"/"); print a[2]}'`
  if [[ "$REFS" = "tags" ]]
  then
    echo "In $FOLDER_DIR, checking out tag $BRANCH"
    git checkout $BRANCH
  else
    echo "In $FOLDER_DIR, checking out branch $FULL_BRANCH_NAME"
    $GIT checkout $FULL_BRANCH_NAME
  fi
  cd $base_dir
  validate ${FOLDER_DIR}
}

###############################################################
#                            BUILD                            #
###############################################################

# At this point the version tag cannot be empty. Why? Because if the IDE build won't be signed, 
# then VERSION_TAG is set to `local`. Otherwise, if the IDE build will be signed, then the 
# VERSION_TAG must be set or the build will stop immediately.
# This is really just a sanity check.
assert_version_tag_not_empty

# Selecting Git repositories

REMOTE_NAME=origin # Name of the remote

# These are currently non-overridable defaults
SBINARY_GIT_REPO=git://github.com/scala-ide/sbinary.git
SBT_GIT_REPO=git://github.com/harrah/xsbt.git
SCALA_IDE_GIT_REPO=git://github.com/scala-ide/scala-ide.git

# Defaults can be changed
SCALARIFORM_GIT_REPO=git://github.com/mdr/scalariform.git
SCALA_REFACTORING_GIT_REPO=git://git.assembla.com/scala-refactoring.git

read -n1 -p "Do you want to build the IDE dependencies using the original repositories, or the GitHub forks under the scala-ide organization? (o/f): " original_or_fork; echo;
case "$original_or_fork" in
	o ) 
		echo "Using the original repositories"
		;;
		
	f ) 
		echo "Using the GitHub forks for $SCALARIFORM_DIR and $SCALA_REFACTORING_DIR"
		REMOTE_NAME=fork
		SCALARIFORM_FORK_GIT_REPO=git://github.com/scala-ide/scalariform.git
		SCALA_REFACTORING_FORK_GIT_REPO=git://github.com/scala-ide/scala-refactoring.git
		SCALARIFORM_GIT_REPO=$SCALARIFORM_FORK_GIT_REPO
		SCALA_REFACTORING_GIT_REPO=$SCALA_REFACTORING_FORK_GIT_REPO
		;;
		
	*)
		echo "Unexpected input"
		aborting
		;;
esac

clone_git_repo_if_needed ${SBINARY_GIT_REPO} ${SBINARY_DIR}
clone_git_repo_if_needed ${SBT_GIT_REPO} ${SBT_DIR}
clone_git_repo_if_needed ${SCALA_IDE_GIT_REPO} ${SCALAIDE_DIR}
clone_git_repo_if_needed ${SCALARIFORM_GIT_REPO} ${SCALARIFORM_DIR} $REMOTE_NAME
clone_git_repo_if_needed ${SCALA_REFACTORING_GIT_REPO} ${SCALA_REFACTORING_DIR} $REMOTE_NAME


# Selecting branches/tags to build

SBT_BRANCH=0.13
SBINARY_BRANCH=master

read -p "What branch/tag should I use for building the ${SCALAIDE_DIR}: " scala_ide_branch;
assert_branch_in_repo_verbose $scala_ide_branch $SCALA_IDE_GIT_REPO


read -p "What branch/tag should I use for building ${SCALARIFORM_DIR}: " scalariform_branch;
assert_branch_in_repo_verbose $scalariform_branch $SCALARIFORM_GIT_REPO

read -p "What branch/tag should I use for building ${SCALA_REFACTORING_DIR}: " scala_refactoring_branch;
assert_branch_in_repo_verbose $scala_refactoring_branch $SCALA_REFACTORING_GIT_REPO


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
checkout_git_repo ${SCALA_IDE_GIT_REPO} ${SCALAIDE_DIR} ${scala_ide_branch}
checkout_git_repo ${SCALARIFORM_GIT_REPO} ${SCALARIFORM_DIR} ${scalariform_branch} $REMOTE_NAME
checkout_git_repo ${SCALA_REFACTORING_GIT_REPO} ${SCALA_REFACTORING_DIR} ${scala_refactoring_branch} $REMOTE_NAME

build_sbinary
build_xsbt
build_toolchain
build_refactoring
build_scalariform
build_ide

if [[ "$signing" == "y" ||  "$signing" == "Y" ]]
then
  sign_plugins
fi
# Uber build script for Scala IDE

> One build script to rule them all.

Build script design to unify all compound builds needed around [Scala IDE][scala-ide].
It supports rebuilding everything from source, starting from Scala all the way to the product,
as well as producing the Scala IDE release or providing CI support for the Scala pull requests
validator.

The main usages are:

* generate the Scala IDE releases (IDE, plugins and bundle), with or without publishing.
* check integration of Scala IDE and the plugins nighlty.
* perform Scala IDE builds as part of the Scala pull request validator
* rebuild Scala pr validation builds locally, to study failures
* build Scala IDE against any custom version of Scala, to test changes made to the compiler

The current build works for Scala 2.10.x and 2.11.x, and Scala IDE 4.0.x.


[scala-ide]: https://github.com/scala-ide/scala-ide/
[worksheet]: https://github.com/scala-ide/scala-worksheet/

## Invocation

```bash
./uber-build <config_file> [scala_version] [scala_git_hash]
```

* `config_file` - the config file containing the build parameters. The uncommented lines override the values from `config/default.conf`.
* `scala_git_hash` - overrides the value `SCALA_GIT_HASH` defined in the config file.
* `scala_version` overrides the value `SCALA_VERSION` defined in the config file.

## scala-local-build

Builds Scala IDE from any source version of Scala.

* base config file: `scala-local-build.conf`
* relevant config parameters:
  * `SCALA_GIT_REPO` - modify to use Scala hash from a different repository
* extra command line parameters: `<scala_version> <scala_git_hash>`

## release, release-dryrun

Generates and publishes (only with `release`) a Scala IDE release, build on a released version of Scala.

* example config files: `release-30x.conf`, `release-40x-210.conf`
* relevant config parameters:
  * `OPERATION` - keep it, and commit with, `release-dryrun` most of the time. Switch to `release` only when doing the real release, after having done a successful dryrun.
  * `SCALA_VERSION` - the version of Scala to use
  * `SCALA_IDE_VERSION_TAG` - `b?` for special builds, `m?` for milestones, `rc?` for RCs, `v` for final versions.
  * `*_GIT_BRANCH` - the source to use for each project. Should be a tag when doing the publishing.
  * `*_GIT_REPO` - usefull to test tags or small fixes on your forks, before pushing the changes to the main repos.
* no extra command line parameters

## nightly

Builds all Scala IDE projects from the master branches. Used nightly to check that all masters build together.

* example config files: `nightly-4.0.x-juno-2.10.conf`
* relevant config parameters:
  * `*_GIT_BRANCH` - all should be on `master`
  * `PLUGINS` - list the plugins to build, all plugins may no work with all configurations.
* no extra command line parameters

## scala-pr-validator

Runs a build up to Scala IDE. The goal is to check that a Scala PR is not going to break Scala IDE and its dependencies.
(to document)

* config file: `validator.conf`
* config parameters should not be modified.
* This build requires an extra maven repository to fetch pre-build Scala binaries. The simplest way to set it up
is to add the following in the `~/.m2/settings.xml` file.
```xml
    <profile>
      <id>pr-scala</id>
      <repositories>
        <repository>
          <id>scala-pr-builds</id>
          <url>http://private-repo.typesafe.com/typesafe/scala-pr-validation-snapshots/</url>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
    </profile>
```
* to enable the profile, extra Maven parameters are needed. Use:
```bash
export MAVEN_ARGS="-Ppr-scala"
```
* extra command line parameters: `<scala_version>`


## scala-pr-rebuild

(to document)

# List of published releases so far

Below follows a list of published releases with the exact command that was used to build each release.

(Before this page was created we used to keep these information in a [spreadsheet document on Google Drive](https://docs.google.com/a/typesafe.com/spreadsheet/ccc?key=0Aic2QFD0IxW4dEszQUxQWFROemE5UkFuc3JncjBaQlE#gid=0))

## v4.7.1-rc3

- **With Eclipse 4.7(Oxygen)**

uber-build.sh at tag 4.7.1-rc3 with [config/release-47x-212.conf](https://github.com/scala-ide/uber-build/blob/4.7.1-rc3/config/release-47x-212.conf)

## v4.7.1-rc2

- **With Eclipse 4.7(Oxygen)**

uber-build.sh at tag 4.7.1-rc2 with [config/release-47x-212.conf](https://github.com/scala-ide/uber-build/blob/4.7.1-rc2/config/release-47x-212.conf)

## v4.7.1-rc1

- **With Eclipse 4.7(Oxygen)**

uber-build.sh at tag 4.7.1-rc1 with [config/release-47x-212.conf](https://github.com/scala-ide/uber-build/blob/4.7.1-rc1/config/release-47x-212.conf)

## v4.7.0-vfinal

- **With Eclipse 4.7(Oxygen)**

uber-build.sh at tag 4.7.0-vfinal with [config/release-47x-212.conf](https://github.com/scala-ide/uber-build/blob/4.7.0-vfinal/config/release-47x-212.conf)

## v4.7.0-rc1

- **With Eclipse 4.7(Oxygen)**

uber-build.sh at tag 4.7.0-rc1 with [config/release-47x-212.conf](https://github.com/scala-ide/uber-build/blob/4.7.0-rc1/config/release-47x-212.conf)

## v4.6.0-rc2

- **With Eclipse 4.6(Neon)**

uber-build.sh at tag 4.6.0-rc2 with [config/release-46x-212.conf](https://github.com/scala-ide/uber-build/blob/4.6.0-rc2/config/release-46x-212.conf)

## v4.6.0-rc1

- **With Eclipse 4.6(Neon)**

uber-build.sh at tag 4.6.0-rc1 with [config/release-46x-212.conf](https://github.com/scala-ide/uber-build/blob/4.6.0-rc1/config/release-46x-212.conf)

## v4.5.0-vfinal

- **With Eclipse 4.6(Neon)**

uber-build.sh at tag 4.5.0-vfinal with [config/release-45x-211.conf](https://github.com/scala-ide/uber-build/blob/4.5.0-vfinal/config/release-45x-211.conf)

## v4.5.0-rc2

- **With Eclipse 4.6(Neon)**

uber-build.sh at tag 4.5.0-rc2 with [config/release-45x-211.conf](https://github.com/scala-ide/uber-build/blob/4.5.0-rc2/config/release-45x-211.conf)

## v4.5.0-rc1

- **With Eclipse 4.6(Neon)**

uber-build.sh at tag 4.5.0-rc1 with [config/release-45x-211.conf](https://github.com/scala-ide/uber-build/blob/4.5.0-rc1/config/release-45x-211.conf)

## v4.4.1-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.4.1-vfinal with [config/release-44x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.4.1-vfinal/config/release-44x-211-luna.conf)

## v4.4.0-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.4.0-vfinal with [config/release-44x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.4.0-vfinal/config/release-44x-211-luna.conf)

## v4.4.0-rc2

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.4.0-rc2 with [config/release-44x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.4.0-rc2/config/release-44x-211-luna.conf)

## v4.4.0-rc1

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.4.0-rc1 with [config/release-44x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.4.0-rc1/config/release-44x-211-luna.conf)

## v4.3.0-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.3.0-vfinal with [config/release-43x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.3.0-vfinal/config/release-43x-211-luna.conf)

## v4.3.0-rc1

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.3.0-rc1 with [config/release-43x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.3.0-rc1/config/release-43x-211-luna.conf)

## v4.2.0-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.2.0-vfinal with [config/release-42x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.2.0-vfinal/config/release-42x-211-luna.conf)

## v4.2.0-rc3

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.2.0-rc3 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.2.0-rc3/config/release-42x-211-luna.conf)

## v4.2.0-rc2

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.2.0-rc2 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.2.0-rc2/config/release-42x-211-luna.conf)

## v4.2.0-rc1

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.2.0-rc1 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.2.0-rc1/config/release-42x-211-luna.conf)

## v4.1.1-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.1.1-vfinal with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.1.1-vfinal/config/release-41x-211-luna.conf)

## v4.1.0-vfinal_2.11.7

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.1.0-vfinal_2.11.7 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.1.0-vfinal_2.11.7/config/release-41x-211-luna.conf)

## v4.1.0-vfinal

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.1.0-vfinal with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.1.0-vfinal/config/release-41x-211-luna.conf)

## v4.1.0-rc2

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.1.0-rc2 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.1.0-rc2/config/release-41x-211-luna.conf)

## v4.1.0-rc1

- **With Eclipse 4.4(Luna)**

uber-build.sh at tag 4.1.0-rc1 with [config/release-41x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.1.0-rc1/config/release-41x-211-luna.conf)

## v4.0.0-vfinal on Scala 2.11.6

- **With Scala 2.11.4 / Eclipse 4.3(Kepler)**

uber-build.sh at tag 4.0.0-vfinal-2.11.6 with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-vfinal-2.11.6/config/release-40x-211.conf)

- **With Scala 2.11.4 / Eclipse 4.4(Luna)**

uber-build.sh at tag 4.0.0-vfinal-2.11.6 with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-vfinal-2.11.6/config/release-40x-211-luna.conf)

## v4.0.0-vfinal

- **With Scala 2.11.4 / Eclipse 4.3(Kepler)**

uber-build.sh at tag 4.0.0-vfinal with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-vfinal/config/release-40x-211.conf)

- **With Scala 2.11.4 / Eclipse 4.4(Luna)**

uber-build.sh at tag 4.0.0-vfinal with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-vfinal/config/release-40x-211-luna.conf)


## v4.0.0-rc4

- **With Scala 2.11.4 / Eclipse 4.3(Kepler)**

uber-build.sh at tag 4.0.0-rc4 with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-rc4/config/release-40x-211.conf)

- **With Scala 2.11.4 / Eclipse 4.4(Luna)**

uber-build.sh at tag 4.0.0-rc4 with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-rc4/config/release-40x-211-luna.conf)


## v4.0.0-rc1

- **With Scala 2.11.2 / Eclipse 4.3(Kepler)**

uber-build.sh at tag 4.0.0-rc1 with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-rc1/config/release-40x-211.conf)

- **With Scala 2.11.2 / Eclipse 4.4(Luna)**

uber-build.sh at tag 4.0.0-rc1 with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-rc1/config/release-40x-211-luna.conf)

##  v4.0.0-m3

- **With Scala 2.11.1 / Eclipse 4.3(Kepler)**

uber-build.sh at tag 4.0.0-m3 with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m3/config/release-40x-211.conf)

- **With Scala 2.11.1 / Eclipse 4.4(Luna)**

uber-build.sh at tag 4.0.0-m3 with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m3/config/release-40x-211-luna.conf)

## v4.0.0-m2

- **With Scala 2.10.4 / Eclipse 4.3**

uber-build.sh at tag 4.0.0-m2 with [config/release-40x-210.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m2/config/release-40x-210.conf)

- **With Scala 2.11.1 / Eclipse 4.3**

uber-build.sh at tag 4.0.0-m2 with [config/release-40x-211.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m2/config/release-40x-211.conf)

- **With Scala 2.11.1 / Eclipse 4.4**

uber-build.sh at tag 4.0.0-m2-luna with [config/release-40x-211-luna.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m2-luna/config/release-40x-211-luna.conf)

## v3.0.4-vfinal

- **With Scala 2.11.0 / Eclipse 4.3**

uber-build.sh at tag 3.0.4-vfinal-2.11.0-1 with [config/release-30x-2.11.x.conf](https://github.com/scala-ide/uber-build/blob/3.0.4-vfinal-2.11.0-1/config/release-30x-2.11.x.conf)

- **With Scala 2.11.1 / Eclipse 4.3**

uber-build.sh at tag 3.0.4-vfinal-2.11.1 with [config/release-30x-2.11.x.conf](https://github.com/scala-ide/uber-build/blob/3.0.4-vfinal-2.11.1/config/release-30x-2.11.x.conf)

- **With Scala 2.11.2 / Eclipse 4.3**

uber-build.sh at tag 3.0.4-vfinal-2.11.2 with [config/release-30x-2.11.x.conf](https://github.com/scala-ide/uber-build/blob/3.0.4-vfinal-2.11.2/config/release-30x-2.11.x.conf)

## v3.0.3-vfinal

- **With Scala 2.10.4 / Eclipse 4.3**

uber-build.sh at tag 3.0.3-vfinal-2.10.4 with [config/release-30x.conf](https://github.com/scala-ide/uber-build/blob/3.0.3-vfinal-2.10.4/config/release-30x.conf)

## v3.0.4-rc03

- **With Scala 2.11.0-RC3 / Eclipse 4.3**
used uber-build.sh [config/release-30x-2.11.x.conf](https://github.com/scala-ide/uber-build/tree/3.0.4-rc3-2.11.0-RC3/config/release-30x-2.11.x.conf)

## v3.0.4-rc01

- **With Scala 2.11.0-RC1 / Eclipse 4.3**
used uber-build.sh [config/release-30x-2.11.x.conf](https://github.com/scala-ide/uber-build/blob/3.0.4-rc01-2.11.0-RC1/config/release-30x-2.11.x.conf)

##  v3.0.3-rc01

- **With Scala 2.10.4-RC1 / Eclipse 4.3**

used uber-build.sh [config/release-30x.conf](https://github.com/scala-ide/uber-build/blob/3.0.3-rc01/config/release-30x.conf)

## <span style="color: red">v3.0.2-patch01</span>

- **With Scala 2.10.3 / Eclipse 4.3**

This is a SPECIAL RELEASE for a customer, published at http://download.scala-ide.org/patch-releases/3.0.2.v-patch01/

(using tags 3.0.2-patch01 in the uber-build and scala-ide repositories)

used uber-build.sh [config/release-3.0.x](https://github.com/scala-ide/uber-build/blob/3.0.2-patch01/config/release-30x.conf)

## v4.0.0-M1

- **With Scala 2.10.4-SNAPSHOT / Eclipse 4.3**

used uber-build.sh [config/release-40x-210.conf](https://github.com/scala-ide/uber-build/blob/4.0.0-m1-210/config/release-40x-210.conf)

## v3.0.2-vfinal

- **With Scala 2.10.3 / Eclipse 4.3**

used uber-build.sh [config/release-3.0.x](https://github.com/scala-ide/uber-build/blob/3.0.2-vfinal/config/release-30x.conf)

##  v3.0.2-rc01

- **With Scala 2.10.3-RC3 for Eclipse 4.2**

		./build-full-ide.sh ECLIPSE_PLATFORM=juno \
		   VERSION_TAG=rc01 \
		   SCALA_VERSION=2.10.3-RC3 \
		   SBT_VERSION=0.13.0 \
		   SBT_IDE_VERSION=0.13.0-on-2.10.3-RC2-for-IDE \
		   SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
		   SCALARIFORM_BRANCH=scala-ide-3.0.1\
		   SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
		   SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
		   SCALA_IDE_BRANCH=release/scala-ide-3.0.x-juno \
		   WORKSHEET_BRANCH=0.2.1 \
		   WORKSHEET_VERSION_TAG=v \
		   SCALASEARCH_BRANCH=0.2.0 \
		   SCALASEARCH_VERSION_TAG=v \
		   PLAY_BRANCH=0.4.1 \
		   TYPESAFE_IDE_VERSION_TAG=3.0.2-rc01 \
		   SIGN_BUILD=true \
		   BUILD_PLUGINS=true \
		   KEYSTORE_GIT_REPO=$1 \
		   KEYSTORE_PASS=$2 \
		   PUBLISH=dev


- **With Scala 2.10.3-RC2 for Eclipse 4.2**

```
 ./build-full-ide.sh ECLIPSE_PLATFORM=juno \
    VERSION_TAG=rc01 \
    SCALA_VERSION=2.10.3-RC2 \
    SBT_VERSION=0.13.0 \
    SBT_IDE_VERSION=0.13.0-on-2.10.3-RC2-for-IDE \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=scala-ide-3.0.1\
    SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
    SCALA_IDE_BRANCH=release/scala-ide-3.0.x-juno \
    WORKSHEET_BRANCH=0.2.1 \
    WORKSHEET_VERSION_TAG=v \
    SCALASEARCH_BRANCH=0.2.0 \
    SCALASEARCH_VERSION_TAG=v \
    PLAY_BRANCH=0.4.1 \
    TYPESAFE_IDE_VERSION_TAG=3.0.2-rc01 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

##  v4.0.0-b03

- **With Scala 2.11.0-M5 for Eclipse 4.2**

[Use this tag](https://github.com/scala-ide/uber-build/releases/tag/4.0.0-b03).

Had to introduce a new variable SBT_IDE_VERSION to inject from the outside the version of the Zinc artifacts needed by the build.

```
   ./build-full-ide.sh ECLIPSE_PLATFORM=juno \
     VERSION_TAG=b03 \
     SCALA_VERSION=2.11.0-M5 \
     SBT_VERSION=0.13.0 \
     SBT_IDE_VERSION=0.13.0-on-2.11.0-M5-for-IDE \
     SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
     SCALARIFORM_BRANCH=scala-ide-3.0.1\
     SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
     SCALA_REFACTORING_BRANCH=0.6.2-S_4.0.0-b02 \
     SCALA_IDE_BRANCH=4.0.0-b03 \
     WORKSHEET_BRANCH=0.2.1-S_4.0.0-b02 \
     WORKSHEET_VERSION_TAG=b01 \
     SCALASEARCH_BRANCH=0.2.0 \
     SCALASEARCH_VERSION_TAG=v \
     TYPESAFE_IDE_VERSION_TAG=4.0.0-b03 \
     SIGN_BUILD=true \
     BUILD_PLUGINS=true \
     KEYSTORE_GIT_REPO=$1 \
     KEYSTORE_PASS=$2 \
     PUBLISH=dev
```

## v3.0.1-vfinal / 2.10.3-RC1
- **with Scala 2.10.3-RC1 on Indigo**

**CHECK OUT TAG** release/3.0.x of the uber-build script (the new uber-build depends on having dbuild-artifacts for Sbt/zinc.

```
  ./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=v \
    SCALA_VERSION=2.10.3-RC1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/sbt/sbt.git \
    SBT_BRANCH=v0.13.0-M2 \
    SBT_VERSION=0.13.0-M2 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=scala-ide-3.0.1 \
    SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
    SCALA_IDE_BRANCH=3.0.1-vfinal \
    WORKSHEET_BRANCH=0.2.0 \
    PLAY_BRANCH=0.4.0 \
    SCALASEARCH_BRANCH=0.1.0 \
    TYPESAFE_IDE_VERSION_TAG=3.0.1-vfinal \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

- **with Scala 2.10.3-RC1 on Juno/Kepler**

**CHECK OUT TAG** release/3.0.x of the uber-build script (the new uber-build depends on having dbuild-artifacts for Sbt/zinc.

```
  ./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=v \
    SCALA_VERSION=2.10.3-RC1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/sbt/sbt.git \
    SBT_BRANCH=v0.13.0-M2 \
    SBT_VERSION=0.13.0-M2 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=scala-ide-3.0.1 \
    SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
    SCALA_IDE_BRANCH=3.0.1-vfinal-juno \
    WORKSHEET_BRANCH=0.2.0 \
    PLAY_BRANCH=0.4.0 \
    SCALASEARCH_BRANCH=0.1.0 \
    TYPESAFE_IDE_VERSION_TAG=3.0.1-vfinal \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

##  v4.0.0-b02

- **With Scala 2.11.0-M4 for Eclipse 4.2**

It is using a slightly modified version of the uber-build, to managed the fact that sbinary 0.4.2-SNAPSHOT is used instead of 0.4.1: https://github.com/skyluc/uber-build/tree/build-4.0.0-b02

```
   ./build-full-ide.sh ECLIPSE_PLATFORM=juno \
     VERSION_TAG=b02 \
     SCALA_VERSION=2.11.0-M4 \
     SBINARY_BRANCH=0.4.2-S_4.0.0-b02 \
     SBT_GIT_REPO=git://github.com/scala-ide/xsbt \
     SBT_BRANCH=v0.13.0-RC2 \
     SBT_VERSION=0.13.0-RC2 \
     SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
     SCALARIFORM_BRANCH=scala-ide-3.0.1\
     SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
     SCALA_REFACTORING_BRANCH=0.6.2-S_4.0.0-b02 \
     SCALA_IDE_BRANCH=4.0.0-b02 \
     WORKSHEET_BRANCH=0.2.1-S_4.0.0-b02 \
     WORKSHEET_VERSION_TAG=b01 \
     TYPESAFE_IDE_VERSION_TAG=4.0.0-b02 \
     SIGN_BUILD=true \
     BUILD_PLUGINS=true \
     KEYSTORE_GIT_REPO=$1 \
     KEYSTORE_PASS=$2 \
     PUBLISH=dev
```

##  v3.0.1-vfinal

- **With Scala 2.10.2 for Eclipse 3.7**

```
   ./build-full-ide.sh ECLIPSE_PLATFORM=indigo \
     VERSION_TAG=v \
     SCALA_VERSION=2.10.2 \
     SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
     SBT_GIT_REPO=git://github.com/sbt/sbt.git \
     SBT_BRANCH=v0.13.0-M2 \
     SBT_VERSION=0.13.0-M2 \
     SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
     SCALARIFORM_BRANCH=scala-ide-3.0.1 \
     SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
     SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
     SCALA_IDE_BRANCH=3.0.1-vfinal \
     WORKSHEET_BRANCH=0.2.0 \
     PLAY_BRANCH=0.3.0 \
     SCALASEARCH_BRANCH=0.1.0 \
     TYPESAFE_IDE_VERSION_TAG=3.0.1-vfinal \
     SIGN_BUILD=true \
     BUILD_PLUGINS=true \
     KEYSTORE_GIT_REPO=$1 \
     KEYSTORE_PASS=$2 \
     PUBLISH=stable
```

- **With Scala 2.10.2 for Eclipse 3.8, 4.2 and 4.3**

```
   ./build-full-ide.sh ECLIPSE_PLATFORM=juno \
     VERSION_TAG=v \
     SCALA_VERSION=2.10.2 \
     SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
     SBT_GIT_REPO=git://github.com/sbt/sbt.git \
     SBT_BRANCH=v0.13.0-M2 \
     SBT_VERSION=0.13.0-M2 \
     SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
     SCALARIFORM_BRANCH=scala-ide-3.0.1\
     SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
     SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
     SCALA_IDE_BRANCH=3.0.1-vfinal-juno \
     WORKSHEET_BRANCH=0.2.0 \
     PLAY_BRANCH=0.3.0 \
     SCALASEARCH_BRANCH=0.1.0 \
     TYPESAFE_IDE_VERSION_TAG=3.0.1-vfinal \
     SIGN_BUILD=true \
     BUILD_PLUGINS=true \
     KEYSTORE_GIT_REPO=$1 \
     KEYSTORE_PASS=$2 \
     PUBLISH=stable
```

##  v3.0.1-rc02

- **With Scala 2.10.2 for Eclipse 3.7**

```
   ./build-full-ide.sh ECLIPSE_PLATFORM=indigo \
   VERSION_TAG=rc02 \
   SCALA_VERSION=2.10.2 \
   SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
   SBT_GIT_REPO=git://github.com/sbt/sbt.git \
   SBT_BRANCH=v0.13.0-M2 \
   SBT_VERSION=0.13.0-M2 \
   SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
   SCALARIFORM_BRANCH=scala-ide-3.0.1\
   SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
   SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
   SCALA_IDE_BRANCH=3.0.1-rc2 \
   WORKSHEET_BRANCH=0.2.0 \
   TYPESAFE_IDE_VERSION_TAG=3.0.1-rc02 \
   SIGN_BUILD=true \
   BUILD_PLUGINS=true \
   KEYSTORE_GIT_REPO=$1 \
   KEYSTORE_PASS=$2 \
   PUBLISH=dev
```

- **With Scala 2.10.2 for Eclipse 4.2**

```
    ./build-full-ide.sh ECLIPSE_PLATFORM=juno \
   VERSION_TAG=rc02 \
   SCALA_VERSION=2.10.2 \
   SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
   SBT_GIT_REPO=git://github.com/sbt/sbt.git \
   SBT_BRANCH=v0.13.0-M2 \
   SBT_VERSION=0.13.0-M2 \
   SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
   SCALARIFORM_BRANCH=scala-ide-3.0.1\
   SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
   SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.1-RC2_2.10.2 \
   SCALA_IDE_BRANCH=3.0.1-rc2-juno \
   WORKSHEET_BRANCH=0.2.0 \
   TYPESAFE_IDE_VERSION_TAG=3.0.1-rc02 \
   SIGN_BUILD=true \
   BUILD_PLUGINS=true \
   KEYSTORE_GIT_REPO=$1 \
   KEYSTORE_PASS=$2 \
   PUBLISH=dev
```

## v3.0.1-rc01

- **With Scala 2.10.2 for Eclipse 3.7**

```
./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=rc01 \
    SCALA_VERSION=2.10.2 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/sbt/sbt.git \
    SBT_BRANCH=v0.13.0-M2 \
    SBT_VERSION=0.13.0-M2 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=scala-ide-3.0.1\
    SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.1-rc1 \
    WORKSHEET_BRANCH=0.2.0 \
    TYPESAFE_IDE_VERSION_TAG=3.0.1-rc01 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

- **With Scala 2.10.2 for Eclipse 4.2**

```
./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=rc01 \
    SCALA_VERSION=2.10.2 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/sbt/sbt.git \
    SBT_BRANCH=v0.13.0-M2 \
    SBT_VERSION=0.13.0-M2 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=scala-ide-3.0.1\
    SCALA_REFACTORING_GIT_REPO=git://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.1-rc1-juno \
    WORKSHEET_BRANCH=0.2.0 \
    TYPESAFE_IDE_VERSION_TAG=3.0.1-rc01 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

##  v3.0.1-b01 & v4.0.0-b01

These were "special releases" for Scala 2.10.2-RC1 and Scala 2.11.0-M3

|             |Scala IDE   |Eclipse   | Scala     | Sbt      |   Refactoring      |    Scalariform     |  Worksheet |
|-------------|------------|----------|-----------|----------|--------------------|--------------------|------------|
|2013-05-21   | 4.0.0-b01  | Indigo   |2.11.0-M3  |v0.13.0-M2|0.6.2-S_SI-4.0.0-b01|0.1.4-S_SI-3.0.0-RC1| 0.2.0-b01  |
|2013-05-23   | 3.0.1-b01  | Indigo   |2.10.2-RC1 |v0.13.0-M2|0.6.2-S_SI-4.0.0-b01|0.1.4-S_SI-3.0.0-RC1| 0.2.0-b01  |
|2013-05-23   | 3.0.1-b01  | Juno     |2.10.2-RC1 |v0.13.0-M2|0.6.2-S_SI-4.0.0-b01|0.1.4-S_SI-3.0.0-RC1| 0.2.0-b01  |


##  v3.0.0-vfinal

- **With Scala 2.9.3 for Eclipse 3.7**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=v \
    SCALA_VERSION=2.9.3 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt.git \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.9.3-RC2 \
    SCALA_IDE_BRANCH=3.0.0-vfinal \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-vfinal \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=stable
```

- **With Scala 2.10.1 for Eclipse 3.7**

```
./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=v \
    SCALA_VERSION=2.10.1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt.git \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.0-vfinal \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-vfinal \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=stable
```

- **With Scala 2.9.3 for Eclipse 4.2**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=v \
    SCALA_VERSION=2.9.3 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt.git \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.9.3-RC2 \
    SCALA_IDE_BRANCH=3.0.0-vfinal-juno \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-vfinal \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=stable
```

- **With Scala 2.10.1 for Eclipse 4.2**

```
./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=v \
    SCALA_VERSION=2.10.1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt.git \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.0-vfinal-juno \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-vfinal \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=stable
```

## v3.0.0-rc3

- **With Scala 2.9.3 for Eclipse 3.7**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=rc3 SCALA_VERSION=2.9.3 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \ <-- (This was a mistake, we should have used 0.6.0_SI-3.0.0-RC1_2.9.3-RC2)
    SCALA_IDE_BRANCH=3.0.0-RC3 \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-rc3 \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

- **With Scala 2.10.1 for Eclipse 3.7**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=indigo \
    VERSION_TAG=rc3 \
    SCALA_VERSION=2.10.1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.0-RC3 \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-rc3 \
    KEYSTORE_GIT_REPO=$1 KEYSTORE_PASS=$2 \
    PUBLISH=dev
```


- **With Scala 2.9.3 for Eclipse 4.2**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=rc3 \
    SCALA_VERSION=2.9.3 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \ <-- (This was a mistake, we should have used 0.6.0_SI-3.0.0-RC1_2.9.3-RC2)
    SCALA_IDE_BRANCH=3.0.0-RC3-juno \
    WORKSHEET_BRANCH=0.1.4 SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-rc3 \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

- **With Scala 2.10.1 for Eclipse 4.2**

```
 ./build-full-ide.sh \
    ECLIPSE_PLATFORM=juno \
    VERSION_TAG=rc3 \
    SCALA_VERSION=2.10.1 \
    SBINARY_BRANCH=0.4.1_SI-3.0.0-RC1 \
    SBT_GIT_REPO=git://github.com/scala-ide/xsbt \
    SBT_BRANCH=0.13.0-S_SI-3.0.0-RC1 \
    SCALARIFORM_GIT_REPO=git://github.com/scala-ide/scalariform.git \
    SCALARIFORM_BRANCH=0.1.4-S_SI-3.0.0-RC1 \
    SCALA_REFACTORING_GIT_REPO=https://github.com/scala-ide/scala-refactoring \
    SCALA_REFACTORING_BRANCH=0.6.0_SI-3.0.0-RC1_2.10.1-S \
    SCALA_IDE_BRANCH=3.0.0-RC3-juno \
    WORKSHEET_BRANCH=0.1.4 \
    SIGN_BUILD=true \
    BUILD_PLUGINS=true \
    TYPESAFE_IDE_VERSION_TAG=3.0.0-rc3 \
    KEYSTORE_GIT_REPO=$1 \
    KEYSTORE_PASS=$2 \
    PUBLISH=dev
```

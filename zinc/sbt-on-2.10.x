# Warning: THIS FILE IS USED IN PR VALIDATION. DO NOT MODIFY WITHOUT
#          NOTIFYING SCALA, SCALA-IDE TEAMS
#  Default Nightly job: https://jenkins-dbuild.typesafe.com:8499/job/sbt-nightly-for-ide-on-scala-2.10.x/
# - If you need a different branch ping qbranch@typesafe.com
# - If you need to modify the version number string ping ????


# This file knows how to build sbt inside Ivy and publish *maven nightly artifacts* for consumption.
# Combined, we run tests to ensure that sanity exists for these artifacts (specifically, does Zinc build/run).
# This build is *tied* to the 2.10.x scala series.  Scala's modularization requires different build files for
# both 2.10.x and 2.11.x series.  The main difference is in how modules are grabbed.
# The four projects that are sbt related are:
#
# - harrah/sbinary     * Dependency required for building sbt/sbt
# - sbt/sbt            * Build/Test/Deploys via Ivy
# - sbt/sbt-republish  * Actually releases maven artifacts
# - typesafehub/zinc   * for testing only


# If you'd like to create a "branch release" of this build, here's what you need to do:
# - Copy the sbt-on-2.10.x.properties file to a new name.
# - Override the variables in there for your purposes.
# - Create a new jenkins job where the environment variable SBT_TAG_PROPS points at your properties file.
# - Test locally with the command `SBT_VERSION_PROPERTIES_FILE=file:my.properties ./bin/dbuild sbt-on-2.10.x`
{
  // Variables that may be external.  We have the defaults here.
  vars: {
    scala-version: ${?SCALA_VERSION}
    publish-repo: ${?PUBLISH_REPO}
    sbt-version: ${?SBT_VERSION}
    sbt-tag: ${?SBT_TAG}
    sbt.snapshot.suffix: ${?SBT_SNAPSHOT_SUFFIX}
  }
  properties: [
    ${?SBT_VERSION_PROPERTIES_FILE}  # If a properties environment vairable exists, we load it
    "file:sbt-on-2.10.x.properties"
  ]
  build: {
    "projects":[
      {
        name:  "scala-lib",
        system: "ivy",
        uri:    "ivy:org.scala-lang#scala-library;"${vars.scala-version}
        set-version: ${vars.scala-version}
      }, {
        name:  "scala-compiler",
        system: "ivy",
        uri:    "ivy:org.scala-lang#scala-compiler;"${vars.scala-version}
        set-version: ${vars.scala-version}
      }, {
        name:  "scala-actors",
        system: "ivy",
        uri:    "ivy:org.scala-lang#scala-actors;"${vars.scala-version}
        set-version: ${vars.scala-version}
      }, {
        name:  "scala-reflect",
        system: "ivy",
        uri:    "ivy:org.scala-lang#scala-reflect;"${vars.scala-version}
        set-version: ${vars.scala-version}
      }, {
        name:  "specs",
        system: "ivy",
        uri:    "ivy:org.specs2#specs2_2.10;1.12.3"
        set-version: "1.12.3"
      }, {
        name:   "scalacheck",
        system: "ivy",
        uri:    "ivy:org.scalacheck#scalacheck_2.10;1.10.1"
      }, {
        name:   "sbinary",
        uri:    "git://github.com/harrah/sbinary.git#v0.4.2"
        extra: { projects: ["core"] }
      }, {
        name:   "sbt",
        uri:    "git://github.com/sbt/sbt.git#"${vars.sbt-tag}
        extra: {
          projects: ["compiler-interface",
                     "classpath","logging","io","control","classfile",
                     "process","relation","interface","persist","api",
                     "compiler-integration","incremental-compiler","compile","launcher-interface"
                    ],
          run-tests: false
          sbt-version: ${vars.sbt-build-sbt-version}
        }
      }, {
        name:   "sbt-republish",
        uri:    "http://github.com/typesafehub/sbt-republish.git#"${vars.sbt-republish-tag},
        set-version: ${vars.sbt-version}"-on-"${vars.scala-version}${vars.sbt.version.suffix}${vars.sbt.snapshot.suffix}
      }, {
        name:   "zinc",
        uri:    "https://github.com/typesafehub/zinc.git#"${vars.zinc-tag}
      }
    ],
    options:{cross-version:standard},
  }
  options: {
    deploy: [
      {
        uri=${?vars.publish-repo},
        credentials="/home/jenkinsdbuild/dbuild-josh-credentials.properties",
        projects:["sbt-republish"]
      }
    ]
    notifications: {
      send:[{
        projects: "."
        send.to: "qbranch@typesafe.com"
        when: bad
      },{ 
        projects: "."
        kind: console
        when: always
      }]
      default.send: {
        from: "jenkins-dbuild <antonio.cunei@typesafe.com>"
        smtp:{
          server: "psemail.epfl.ch"
          encryption: none
        }
      }
    }
  }
}

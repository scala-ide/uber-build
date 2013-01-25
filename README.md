# Uber build script for Scala IDE

Build script for [Scala IDE][scala-ide] (it also builds all its dependencies), the
[Worksheet][worksheet] plugin and the Typesafe IDE product.

# Usage

The script requires you to export a number of variables to correctly work (I'd highly
recommend to skim through the script before running it, if this is the first time you
are using it). If you open the script, at the top you will see a list of variables
declarations with a short description of the intended usage. Many of the variables needs
to be correctly initialized for the script to be working correctly. Failing to provide a
value will result in an error during the script execution.

At a high-level, variables are split into four groups:

* Executables that are required to correctly run the script.
* Values required to sign the script (optionals).
* GitHub repositories and branch/tag names for all projects that need to be built by the script.
* Scala version to use to build the projects (and to bundle in the Scala IDE).

For usage examples, have a look at the ``.sample`` scripts in the project's root.

## Assumptions

If want to publish binaries to the staging website you need to enable
SSH authentication with your public key for the scalaide user on our
dreamhost server.

## Warning Note

When you launch the script, **all checked out repositories will be cleaned out and
synched with the remote before building their content**. Implying that all local changes
are lost. Forever.

[scala-ide]: https://github.com/scala-ide/scala-ide/
[worksheet]: https://github.com/scala-ide/scala-worksheet/
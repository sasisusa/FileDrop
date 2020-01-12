# FileDrop

## What is FileDrop?

A script (sh) to handle files and folders from a [Dropbox account app](https://www.dropbox.com/developers/apps) with an [access token](https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/).

(To create a new dropbox app, see [Create An App](https://www.dropbox.com/developers/apps/create).)


## Requirements

* Bourne shell
* Basic commands like: curl, sed, awk, grep, ...
* A valid (Dropbox account app) access token


## Stage of development (Version)
Alpha (0.0.1)


## Examples
Display help and usage

  `./filedrop.sh -h`

Show files and folder in top folder

  `./filedrop.sh -a ACCESS_TOKEN --ls "/"`

Show all files and folder (recusive), starting from top folder

  `./filedrop.sh -a ACCESS_TOKEN --lrec "/"`

Download the complete folder "my/src/foler" as a zip file into "./dropbox-app-data"

  `./filedrop.sh -a ACCESS_TOKEN -z "my/src/foler" "./dropbox-app-data"`
  
Download the file "my/src/foler/file.txt" into "./dropbox-app-files"

  `./filedrop.sh -a ACCESS_TOKEN -g "/my/src/foler/file.txt" "./dropbox-app-files"`
  
Upload the file "./dropbox-app-files/file.txt" into "/files/infos"

  `./filedrop.sh -a ACCESS_TOKEN -u "./dropbox-app-files/file.txt" /files/infos`

Modify/process(/create) a file "file.txt" at the top folder in an editor (requirement: editor has to block the scipt)

  `./filedrop.sh -a ACCESS_TOKEN -e nano -f file.txt`


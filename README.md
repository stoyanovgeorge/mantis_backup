# Mantis Automatic Backup with rclone

## Introduction

I have written three scripts in BASH for automatic backup of the [Mantis Bug Tracker](https://www.mantisbt.org/) using rclone. I am backing up the Mantis database also the `/mantis/cfg` and `/mantis/scripts` directory and the directory containing the backup scripts. Those backups are then automatically transferred to a specific path on your Cloud storage in case of any changes.

## Requirements 

The scripts rely on:

* `xz-utils` for the archiving. I have found that the `xzip` compression level is the highest compared to other compressing formats
* [rclone](https://rclone.org/) for cloud storage upload. Rclone is a command line program to sync files and directories to and from myriads of online cloud storage search providers. 
* mysqldump - Mysqldump can be used to dump a database or a collection of databases for backup or transfer to another SQL server. This package is most likely already preinstalled on your system. 
* git - GIT is needed to clone the project to your server (optional). You can of course download the zip and extract it on your Mantis running server but I find `git` more convenient. 

You can install those packages in Ubuntu using the following command: 
```
sudo apt update && sudo apt install xz-utils rclone git -y
```

## Initial Configuration

In order the scripts to run smoothly you need to make couple of configuration of `rclone` and `mysqldump`. 

### RClone Configuration

After installation of the `rclone` package you need to configure it and to link it to your cloud storage account. This could be done by performing: 
```
rclone config
```
This will present you with coupe of choices and you need to select `n` in order to create a new remote connection:
```
n) New remote
r) Rename remote
c) Copy remote
s) Set configuration password
q) Quit config
n/r/c/s/q> n
```
The next prompt will be about the name, here you can type whatever you want.
```
name> cloud_storage
```
Next is the selection of the cloud Storage provider:
```
Type of storage to configure.
Choose a number from below, or type in your own value
 1 / Amazon Drive
   \ "amazon cloud drive"
 2 / Amazon S3 (also Dreamhost, Ceph, Minio)
   \ "s3"
 3 / Backblaze B2
   \ "b2"
 4 / Dropbox
   \ "dropbox"
 5 / Encrypt/Decrypt a remote
   \ "crypt"
 6 / Google Cloud Storage (this is not Google Drive)
   \ "google cloud storage"
 7 / Google Drive
   \ "drive"
 8 / Hubic
   \ "hubic"
 9 / Local Disk
   \ "local"
10 / Microsoft OneDrive
   \ "onedrive"
11 / Openstack Swift (Rackspace Cloud Files, Memset Memstore, OVH)
   \ "swift"
12 / SSH/SFTP Connection
   \ "sftp"
13 / Yandex Disk
   \ "yandex"
Storage> 7
```
Please note that **Google Drive** is actually number **7** and not **6**. 
Next two prompts will be about your `client_id` and `client_secret`, you can leave them blank as suggested and then you will be asked if you want to auto configure it.
```
Google Application Client Id - leave blank normally.
client_id>
Google Application Client Secret - leave blank normally.
client_secret>
Remote config
Use auto config?
 * Say Y if not sure
 * Say N if you are working on a remote or headless machine or Y didn't work
y) Yes
n) No
y/n> n
```
Here it is very **important** to type **y** only if you are connected directly to the server and have a graphical user interface with installed Internet browser. In that case `rclone` will present you with a self-hosted link to authorize `rclone` for read/write access to your cloud storage. 
I consider selecting **n** at this question as a safer option. In that case `rclone` will generate rather long link for authorization and upon authorizing it you will get an authorization code which you need to insert in the command line. With that your `rclone` configuration is done.
<br>
In the Debugging Section you can find information how you can check if your `rclone` configuration is correct. 

### Mysqldump

In order to be able to export the database automatically without user input you need to define the username and password. This could be done in the `.my.cnf`:
```
vi ~/.my.cnf
```
There you need to define the username and password in the following format: 
```
[mysqldump]
user=mantisdb_username
password=mantis_password
``` 
Don't forget to replace `mantisdb_username` with the username having access to this database and `mantis_password` with the actual password for the user. 
Then you need to change the permissions to the file to rw only for the owner:
```
chmod 600 ~/.my.cnf
```
In the Debugging Section you can find information how you can check if your `mysqldump` configuration is correct.

## Installation

First you need to clone the project with the following command: 
``` 
git clone https://github.com/stoyanovgeorge/mantis_backup.git
```
In order to automate the scripts and make them running every day you need to add an entry to your crontab:
```
crontab -e
```
You can select your text editor of choice and add the following three lines to the end of the crontab: 
```
0 1 * * * /path/to/your/mantis_backup/cfg_backup.sh
0 1 * * * /path/to/your/mantis_backup/db_backup.sh
0 1 * * * /path/to/your/mantis_backup/scripts_backup.sh
```
This will execute all three scripts at 1AM in the night. You are free to edit this to whatever interval you think is reasonable. 

## Scripts Description 

There are three different scripts. I didn't combine the scripts into one because I think these scripts could be used for other purposes and are showing in general how you can backup configuration files, databases or whole directories. <br>
The scripts are containing four functions: 
* dir_creation - during this function they are checking if the `$bkp_dir` and `$old_dir` are existing and if not it is creating them
* cfg_backup - creates a backup of the configured scripts/database/directory and compress it either to `.xz`, `.sql.xz` or `.tar.xz`
* initial_upload - this function is executed only in case there aren't any files in the `$bkp_dir`. The script is creating a backup and it pushes the backup to `$rclone_dst`. This function normally should be executed just once.
* cfg_upload - here it is looping through the files in `$bkp_dir` evaluating the md5sum of the old backup file. Then both the md5sum of the new backup and old backup are compared. If the md5sum is different then the old backup is moved to `$old_dir` and the new backup file is pushed to the `$rclone_dst`. If not the new backup is removed and the script is exited.  

### General Variables

Every script contains at the top an user defined part, consisting of the following files:

* bkp_dir - directory where the backup will be stored. If it doesn't exist the script will create it during the execution of the `dir_creation` function
* old_dir - directory where the old backups will be stored. 
* bkp_file - the name of the backup file. In my scripts I am appending the current date to it in the format: YYYYMMDD but you can change that format using the `#now` variable
* rclone_dst - that's the destination path of your cloud storage where you want the files to be uploaded. 

### db_backup.sh

Here we are making a database dump file of the Mantis database `$mantis_db` using the `mysqldump` command. You have to be sure that you have created the `.my.cnf` file as described above and that a dump file could be successfully created.<br>
By default `mysqldump` is appending a line containing a timestamp when the dump was created and this is actually messing up the mysqldump. That is why upon creation of the dump I am cutting this line with: 
```
tail -n 1 "$bkp_file" | wc -c | xargs -I {} truncate "$bkp_file" -s -{}
```
and then I am compressing the database with `xz`

### cfg_backup.sh

This file is supposed to backup a couple of `$cfgd` directories. They should point to the mantis installation directory: `config/`, `scripts/` and the last `cfgd_3` is actually the installation directory of your web server, in my case NGINX. <br>
Please note that sometimes you will have some files to which you will not have access, that's why you can use `--exclude=PATTERN` variable where you need to define the path to the excluded directories and/or files. In this case you can replace line 27: 
```
tar cfJP "$bkp_file" "$cfgd_1" "$cfgd_2" "$cfgd_3"
```
with
```
tar cfJP "$bkp_file" --exclude="$excl_dir" --exclude="$excl_file" "$cfgd_1" "$cfgd_2" "$cfgd_3"
```
Don't forget to define the `$excl_file1` and `$excl_file2` on top of your script:
```
excl_dir="/path/for/directory/exclusion"
excl_file="/path/for/file/exclusion"
```
Here the backup is stored as `.tar.xz` in order to preserve the directory structure.
<br>
Please note that I am not completely sure which directories need to be saved and this depends also to your configuration. 

### scripts_backup.sh

Here we are backing up the directory containing the scripts. This is completely optional and will help you to preserve the changes you have done to the user-defined variables. So `$cfgd_1` should point to the directory containing your backup scripts. Again here is used `.tar.xz` in order to preserve the directory structure. 

## Debugging 

### Rclone

You can check if rclone is working executing the following command:
```
rclone ls cloud_storage:/path/to/your/files
```
where the `cloud_storage` is the name of the connection you have set during the `rclone` configuration and /path/to/your/files is actually the path to the directory you want to check. If everything is fine you should be able to see a list of all the files in this directory.

### Mysqldump

You can check if the mysqldump is properly configured executing: 
```
mysqldump mantis_db > mantisdb_backup.sql
```
Again you need to replace `mantis_db` with the actual name of the database you want to backup and the mantisdb_backup.sql is actually the backup of this database. During this you should not be prompted for username and password and the `mantisdb_backup` size should be bigger than **0**. 
If it asks you for username/password, doesn't work or creates an empty dump file it means that you have a problem with the `.my.cnf` configuration or the credentials provided in the file are wrong. You can easily check that by simply connecting to the MySQL database:
```
mysql -u mantisdb_username -p
```
You will be prompted for the password and upon successful connection you would be able to execute the following: 
```
mysql -u mantisdb_username -p
Enter password:
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 53
Server version: 10.3.13-MariaDB-1:10.3.13+maria~bionic mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> SHOW DATABASES;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mantis_db           |
+--------------------+
2 rows in set (0.001 sec)

MariaDB [(none)]> USE mantis_db;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [mantis_db]> SHOW TABLES;
+-----------------------------------+
| Tables_in_mantisbt                |
+-----------------------------------+
| mantis_api_token_table            |
| mantis_bug_file_table             |
| mantis_bug_history_table          |
| mantis_bug_monitor_table          |
| mantis_bug_relationship_table     |
| mantis_bug_revision_table         |
| mantis_bug_table                  |
| mantis_bug_tag_table              |
| mantis_bug_text_table             |
| mantis_bugnote_table              |
| mantis_bugnote_text_table         |
| mantis_category_table             |
| mantis_config_table               |
| mantis_custom_field_project_table |
| mantis_custom_field_string_table  |
| mantis_custom_field_table         |
| mantis_email_table                |
| mantis_filters_table              |
| mantis_news_table                 |
| mantis_plugin_table               |
| mantis_project_file_table         |
| mantis_project_hierarchy_table    |
| mantis_project_table              |
| mantis_project_user_list_table    |
| mantis_project_version_table      |
| mantis_sponsorship_table          |
| mantis_tag_table                  |
| mantis_tokens_table               |
| mantis_user_pref_table            |
| mantis_user_print_pref_table      |
| mantis_user_profile_table         |
| mantis_user_table                 |
+-----------------------------------+
32 rows in set (0.001 sec)

MariaDB [mantis_db]>
```
If you are able to select the `mantis_db` database and show the tables everything should be fine with your credentials

## Bugs and Missing Features

Please use [Github Issues](https://github.com/stoyanovgeorge/mantis_backup/issues "Github Issues") in case you spot a bug or have an idea how to optimize the scripts.

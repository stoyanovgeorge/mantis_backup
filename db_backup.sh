#!/bin/bash

# Non-user defined variables
now="$(date +'%Y%m%d')"

# User defined variables
bkp_dir="$HOME/backup/db"
old_dir="$bkp_dir/old"
bkp_file="${bkp_dir}"/"${now}"_mantis_db.sql
db_name="mantis_db"
rclone_dst="cloud_storage:/backup/mantis/db"

bkp_file_xz="$bkp_file".xz

############################################################
############# Function Definition ##########################
############################################################

function dir_creation {
	# Creates $bkp_dir and $old_dir in case they don't exist
	if [ ! -d "$old_dir" ];
	then
		mkdir -p "$old_dir"
	fi
}

function db_backup {
	# Creates a backup of the specified DB, truncates the last line containing the comment about the creation date of the dump not to mess up the MD5SUM, and compressing it to .sql.xz format
	mysqldump "$db_name" > "$bkp_file" 

	# Cuts the last line of the file containing a comment when the backup was completed
	tail -n 1 "$bkp_file" | wc -c | xargs -I {} truncate "$bkp_file" -s -{}

	# Compress the backup to .sql.xz
	xz "$bkp_file"

	# Evaluates the md5sum of the most recent backup and compares its md5sum against the other files in the same directory. If the md5sum is the same removes the duplicated file
	md5sum_now=$(md5sum "$bkp_file_xz" | awk '{ print $1 }')

	# Debug check what's the MD5SUM of the newly created backup file
	# echo "MD5SUM of $bkp_file_xz is $md5sum_now"
}

function initial_upload {
        # Checks how many files are in the directory and if it is only one it uploads it to the $rclone_dst

        if [ "$(find "$bkp_dir" -maxdepth 1 -type f -name '*.sql.xz' -ls | wc -l)" == 1 ];
        then
                # echo "Initial Upload to $rclone_dst"
                rclone copy "$bkp_file_xz" "$rclone_dst"
        fi
}

function db_upload {
	# Loops over all the files in the $bkp_dir and then comparing the MD5SUM with the other file, if the new file has a different MD5SUM it uploads it to a google drive location if not and moves the previous file to $old_dir if not it removes the newly created DB backup. 
	for filename in $bkp_dir/*.sql.xz ;
	do	
		if [ "$filename" != "$bkp_file_xz" ];
		then 
			if [ "$md5sum_now" == "$(md5sum "$filename" | awk '{ print $1 }')" ];
			then
				rm "$bkp_file_xz"
				return 0
			else
				mv "$filename" "$old_dir"
				rclone copy "$bkp_file_xz" "$rclone_dst"
				return 0
			fi
		fi
	done
}

#############################################################
################# Program Exectuion #########################
#############################################################

dir_creation
db_backup
initial_upload
db_upload

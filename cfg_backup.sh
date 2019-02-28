#!/bin/bash

now="$(date +'%Y%m%d')"

bkp_dir="$HOME/backup/config"
old_dir="$bkp_dir/old"
bkp_file="${bkp_dir}"/"${now}"_config.tar.xz
rclone_dst="cloud_storage:/backup/mantis/config"
cfgd_1="/var/www/html/mantis/config"
cfgd_2="/var/www/html/mantis/scripts"
cfgd_3="/etc/nginx"

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

function cfg_backup {

	tar cfJP "$bkp_file" "$cfgd_1" "$cfgd_2" "$cfgd_3"

	# Evaluates the md5sum of the most recent backup and compares its md5sum against the other files in the same directory. If the md5sum is the same removes the duplicated file
	md5sum_now=$(md5sum "$bkp_file" | awk '{ print $1 }')
}

function initial_upload {
	# Checks how many files are in the directory and if it is only one it uploads it to the $rclone_dst

	if [ "$(find "$bkp_dir" -maxdepth 1 -type f -name '*.tar.xz' -ls | wc -l)" == 1 ];
	then
		# echo "Initial Upload to $rclone_dst"
		rclone copy "$bkp_file" "$rclone_dst"
	fi
}

function cfg_upload {
	# Loops over all the files in the $bkp_dir and then comparing the MD5SUM with the other file, if the new file has a different MD5SUM it uploads it to a google drive location if not and moves the previous file to $old_dir if not it removes the newly created DB backup.
	
	for filename in $bkp_dir/*.tar.xz ;
        do
                if [ "$filename" != "$bkp_file" ];
                then
                        if [ "$md5sum_now" == "$(md5sum "$filename" | awk '{ print $1 }')" ];
                        then
                                # echo "Removing the backup"
				rm "$bkp_file"
                                return 0
                        else
				# echo "Moving $filename to $old_dir and uploading it to the $rclone_dst"
                                mv "$filename" "$old_dir"
                                rclone copy "$bkp_file" "$rclone_dst"
                                return 0
                        fi
                fi
        done
}

#############################################################
################# Program Exectuion #########################
#############################################################

dir_creation
cfg_backup
initial_upload
cfg_upload

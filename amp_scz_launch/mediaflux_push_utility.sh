#!/bin/bash

# call this with data root argument, so it can be run from dev and prod independently for prescient
data_root="$1"

# get absolute path to dir script is being run from, to save history of emails in logs and find relevant functions
full_path=$(realpath $0)
launch_root=$(dirname $full_path)
repo_root="$launch_root"/..
func_root="$launch_root"/helper_functions

mediaflux_username="michaela.ennis"
passwords_path="$repo_root"/.passwords.sh
source "$passwords_path"

# make directory for logs if needed
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
# keep logs from this in a mediaflux folder
if [[ ! -d ${repo_root}/logs/MediaFlux ]]; then
	mkdir "$repo_root"/logs/MediaFlux
fi
# organize log filenames via date
cur_date=$(date +%Y%m%d)
exec >  >(tee -ia "$repo_root"/logs/MediaFlux/"$cur_date".txt)
exec 2> >(tee -ia "$repo_root"/logs/MediaFlux/"$cur_date".txt >&2)

# TODO: 
# echo to logs
# run python functions from func_root to do the actual mediaflux push (to be implemented), using dataroot, username, and password information (use mediaflux_password)

# TODO: make sure this gets called appropriately from the prescient cron script(s)! will be once at the end and handle across sites that way


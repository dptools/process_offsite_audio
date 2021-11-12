#!/bin/bash

# will call this module with arguments in main pipeline, root then study then length cutoff then db cutoff
data_root="$1"
study="$2"
length_cutoff="$3"
db_cutoff="$4"

echo "Beginning audio selection script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# body:
# actually start running the main computations
cd "$data_root"/PROTECTED/"$study"
for p in *; do # loop over all patients in the specified study folder on PHOENIX
	# first check that it is truly an OLID, that has offsite audio data
	if [[ ! -d $p/offsite_interview/processed/decrypted_audio ]]; then
		continue
	fi
	cd "$p"/offsite_interview/processed
	# can also skip over the patient if there is no new decrypted audio
	# (both this module and the steps that come after it in the main pipeline have no use for a patient with no newly processed audio)
	if [ -z "$(ls -A decrypted_audio)" ]; then	
		cd "$data_root"/PROTECTED/"$study" # back out of pt folder before skipping
   		continue
	fi

	# create a temporary folder of audios that should be sent to TranscribeMe. 
	# (if auto send is on, it will be deleted automatically by the transcript push script, otherwise this is left to be dealt with manually)
	if [[ ! -d audio_to_send ]]; then
		mkdir audio_to_send 
	fi

	# this script will go through decrypted files for the current patient and move any that meet criteria to "to_send" - also renaming them appropriately for easy pull later
	python "$func_root"/offsite_audio_send_prep.py "$data_root" "$study" "$p" "$length_cutoff" "$db_cutoff"

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done
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
# loop over all patients in the specified study folder on PHOENIX - start with open
echo "Running audio selection for open interviews"
for p in *; do 
	# first check that it is truly a patient ID that has new audio from open interviews
	if [[ ! -d processed/$p/interviews/open/temp_audio ]]; then
		continue
	fi
	cd processed/"$p"/interviews/open
	# can also skip over the patient if there is no new converted audio
	# (both this module and the steps that come after it in the main pipeline have no use for a patient with no newly processed audio)
	if [ -z "$(ls -A temp_audio)" ]; then	
		cd "$data_root"/PROTECTED/"$study" # back out of pt folder before skipping
   		continue
	fi

	# create a temporary folder of audios that should be sent to TranscribeMe. 
	# (if auto send is on, it will be deleted automatically by the transcript push script, as long as all intended audios are successfully uploaded)
	if [[ ! -d audio_to_send ]]; then
		mkdir audio_to_send 
	fi

	# this script will go through decrypted files for the current patient and move any that meet criteria to "to_send" - also renaming them appropriately for easy pull later
	python "$func_root"/interview_audio_send_prep.py "open" "$data_root" "$study" "$p" "$length_cutoff" "$db_cutoff"

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done

echo "Running audio selection for psychs interviews"
for p in *; do 
	# first check that it is truly a patient ID that has new audio from psychs interviews
	if [[ ! -d processed/$p/interviews/psychs/temp_audio ]]; then
		continue
	fi
	cd processed/"$p"/interviews/psychs
	# can also skip over the patient if there is no new converted audio
	# (both this module and the steps that come after it in the main pipeline have no use for a patient with no newly processed audio)
	if [ -z "$(ls -A temp_audio)" ]; then	
		cd "$data_root"/PROTECTED/"$study" # back out of pt folder before skipping
   		continue
	fi

	# create a temporary folder of audios that should be sent to TranscribeMe. 
	# (if auto send is on, it will be deleted automatically by the transcript push script, as long as all intended audios are successfully uploaded)
	if [[ ! -d audio_to_send ]]; then
		mkdir audio_to_send 
	fi

	# this script will go through decrypted files for the current patient and move any that meet criteria to "to_send" - also renaming them appropriately for easy pull later
	python "$func_root"/interview_audio_send_prep.py "psychs" "$data_root" "$study" "$p" "$length_cutoff" "$db_cutoff"

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done
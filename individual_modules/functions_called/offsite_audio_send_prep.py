#!/usr/bin/env python

import os
import sys
import glob
import shutil
import pandas as pd
import numpy as np

def move_audio_to_send(data_root, study, ptID, length_cutoff, db_cutoff):
	# navigate to folder of interest, load initial CSVs
	try:
		os.chdir(os.path.join(data_root, "GENERAL", study, ptID, "offsite_interview/processed"))
		dpdash_name_format = study + "-" + ptID + "-offsiteMonoAudioQC-day1to*.csv"
		dpdash_name = glob.glob(dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		dpdash_qc = pd.read_csv(dpdash_name)
		os.chdir(os.path.join(data_root, "PROTECTED", study, ptID, "offsite_interview/processed"))
		os.chdir("decrypted_audio") # now actually go into folder with audios to be checked
	except:
		# shouldn't encounter this issue ever if calling via main pipeline
		print("No new phone audio (with QC output) for input patient " + ptID + ", continuing")
		return

	# loop through the audios available in decrypted_audio
	# if acceptable will match name to desired transcript name, and move to to_send folder
	# if unacceptable will rename to prepend an error code, keep in decrypted_files
	cur_decrypted = os.listdir(".")
	for filen in cur_decrypted:
		if filen=="smile.log":
			os.remove(filen) # make sure OpenSMILE log files don't count towards the error rate!
			continue

		# match day and interview number directly in the DPDash CSV - if it doesn't match exactly 1 file give error code 0
		cur_day = int(filen.split("day")[-1].split("_")[0])
		cur_sess = int(filen.split("session")[-1].split(".")[0])
		cur_df = dpdash_qc[(dpdash_qc["day"]==cur_day) & (dpdash_qc["interview_number"]==cur_sess)]
		if cur_df.empty or cur_df.shape[0] > 1:
			error_rename = "0err" + filen
			os.rename(filen, error_rename)
			continue # move onto next file

		# now decide if file meets criteria or not. will only be one row in the df, grab the length and volume from that
		cur_length = float(cur_df["length(minutes)"].tolist()[0]) * 60.0 # convert from minutes to seconds to compare to the seconds cutoff input
		cur_db = float(cur_df["overall_db"].tolist()[0])
		if cur_length < float(length_cutoff):
			# use error code 1 to denote the file is too short - volume not even considered
			error_rename = "1err" + filen
			os.rename(filen, error_rename)
			continue # move onto next file
		if cur_db < float(db_cutoff):
			# use error code 2 to denote the file has audio quality issue
			error_rename = "2err" + filen
			os.rename(filen, error_rename)
			continue # move onto next file

		# if reach this point file is okay, should be moved to to_send
		# will be renamed so that the matching txt files later pulled from transcribme can be kept as is
		new_name = filen.split("_audio_")[0] + "_audioTranscript_" + filen.split("_audio_")[1]
		move_path = "../audio_to_send/" + new_name
		shutil.move(filen, move_path)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    move_audio_to_send(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])

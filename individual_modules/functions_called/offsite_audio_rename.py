#!/usr/bin/env python

import os
import sys
import datetime
import pandas as pd

# files decrypted by bash script are just named using top level interview folder info, so still containing date time
# this function will rename all newly decrypted files to match proper study convention, for use in summary audio QC calculations and TranscribeMe upload
# each call of function does so for one patient
def offsite_mono_rename(data_root, study, ptID):
	try:
		study_metadata_path = os.path.join(data_root,"GENERAL",study,study + "_metadata.csv")
		study_metadata = pd.read_csv(study_metadata_path)
		patient_metadata = study_metadata[study_metadata["Subject ID"] == ptID]
		consent_date_str = patient_metadata["Consent"].tolist()[0]
		consent_date = datetime.datetime.strptime(consent_date_str,"%Y-%m-%d")
	except:
		# occasionally we encounter issues with the study metadata file, so adding a check here
		print("No consent date information in the study metadata CSV for input patient " + ptID + ", or problem with input arguments")
		return

	try:
		os.chdir(os.path.join(data_root,"PROTECTED", study, ptID, "offsite_interview/processed/decrypted_audio"))
	except:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't decrypted any audio files yet for input patient " + ptID + ", or problem with input arguments") 
		return

	cur_files = os.listdir(".")
	if len(cur_files) == 0:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't decrypted any audio files yet for input patient " + ptID)
		return

	# if reach this point, there should definitely be corresponding raw audio folders
	raw_folder_paths = os.listdir(os.path.join(data_root,"PROTECTED", study, ptID, "offsite_interview/raw"))
	raw_folder_names = [x.split("/")[-1] for x in raw_folder_paths]
	raw_folder_names.sort() # the way zoom puts date/time in text in the folder name means it will always sort in chronological order
	raw_audio_formatted = [x.split(" ")[0] + "+" + x.split(" ")[1] + ".wav" for x in raw_folder_names]

	for filename in cur_files:
		if not filename.endswith(".wav"): # skip any non-audio files (and folders)
			continue

		session_num = raw_audio_formatted.index(filename) + 1

		date_str = filename.split("+")[0]
		cur_date = datetime.datetime.strptime(date_str,"%Y-%m-%d")
		day_num = (cur_date - consent_date).days + 1 # study day starts at 1 on day of consent

		new_name = study + "_" + ptID + "_offsiteInterview_audio_day" + format(day_num, '04d') + "_session" + format(session_num, '03d') + ".wav"
		os.rename(filename, new_name)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    offsite_mono_rename(sys.argv[1], sys.argv[2], sys.argv[3])
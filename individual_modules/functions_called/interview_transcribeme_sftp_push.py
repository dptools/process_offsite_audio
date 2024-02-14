#!/usr/bin/env python

import pysftp
import os
import shutil
import sys
from pathlib import Path
from typing import Optional, Dict
import pandas as pd
import json

# make sure if paramiko throws an error it will get mentioned in log files
import logging
logging.basicConfig()

def map_transcription_language(language_code: int) -> str:
	"""
	Maps the language code to the language name.

	Can be found in Data_Dictionary.

	Parameters:
		language_code: The language code.

	Returns:
		The language name.
	"""

	# 1, Cantonese | 2, Danish | 3, Dutch | 4, English | 5, French
	# 6, German | 7, Italian | 8, Korean | 9, Mandarin (TBC) | 10, Spanish
	language_code_map: Dict[int, str] = {
		1: "Cantonese",
		2: "Danish",
		3: "Dutch",
		4: "English",
		5: "French",
		6: "German",
		7: "Italian",
		8: "Korean",
		9: "Mandarin",
		10: "Spanish"
	}

	return language_code_map[language_code]


def get_transcription_language_csv(sociodemographics_file_csv_file: Path) -> Optional[int]:
	"""
	Reads the sociodemographics survey and attempts to get the language variable.
	Prescient uses RPMS CSVs for surveys.

	Returns None if the language is not found.

	Parameters:
		sociodemographics_file_csv_file: The path to the sociodemographics survey CSV file.

	Returns:
		The language code if found, otherwise None.
	"""
	language_variable = "chrdemo_assess_lang"
	sociodemographics_df = pd.read_csv(sociodemographics_file_csv_file)

	try:
		language_variable_value = sociodemographics_df[language_variable].iloc[0]
	except KeyError:
		return None
	
	# Check if language is missing
	if pd.isna(language_variable_value):
		return None
	
	return int(language_variable_value)


def get_transcription_language_json(json_file: Path) -> Optional[int]:
	"""
	Reads the REDCap JSON file and attempts to get the language variable.
	ProNET uses REDCap for surveys.

	Returns None if the language is not found.

	Parameters:
		json_file: The path to the sociodemographics survey JSON file.

	Returns:
		The language code if found, otherwise None.
	"""
	language_variable = "chrdemo_assess_lang"
	with open(json_file, "r") as f:
		json_data = json.load(f)
	
	for event_data in json_data:
		if language_variable in event_data:
			value = event_data[language_variable]
			if value != "":
				return int(value)
	
	return None


def get_transcription_language(subject_id: str, study: str, data_root: Path) -> Optional[str]:
	"""
	Attempts to get the transcription language for the participant from the sociodemographics survey.

	Returns None if the language is not found.

	Parameters:
		subject_id: The participant's ID.
		study: The study name.
		data_root: The root directory of the data.

	Returns:
		The transcription language if found, otherwise None.
	"""

	data_root = Path(data_root)
	surveys_root = data_root / "PROTECTED" / study / "raw" / subject_id / "surveys"

	# Get sociodemographics survey
	sociodemographics_files = surveys_root.glob("*sociodemographics*.csv")

	# Check if sociodemographics survey exists
	if sociodemographics_files:
		# Read sociodemographics survey
		sociodemographics_file = list(sociodemographics_files)[0]
		language_code = get_transcription_language_csv(sociodemographics_file)
	else:
		json_files = surveys_root.glob("*.Pronet.json")
		if json_files:
			json_file = list(json_files)[0]
			language_code = get_transcription_language_json(json_file)
		else:
			return None

	return map_transcription_language(int(language_code))



def transcript_push(interview_type, data_root, study, ptID, username, password, transcription_language, pipeline=False):
	# currently only expect this to be called from wrapping bash script (possibly via main pipeline), so means there definitely will be some audio to push for this ptID
	print("Pushing " + interview_type + " audio to TranscribeMe for participant " + ptID)
	# print statement useful here because the process can be slow, will give user an idea of how far along we are

	# initialize list to keep track of which audio files will need to be moved at end of patient run
	push_list = []

	# hardcode the basic properties for the transcription service, as these shouldn't change
	destination_directory = "audio"
	host = "sftp.transcribeme.com"

	try:
		directory = os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "audio_to_send")
		os.chdir(directory) 
	except:
		# if this is called by pipeline or even the modular wrapping bash script the directory will exist
		print("audio_to_send folder does not exist for patient " + ptID + " " + interview_type + ", ensure running this script from main pipeline")
		return
	
	try:
		sociodemographics_language = get_transcription_language(subject_id=ptID, study=study, data_root=data_root)
		if sociodemographics_language is not None:
			transcription_language = sociodemographics_language
	except Exception as e:
		print(f"Error getting transcription language from sociodemographics survey: {e}")
		print(f"Using default transcription language: {transcription_language}")
		pass
	
	# loop through the WAV files in to_send, push them to TranscribeMe
	for filename in os.listdir("."):
		if not filename.endswith(".wav"):
			continue
		
		# source filepath is just filename, setup desired destination path
		filename_with_lang = filename.split("session")[0] + transcription_language + "_session" + filename.split("session")[1]
		dest_path = os.path.join(destination_directory, filename_with_lang)

		# now actually attempt the push - should work unless there is an unexpected error, but of course will catch those so entire script doesn't fail
		try:
			cnopts = pysftp.CnOpts()
			cnopts.hostkeys = None # ignore hostkey
			with pysftp.Connection(host, username=username, password=password, cnopts=cnopts) as sftp:
				sftp.put(filename, dest_path)
			push_list.append(filename) # if get to this point push was successful, add to list
		except:
			# any files that had problem with push will still be in to_send after this script runs, so can just pass here
			# in future may try to catch specific types of errors to identify when the problem is incorrect login info versus something else 
			# (in the past have run out of storage space in the input folder, not sure if that specific issue could be caught by the python errors though)
			pass 

	# now move all the successfully uploaded files from to_send to pending_audio
	# if this was called via pipeline, also prepend "new+" to name as a temporary marker for email alert generation
	for filename in push_list:
		# get path to move to in the different cases
		if pipeline:
			new_name = "new+" + filename # + not used in transcript names, so will make it easy to separate prepended info back out
			new_path = "../pending_audio/" + new_name
		else:
			new_path = "../pending_audio/" + filename
		# move the file
		shutil.move(filename, new_path)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	try:
		if sys.argv[8] == "Y":
			# if called from main pipeline want to just rename the pulled files in pending_audio here, so email script can use it before deletion
			transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], pipeline=True)
		else:
			# otherwise just deleting the audio immediately
			transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
	except:
		# if pipeline argument never even provided just want to ignore, not crash
		transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])

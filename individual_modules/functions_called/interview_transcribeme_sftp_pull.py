#!/usr/bin/env python

import os
import sys
from pathlib import Path
from typing import Optional, Dict
import pandas as pd
import json

# make sure if paramiko throws an error it will get mentioned in log files
import logging
logging.basicConfig()

import pysftp

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

def transcript_pull(interview_type, data_root, study, ptID, username, password, transcription_language, pipeline=False, lab_email_path=None):
	# track transcripts that got properly pulled this time, for use in cleaning up server later
	successful_transcripts = []

	# hardcode the basic properties for the transcription service, password is only sftp-related input for now
	source_directory = "output" # need to ensure transcribeme is actually putting .txt files into the top level output directory as they are done, consistently!
	host = "sftp.transcribeme.com"

	try:
		directory = os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "pending_audio")
		os.chdir(directory) 
	except:
		# no files for this patient then
		return

	# loop through files in pending, trying to pull corresponding txt files that are in the transcribeme output folder
	cur_pending = os.listdir(".")
	if len(cur_pending) == 0:
		# no files for this patient
		return

	print("Pulling new " + interview_type + " transcripts to server for participant " + ptID + " (if available)")

	try:
		sociodemographics_language = get_transcription_language(subject_id=ptID, study=study, data_root=data_root)
		if sociodemographics_language is not None:
			transcription_language = sociodemographics_language
	except Exception as e:
		print(f"Error getting transcription language from sociodemographics survey: {e}")
		print(f"Using default transcription language: {transcription_language}")
		pass
	
	for filename in cur_pending:
		# setup expected source filepath and desired destination filepath
		rootname = filename.split(".")[0]
		transname = rootname + ".txt"
		transname_lookup = rootname.split("session")[0] + transcription_language + "_session" + rootname.split("session")[1] + ".txt"
		src_path = os.path.join(source_directory, transname_lookup)
		# for now put all pulled transcripts into the prescreening folder. eventually that will change though, will need to be random process for sites that have completed initial reviews
		local_path = os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "transcripts", "prescreening", transname)
		# now actually attempt the pull. will hit the except in all cases where the transcript isn't available yet, but don't want that to crash rest of code obviously
		try:
			cnopts = pysftp.CnOpts()
			cnopts.hostkeys = None # ignore hostkey
			with pysftp.Connection(host, username=username, password=password, cnopts=cnopts) as sftp:
				sftp.get(src_path, local_path)
			successful_transcripts.append(transname_lookup) # if we reach this line it means transcript has been successfully pulled onto PHOENIX
			# this audio is no longer pending then, decrypted copy should be deleted from briefcase
			if pipeline:
				pending_rename = "done+" + filename # + not used in transcript names, so will make it easy to separate prepended info back out
				os.rename(filename,pending_rename) # if part of pipeline will just temporarily rename with prepended code, parent script will use this to generate email and then move
		except:
			# nothing to do here, most likely need to just keep waiting on this transcript
			# in future could look into detecting types of connection errors, perhaps not always assuming a miss means not transcribed yet
			# even the current email alerts should make other issues easy to catch over time though, so not a big priority
			try:
				# seems this sometimes creates an empty file at the prescreening path, so just remove that for clarity
				os.remove(local_path)
			except:
				pass 

	# log some very basic info about success of script
	print("(" + str(len(successful_transcripts)) + " total transcripts pulled)")

	# now do cleanup on trancribeme server for those transcripts successfully pulled
	input_directory = "audio"
	prev_problem = False # for preventing repetitive warning going into the email
	for transcript in successful_transcripts:
		# will remove decrypted audio from TranscribeMe's server, as they do not need it anymore
		match_name = transcript.split(".")[0] 
		match_audio = match_name + ".wav"
		remove_path = os.path.join(input_directory, match_audio)
		# will also move the pulled transcript into an archive subfolder of output on their server (organized by study)
		cur_path = os.path.join(source_directory, transcript)
		archive_name = study + "_archive"
		archive_path = os.path.join(source_directory, archive_name, transcript)
		archive_folder = os.path.join(source_directory, archive_name) # also need just the folder path so it can be made if doesn't exist yet
		# actually connect to server to do the updates for current transcript
		# (note it hasn't been a problem previously to establish new connection each time - 
		#  but in future may want to refactor so only need to establish connection once per patient instead of per file)
		try:
			cnopts = pysftp.CnOpts()
			cnopts.hostkeys = None # ignore hostkey
			with pysftp.Connection(host, username=username, password=password, cnopts=cnopts) as sftp:
				sftp.remove(remove_path) 
				if not sftp.exists(archive_folder):
					sftp.mkdir(archive_folder)
				sftp.rename(cur_path, archive_path)
		except:
			# expect failures here to be rare (if generic connection problems successful_transcripts would likely be empty)
			print("Error cleaning up TranscribeMe server, please check on file " + match_name)
			# also add a related warning in this patient's section of email file if this was called via pipeline - but just make it a generic one liner
			if pipeline and not prev_problem:
				with open(lab_email_path, 'a') as f:
					# not a particularly urgent problem, but could go unnoticed for a long time if not notified, and best practice is to minimize number of copies/locations with decrypted audio
					warning_text = "[May have encountered a problem cleaning up completed audios for " + OLID + " on TranscribeMe server, please review manually]"
					f.write("\n") # add a blank line before the warning
					f.write(warning_text)
					f.write("\n") # and add a blank line after

				prev_problem = True # now that it's been added no need to add again if another problem arises

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	try:
		if sys.argv[8] == "Y":
			# if called from main pipeline want to just rename the pulled files in pending_audio here, so email script can use it before deletion
			transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], pipeline=True, lab_email_path=sys.argv[9])
			# should always expect a 5th argument if here, as that means coming from pipeline. otherwise no need to even enter the lab_email_path setting
		else:
			# otherwise just deleting the audio immediately
			transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
	except:
		# if pipeline argument never even provided just want to ignore, not crash
		transcript_pull(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
    
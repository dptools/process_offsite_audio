#!/usr/bin/env python

import pysftp
import os
import shutil
import sys

# make sure if paramiko throws an error it will get mentioned in log files
import logging
logging.basicConfig()

def transcript_push(data_root, study, ptID, username, password, pipeline=False):
	# currently only expect this to be called from wrapping bash script (possibly via main pipeline), so means there definitely will be some audio to push for this ptID
	print("Pushing transcripts for participant " + ptID)
	# print statement useful here because the process can be slow, will give user an idea of how far along we are

	# initialize list to keep track of which audio files will need to be moved at end of patient run
	push_list = []

	# hardcode the basic properties for the transcription service, as these shouldn't change
	destination_directory = "audio"
	host = "sftp.transcribeme.com"

	try:
		directory = os.path.join(data_root, "PROTECTED", study, ptID, "offsite_interview/processed/audio_to_send")
		os.chdir(directory) 
	except:
		# if this is called by pipeline or even the modular wrapping bash script the directory will exist
		print("audio_to_send folder does not exist for patient " + ptID + ", ensure running this script from main pipeline")
		return
	
	# loop through the WAV files in to_send, push them to TranscribeMe
	for filename in os.listdir("."):
		if not filename.endswith(".wav"):
			continue
		
		# source filepath is just filename, setup desired destination path
		dest_path = os.path.join(destination_directory, filename)

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
		if sys.argv[6] == "Y":
			# if called from main pipeline want to just rename the pulled files in pending_audio here, so email script can use it before deletion
			transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], pipeline=True)
		else:
			# otherwise just deleting the audio immediately
			transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
	except:
		# if pipeline argument never even provided just want to ignore, not crash
		transcript_push(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])

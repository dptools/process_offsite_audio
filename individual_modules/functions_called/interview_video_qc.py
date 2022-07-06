#!/usr/bin/env python

# prevent pyfeat from logging an unneccessary warning every time
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

import os
import sys
import datetime
import pandas as pd
import numpy as np
import glob

# new imports for video
import cv2
from feat import Detector

# run video QC on the newly extracted frames, also handling the file name map for videos here
def interview_video_qc(interview_type, data_root, study, ptID):
	# if can't find valid metadata info for the patient, can't move forward here
	try:
		study_metadata_path = os.path.join(data_root,"GENERAL",study,study + "_metadata.csv")
		study_metadata = pd.read_csv(study_metadata_path)
		patient_metadata = study_metadata[study_metadata["Subject ID"] == ptID]
		consent_date_str = patient_metadata["Consent"].tolist()[0]
		consent_date = datetime.datetime.strptime(consent_date_str,"%Y-%m-%d")
	except:
		# occasionally we encounter issues with the study metadata file, so adding a check here
		print("No consent date information in the study metadata CSV for input patient " + ptID + ", or problem with input arguments")
		sys.exit(1) # exit with an error code so that wrapping script knows the patient should be disregarded

	# start by looking for new files to process
	try:
		os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "video_frames"))
	except:
		# should generally not reach this warning if calling from main pipeline bash script
		print("Haven't extracted any video frames yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_folders = os.listdir(".")
	if len(cur_folders) == 0:
		# should generally not reach this warning if calling from main pipeline bash script
		print("Haven't extracted any video frames yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	# get any the folders that don't have PyFeat outputs for their frames yet
	cur_folders_unprocessed = [x for x in cur_folders if not os.path.isdir(x + "/PyFeatOutputs")]
	if len(cur_folders_unprocessed) == 0:
		print("No new videos for input patient " + ptID + " " + interview_type)
		return
	# go in chronological order
	cur_folders_unprocessed.sort()

	# set up PyFeat
	# ok to use default models for what we are tracking, need None for the others to avoid memory issues!
	detector = Detector(au_model=None,emotion_model=None)

	# loop through folders to actually process, keeping track of bare bones features for now
	final_folder_names = []
	num_frames = []
	min_faces_in_frame = []
	max_faces_in_frame = []
	mean_faces_in_frame = []
	min_face_confidence = []
	max_face_confidence = []
	mean_face_confidence = []
	min_face_area = []
	max_face_area = []
	mean_face_area = []
	for folder in cur_folders_unprocessed:
		os.chdir(folder)
		os.mkdir("PyFeatOutputsTemp") # use temp name for now so wrapping bash script will still know the newest files - that script will rename when done
		# set up lists for tracking within this interview
		frames_count = 0
		face_nums_list = []
		face_conf_list = []
		face_area_list = []
		for file in os.listdir("."):
			if not file.endswith(".jpg"):
				# only process images
				continue
			try:
				# actually load in the image
				cur_image = cv2.imread(file)
				# run PyFeat
				image_results = detector.detect_faces(cur_image)
			except:
				print("Problem running PyFeat on frame " + file + " - it will be excluded from stats for " + folder)
				continue
			# save only the most relevant features for QC for right now
			# image results is a list of lists containing the basic features for each detected face, make it into a DF first
			image_core_faces = pd.DataFrame()
			image_core_faces["FaceRectX"] = [x[0] for x in image_results]
			image_core_faces["FaceRectY"] = [x[1] for x in image_results]
			image_core_faces["FaceRectWidth"] = [x[2] for x in image_results]
			image_core_faces["FaceRectHeight"] = [x[3] for x in image_results]
			image_core_faces["FaceScore"] = [x[4] for x in image_results]
			image_core_faces["FaceNumber"] = range(image_core_faces.shape[0])
			# one file per image
			image_core_faces.to_csv("PyFeatOutputsTemp/" + file.split(".")[0] + ".csv", index=False)
			# increment stats now
			frames_count = frames_count + 1
			face_nums_list.append(image_core_faces.shape[0])
			face_conf_list.extend(image_core_faces["FaceScore"].tolist())
			cur_faces_area = [float(x) * y for x,y in zip(image_core_faces["FaceRectHeight"].tolist(),image_core_faces["FaceRectWidth"].tolist())]
			face_area_list.extend(cur_faces_area)
		
		# check if the interview failed to have any images even loaded, skip these for now along with warning log
		if frames_count == 0:
			print("No valid images were successfully extracted from " + folder + ", removing this interview from processing records for now")
			# remove the directory so it can be recognized as process failing
			os.rmdir("PyFeatOutputsTemp") # note this only works anyway if the directory is empty!
			os.chdir("..") # back out of folder before continuing loop
			continue

		# add to overall list for this interview
		final_folder_names.append(folder)
		num_frames.append(frames_count)
		min_faces_in_frame.append(np.min(face_nums_list))
		max_faces_in_frame.append(np.max(face_nums_list))
		# use round so values are reasonably viewable on DPDash
		mean_faces_in_frame.append(round(np.mean(face_nums_list),2))
		if len(face_conf_list) == 0:
			# handle case where no faces were detected at all
			min_face_confidence.append(np.nan)
			max_face_confidence.append(np.nan)
			mean_face_confidence.append(np.nan)
			min_face_area.append(np.nan)
			max_face_area.append(np.nan)
			mean_face_area.append(np.nan)
		else:
			min_face_confidence.append(round(np.min(face_conf_list),3))
			max_face_confidence.append(round(np.max(face_conf_list),3))
			mean_face_confidence.append(round(np.mean(face_conf_list),3))
			min_face_area.append(round(np.min(face_area_list),1))
			max_face_area.append(round(np.max(face_area_list),1))
			mean_face_area.append(round(np.mean(face_area_list),1))
		# back out of folder before continuing loop
		os.chdir("..") 

	# initialize DF with current stats
	new_df = pd.DataFrame()
	new_df["raw_filename"] = final_folder_names
	new_df["number_extracted_frames"] = num_frames
	new_df["minimum_faces_detected_in_frame"] = min_faces_in_frame
	new_df["maximum_faces_detected_in_frame"] = max_faces_in_frame
	new_df["mean_faces_detected_in_frame"] = mean_faces_in_frame
	new_df["minimum_face_confidence_score"] = min_face_confidence
	new_df["maximum_face_confidence_score"] = max_face_confidence
	new_df["mean_face_confidence_score"] = mean_face_confidence
	new_df["minimum_face_area"] = min_face_area
	new_df["maximum_face_area"] = max_face_area
	new_df["mean_face_area"] = mean_face_area

	# now need to add metadata columns to the csv using the raw filename parameter
	# first specify column headers for final DPDash CSV
	headers=["reftime","day","timeofday","weekday","study","patient","interview_number",
			 "number_extracted_frames","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","mean_faces_detected_in_frame", 
			 "minimum_face_confidence_score","maximum_face_confidence_score","mean_face_confidence_score",
			 "minimum_face_area","maximum_face_area","mean_face_area"]
	# initialize lists to fill in df
	# reftime column will leave blank so can just make it np.nan at the end
	study_days = []
	times = []
	week_days = []
	# study and patient list will be same thing n times, so just do at end
	int_nums=[]

	# if reach this point, there should definitely be corresponding raw audio folders - need that list to find the interview number
	raw_folder_paths = os.listdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type))
	raw_folder_names_int = [x.split("/")[-1] for x in raw_folder_paths]
	# keep only files that seem to meet the convention, also know they will always be Zoom to have video
	raw_folder_names = [x for x in raw_folder_names_int if (os.path.isdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type, x)) and len(x.split(" ")) > 1 and len(x.split(" ")[0]) == 10 and len(x.split(" ")[1]) == 8)] 
	raw_folder_names.sort() # the way zoom puts date/time in text in the folder name means it will always sort in chronological order
	raw_video_formatted = [x.split(" ")[0] + "+" + x.split(" ")[1] for x in raw_folder_names]

	# now use compiled info to get the metadata needed
	for folder in final_folder_names:
		# interview number
		session_num = raw_video_formatted.index(folder) + 1
		int_nums.append(session_num)

		# day number
		date_str = folder.split("+")[0]
		cur_date = datetime.datetime.strptime(date_str,"%Y-%m-%d")
		day_num = (cur_date - consent_date).days + 1 # study day starts at 1 on day of consent
		study_days.append(day_num)

		# weekday encoding
		cur_weekday = datetime.datetime.strptime(date_str,"%Y-%m-%d").weekday()
		dpdash_weekday = ((cur_weekday + 2) % 7) + 1 # dpdash requires 1 through 7, with 1 being Saturday, so it is different than standard datetime convention
		week_days.append(dpdash_weekday)

		# time of day
		time_str = folder.split("+")[1]
		final_time = ":".join(time_str.split("."))
		times.append(final_time)
	# final static columns
	studies = [study for x in range(len(study_days))]
	patients = [ptID for x in range(len(study_days))]
	ref_times = [np.nan for x in range(len(study_days))]

	# add the columns to the df
	new_df["reftime"] = ref_times
	new_df["day"] = study_days
	new_df["timeofday"] = times
	new_df["weekday"] = week_days
	new_df["study"] = studies
	new_df["patient"] = patients
	new_df["interview_number"] = int_nums

	# get fuller string of how the complete video would be named for processing in future
	new_names = []
	for dn,sn in zip(new_df["day"].tolist(),new_df["interview_number"].tolist()):
		new_names.append(study + "_" + ptID + "_interviewVideo_" + interview_type + "_day" + format(dn, '04d') + "_session" + format(sn, '03d') + ".mp4")
	new_df["rename"] = new_names
	# in the folder with the extracted frames and now pyfeat outputs, also add a txt that contains the eventual rename of the corresponding video file
	for og_name,ft_name in zip(new_df["raw_filename"].tolist(),new_df["rename"].tolist()):
		# name of the txt will simply be the same as the name of the folder
		log_name = os.path.join(og_name, og_name + ".txt")
		with open(log_name, 'w') as f:
			f.write(ft_name)

	# make sure columns in right order and drop the PII date column
	new_df = new_df[headers]

	# now prepare to save new CSV for this patient (or update existing CSV if there is one)
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
	# find if there are existing CSVs for this particular subject/type videos
	# convention for U24 DPDash is different, so study name in the DPDash CSV name needs to always just be last two digits of the study ID here
	output_path_format = study[-2:]+"-"+ptID+"-interviewVideoQC_" + interview_type + "-day*.csv"
	output_paths = glob.glob(output_path_format)
	# single existing DPDash file is expected - do concatenation and then delete old version (since naming convention will not overwrite)
	if len(output_paths) == 1:
		old_df = pd.read_csv(output_paths[0])
		join_csv=pd.concat([old_df, new_df])
		join_csv.reset_index(drop=True, inplace=True)
		# drop any duplicates in case audio got decrypted a second time - shouldn't happen via pipeline
		join_csv.drop_duplicates(subset=["patient", "day", "timeofday"],inplace=True)
		join_csv.sort_values(by=["day","timeofday"],inplace=True) # make sure concatenated CSV is still sorted primarily by day number and secondarily by time
		# study name in the DPDash CSV name needs to always just be the last two digits of the study ID here
		output_path_cur = study[-2:] + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day" + str(join_csv["day"].tolist()[0]) + "to" + str(join_csv["day"].tolist()[-1]) + '.csv'
		join_csv.to_csv(output_path_cur,index=False)
		return # function is now done if we are in the single existing dpdash case
	# print warning if more than 1 for this patient
	if len(output_paths) > 1:
		print("Warning - multiple DPDash CSVs exist for patient " + ptID + ". Saving current CSV separately for now")
	# with 0 or more than 1, just save this as is
	# study name in the DPDash CSV name needs to always just be last two digits of the study ID here
	output_path_cur = study[-2:] + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day" + str(study_days[0]) + "to" + str(study_days[-1]) + '.csv'
	new_df.to_csv(output_path_cur,index=False)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    interview_video_qc(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
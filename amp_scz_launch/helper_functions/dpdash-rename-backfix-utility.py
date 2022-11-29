# python script to update DPDash CSV filenames of backlog, to accomodate reversion back to using site ID in the names
# this is a one time use utility, not actively used by pipeline (can be deleted later?)

import os
import shutil
import glob

# list all relevant root paths here, uncomment as appropriate on different servers
#data_root = "/mnt/prescient/Prescient_data_sync/PHOENIX" # prescient dev
#data_root = "/mnt/prescient/Prescient_production/PHOENIX" # prescient prod
#data_root = "/mnt/ProNET/Lochness/PHOENIX" # pronet prod
# not including pronet dev, and in fact turning that cron off

all_old_dpdash_paths = glob.glob(os.path.join(data_root, "GENERAL", "*", "processed", "*", "interviews", "*", "avlqc*QC*day*.csv"))

for path in all_old_dpdash_paths:
	folder = path.split("/avlqc-")[0]
	new_name = path.split("/GENERAL/")[1].split("/processed/")[0][-2:] + "-" + path.split("/avlqc-")[1]
	new_path = os.path.join(folder, new_name)
	shutil.copyfile(path, new_path)
	# just copy so if an issue comes about we can easily revert the state
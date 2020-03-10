/* script requires a folder with only images in it and no other files. The images must be
 *  named with the following format strain_date_wormNumber.tif and optionally have a hash followed by 
 *  a number. If the first image in a series does not have this hash it will be labelled as #0
 */


/////////////////////// some preliminary variables ////////////////////////////////

//manually choose directory with images to process and store path in variable
dir=getDirectory("Select a Directory");
//directorySeparator="/"; //uncomment this line for mac/unix
directorySeparator="\\"; //uncomment this line for windows
subDirListFileName=dir+"subDirListFile.txt"


/////////////////////// functions ////////////////////////////////////////////////

function  sortFiles2dirs(subDirListFileName) {
	/* function to sort files into subdirectories by individual worms,
	 *  removing the same number of subslices from each image
	 *  and make a list of these subdirectories for future processing. 
	 *  Folder must contain ONLY image files */
	
	//first remove any existing list of subdirectories
	if (File.exists(subDirListFileName))
		File.delete(subDirListFileName);
	fileList=getFileList(dir);
	
	// ask for user input for the number of slices to keep (same for all images)
	Dialog.create("Slices to delete");
	Dialog.addString("Slices to keep:", "0-60");
	Dialog.show();
	n=Dialog.getString();
	
	// make file handle for sub directory list
	subDirListFile=File.open(subDirListFileName);

	//loop through all images and remove unwanted slices, then copy to relevan subdirectory
	for (i=0; i<fileList.length; i+=1) {
		fileNameElements=split(fileList[i],"_. ");
		
		//extract elements of worm identity from file name
		strain=fileNameElements[0];
		date=fileNameElements[1];
		wormNum=fileNameElements[2];
		subDirName=dir+strain+"_"+wormNum;
		
		//make directory as composite of strain name and worm number
		//and save directory name to file subDirListFileName for future processing
		if (File.isDirectory(subDirName)) {
			print(subDirName);
			//print(fileList[i]);
		} else {
			File.makeDirectory(subDirName);
			print(subDirListFile,subDirName);
		}
		
		//open each file, remove unwanted slices and save file into subdirectory by worm
		open(dir+fileList[i]);
		sliceNum=nSlices()/2;
		run("Stack to Hyperstack...", "order=xyzct channels=2 slices="+sliceNum+" frames=1 display=Grayscale");
		run("Make Substack...", "channels=1-2 slices="+n);
		//run("Hyperstack to Stack");
		save(subDirName+directorySeparator+fileList[i]);
		close("*");
	}	
	File.close(subDirListFile);
}





function stitchWorms(subDirListFileName) {
	/* function to stitch worms tiles together. this uses no positional information */
	
	//load list of subDirectories (one per worm)
	contents=File.openAsString(subDirListFileName);
	subDirList=split(contents,"\n");
	
	//stich the files in each subdirectory
	for (i=0; i<subDirList.length; i++) { //subDirList.length
		fileList=getFileList(subDirList[i]);

		//extract elements of worm identity from file name
		fileNameElements=split(fileList[0],"_. ");
		strain=fileNameElements[0];
		date=fileNameElements[1];
		wormNum=fileNameElements[2];

		print(subDirList[i]);
		// do unknown grid stitching and save with prefix stchd_
		run("Grid/Collection stitching", "type=[Unknown position] order=[All files in directory] directory="+subDirList[i]+
			" output_textfile_name=TileConfiguration.txt fusion_method=[Linear Blending] regression_threshold=0.70 max/avg_displacement_threshold=2.50"+ 
			" absolute_displacement_threshold=3.50 computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");
		//save(subDirList[i]+directorySeparator+"stchd_"+date+"_"+strain+"_"+wormNum+".tif");
		
		// save as OME-tiff format for deconvolution
		run("OME-TIFF...", "save="+dir+"stitched"+directorySeparator+"stchd_"+date+"_"+strain+"_"+wormNum+".ome.tif export compression=Uncompressed");
		close("*");
	}
}





function makeMontage(subDirListFileName) {
	/* function to display worm images in a single panel as a quick check of stitching.
	 *  This does NOT do correction of the intensities, so these images CANNOT be compared
	 *  one to another. It is just a quick sanity check of stitching
	 */
	//load list of subDirectories (one per worm)
	contents=File.openAsString(subDirListFileName);
	subDirList=split(contents,"\n");
	//make subdirectory for rgb images
	File.makeDirectory(dir+"RGB");
	stackSlicesFile=File.open(dir+"stackSlicesFile.txt");
	
	//get stitched file from every subdirectory
	for (i=0; i<subDirList.length; i++) {
		fileList=getFileList(subDirList[i]);
		
		//extract elements of worm identity from file name
		open(fileList[0]);
		fileNameElements=split(fileList[0],"_. ");
		strain=fileNameElements[0];
		date=fileNameElements[1];
		wormNum=fileNameElements[2];
		close("*");
		
		// open stitched file in each folder, record the number of slices it has and move to a common RGB folder 
		open(subDirList[i]+directorySeparator+"stchd_"+date+"_"+strain+"_"+wormNum+".tif");
		n=nSlices();
		print(stackSlicesFile,date+"_"+strain+"_"+wormNum+": "+n);
		run("Z Project...", "projection=[Max Intensity]");
		run("Stack to RGB");
		save(dir+"RGB"+directorySeparator+"RGB_"+date+"_"+strain+"_"+wormNum+".tif");
		close("*");
	}
	File.close(stackSlicesFile);
	//make montage file
	RGBfileList=getFileList(dir+"RGB");
	for (i=0; i<RGBfileList.length; i++) {
		open(dir+"RGB"+directorySeparator+RGBfileList[i]);
	}
	//run("Image Sequence...", "open="+dir+"RGB sort");
	run("Images to Stack", "method=[Copy (center)] name=Stack title=[] use");

	// get dimensions for montage
	rowNum=floor(sqrt(RGBfileList.length));
	colNum=round(sqrt(RGBfileList.length));
	if (rowNum==colNum && rowNum!=sqrt(RGBfileList.length)) {
		colNum+=1;
	} else if (rowNum<colNum) {
		rowNum+=1;
	} 
	run("Make Montage...", "columns="+colNum+" rows="+rowNum+" scale=0.50 font=48 label");
	save(dir+"RGB"+directorySeparator+"montage_"+date+".tif");
	close("*");
}



function saveAsOMEtiff(subDirListFileName) {
	/* save stitched files as OME-tiff format necessary for Huygens deconvolution
	to recognise two channels */
	
	//load list of subDirectories (one per worm)
	contents=File.openAsString(subDirListFileName);
	subDirList=split(contents,"\n");

	// make directory for stitched files
	File.makeDirectory(dir+"stitched");
	
	//stitch the files in each subdirectory
	for (i=0; i<subDirList.length; i++) { //subDirList.length
		fileList=getFileList(subDirList[i]);
		
		//extract elements of worm identity from file name
		open(fileList[0]);
		fileNameElements=split(fileList[0],"_. ");
		strain=fileNameElements[0];
		date=fileNameElements[1];
		wormNum=fileNameElements[2];
		close("*");

		// open the stitched file
		open(subDirList[i]+directorySeparator+"stchd_"+date+"_"+strain+"_"+wormNum+".tif");

		// save as OME-tiff
		run("OME-TIFF...", "save="+dir+"stitched"+directorySeparator+"stchd_"+date+"_"+strain+"_"+wormNum+".ome.tif export compression=Uncompressed");
		close("*");
	}
}



/////////////////////// code to run ///////////////////////////////////////

//print(subDirListFileName);

//sortFiles2dirs(subDirListFileName);

//stitchWorms(subDirListFileName);

//makeMontage(subDirListFileName);

saveAsOMEtiff(subDirListFileName);


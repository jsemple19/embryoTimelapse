/* script to take deconvoluted images and split channels needed for cellprofiler script and also
 *  generate RGB images that are comparable accross worms by setting the same max for all images
 */

 /////////////////////// some preliminary variables ////////////////////////////////

//manually choose directory with images to process and store path in variable
dir=getDirectory("Select a Directory");
//directorySeparator="/"; //uncomment this line for mac/unix
directorySeparator="\\"; //uncomment this line for windows

/////////////////////// functions ////////////////////////////////////////////////

function separateChannels(dir) {
	/* function to open deconvoluted images split the two channels and save
	 *  them separately into folder ./channels. All deconvoluted images must
	 *  be in a directory called "deconvoluted" under the main directory of images
	 *  from that day.
	 */
	
	fileList=getFileList(dir+"deconvoluted");
	File.makeDirectory(dir+"channels");
	//loop through images and only open .ids files
	for (i=0; i<fileList.length; i++) { //fileList.length
		if(endsWith(fileList[i],".ids")) {
			
			//extract elements of worm identity from file name
			fileNameElements=split(fileList[i],"_. ");
			strain=fileNameElements[2];
			date=fileNameElements[1];
			wormNum=fileNameElements[3];

			//open image and split the channels
			run("Bio-Formats Windowless Importer", "open="+dir+"deconvoluted"+
			directorySeparator+fileList[i]);
			run("Split Channels");
			
			//save each single-channel stack in channels directory with C1- or C2- prefix
			selectWindow("C1-"+fileList[i]);
			save(dir+"channels"+directorySeparator+"C1-"+date+"_"+strain+"_"+wormNum+".tif");

			selectWindow("C2-"+fileList[i]);
			save(dir+"channels"+directorySeparator+"C2-"+date+"_"+strain+"_"+wormNum+".tif");
			close("*");
		}
	}
}

function getMeasurements(dir) {
	/* function to read in all green and then all red stacks (in channels folder), 
	 *  make Z projections and obtain measurements which will be stored in text files
	 */
	fileList=getFileList(dir+"channels");

	// processing all red stacks
	for (i=0; i<fileList.length; i++) { //fileList.length
		if(startsWith(fileList[i],"C1-")) {
			//open image, z projection and measure parameters
			open(dir+"channels"+directorySeparator+fileList[i]);
			run("Z Project...", "projection=[Max Intensity]");
			run("Set Measurements...", "mean standard modal min median skewness kurtosis display redirect=None decimal=4");
			run("Measure");
			close("*");
		}
	}
	selectWindow("Results");
	saveAs("Text", dir+"resultsRed.txt");
	selectWindow("Results"); 
	run("Close");

	// processing all green stacks
	for (i=0; i<fileList.length; i++) { //fileList.length
		if(startsWith(fileList[i],"C2-")) {
			//open image, z projection and measure parameters
			open(dir+"channels"+directorySeparator+fileList[i]);
			run("Z Project...", "projection=[Max Intensity]");
			run("Set Measurements...", "mean standard modal min median skewness kurtosis display redirect=None decimal=4");
			run("Measure");
			close("*");
		}
	}
	selectWindow("Results");
	saveAs("Text", dir+"resultsGreen.txt");
	selectWindow("Results"); 
	run("Close");
}
		

/////////////////////// code to run ///////////////////////////////////////

separateChannels(dir);

getMeasurements(dir);

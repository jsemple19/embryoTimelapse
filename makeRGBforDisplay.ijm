/* script that takes separated red and green channels of an image saved in the channels folder,
 *  adjusts their intensity to a given value and makes an RGB image which is saved in the
 *  RGB4display folder
 */

/////////////////////// some preliminary variables ////////////////////////////////

//manually choose directory with images to process and store path in variable
dir=getDirectory("Select a Directory");
//directorySeparator="/"; //uncomment this line for mac/unix
directorySeparator="\\"; //uncomment this line for windows
maxRed=29648;
maxGreen=21181;

/////////////////////// functions ////////////////////////////////////////////////

function makeRGB(dir,maxRed,maxGreen) {
	//read in list of separated channel files
	fileList=getFileList(dir+"channels");
	File.makeDirectory(dir+"RGB4display");
	
	// first create lists of red and green channel files so they can be processed in parallel
	greenList=newArray();
	redList=newArray();
	for (i=0; i<fileList.length; i++) { //fileList.length
		if(startsWith(fileList[i],"C1-")) {
			redList=Array.concat(redList, fileList[i]);
		} else if (startsWith(fileList[i],"C2-")) {
			greenList=Array.concat(greenList, fileList[i]);
		}
	}

	//loop through redList and greenList set min and max, Z project and make RGB
	for (i=0; i<redList.length; i++) { //redList.length
		
		//extract wormID from fileName in each list
		redFileName=split(redList[i],"-.");
		redFileName=redFileName[1];
		greenFileName=split(greenList[i],"-.");
		greenFileName=greenFileName[1];
		
		// double check if both lists refer to the same worm
		if (redFileName==greenFileName) {
			
			//process red image
			open(dir+"channels"+directorySeparator+redList[i]);
			run("Z Project...", "projection=[Max Intensity]");
			setMinAndMax(0,maxRed);

			
			//process green image
			open(dir+"channels"+directorySeparator+greenList[i]);
			run("Z Project...", "projection=[Max Intensity]");
			setMinAndMax(0,maxGreen);


			//create RGB
			run("Merge Channels...", "c1=[MAX_C1-"+redFileName+".tif]"+
			" c2=[MAX_C2-"+greenFileName+".tif] create");
			selectWindow("Composite");
			run("Stack to RGB");
			save(dir+"RGB4display"+directorySeparator+"RGB_"+redFileName+".tif");
			//run("Close All");
		} else {
			print("not the same worm "+redFileName+" "+greenFileName);
		}
		close("*");
	}
}



function makeRGBmontage(dir) {
	/* function to display RGB files from the RGB4display directory in a panel for quick 
	 *  visual comparison
	 */

	// get list of all files in RGB4display directory
	RGBfileList=getFileList(dir+"RGB4display");
	
	for (i=0; i<RGBfileList.length; i++) {
		open(dir+"RGB4display"+directorySeparator+RGBfileList[i]);
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

	//get date from filename
	fileNameElements=split(RGBfileList[0],"_. ");
	date=fileNameElements[1];

	//make montage
	run("Make Montage...", "columns="+colNum+" rows="+rowNum+" scale=0.50 font=48 label");
	save(dir+"RGB4display"+directorySeparator+"montage_"+date+".tif");
	close("*");
}



/////////////////////// code to run ///////////////////////////////////////

makeRGB(dir,maxRed,maxGreen);

makeRGBmontage(dir);

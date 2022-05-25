#!/bin/bash
echo > bayorder.txt
## DRIVE VARIABLES
  repeated=false
  filePath="/home/harddrive/Drives/"
  repositoryFolder="HP-Server2/$(date +%Y)/$(date +%B)/"
  rowNum=0
        
## FORMATTING VARIABLES
  seperator1=--------------------------------------
  seperator=$seperator$seperator1
  seperator=$seperator$seperator1
  seperator=$seperator$seperator1
  RED='\033[0;31m'
  NC='\033[0m' # No Color
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  standardFormat=" ${NC}%5s | ${GREEN}%-35s | ${NC}%10s | ${YELLOW}%10s | ${NC}%10s | ${YELLOW}%'12.0f | ${NC}%10s |\n"
  headers=" ${NC}%5s | ${GREEN}%-12s  ${NC}%-21s | ${NC}%10s | ${YELLOW}%10s | ${NC}%10s | ${YELLOW}%12s | ${NC}%10s |\n"
  modelRows=" ${NC}%5s | ${NC}%-35s${GREEN} | ${NC}%10s | ${YELLOW}%10s | ${NC}%10s | ${YELLOW}%12s | ${NC}%10s |\n"
  flaggedFormat=" ${RED}%5s | ${RED}%-35s | ${RED}%10s | ${RED}%10s | ${RED}%10s | ${RED}%'12.0f | ${RED}%10s |\n"
  rowColor=$standardFormat
  TableWidth=130

function CountDrives() {
  clear
  echo -e "\n\n${YELLOW}One moment while we detect all the drives...${NC}"
  sleep 2
  drives=$(lsblk -o name,serial | grep ^'sd*' | awk '$0 !~ /S2D2NXAGC16716/' | awk '{print $1}')
  numOfDrives=$(lsblk -o name,serial | grep ^'sd*' | awk '$0 !~ /S2D2NXAGC16716/' | awk '{print $1}' | wc -l)
}


function PrintSeperatorLine() {
        printf "\n$seperator\n"
}



function SetUpTable() {
        printf "$headers" Slot Serial Model Drive-Size Block-Size Re-Sectors Hours SMART
        printf "%.${TableWidth}s\n" "$seperator"

        printf "$headers" Slot Serial Model ID Block-Size Re-Sectors Hours SMART > $filePath"alldrives.txt"
        printf "%.${TableWidth}s\n" "$seperator" >> $filePath"alldrives.txt"
}

function PushFilesToGitHub() {
        cd /home/harddrive/Drives/HP-Server2
        git add .
        git commit -m "Tested on $(date | cut -d " " -f 2-5)"
        git push -f origin main
}

function SaveSmartData() {

                serial=$(lsblk /dev/$1 -o NAME,SERIAL | grep ^'sd*' | awk '{print $2}')
                fullPath=$filePath$repositoryFolder$serial

		touch $fullPath.txt
                smartctl -a /dev/$drive > $fullPath.txt

}



function GetSmartAttributes() {
	hours=$(cat $fullPath.txt | grep "Accumulated power on time\|Power_On_Hours" | awk '{print $10}')
        if [ -z "$hours" ]; then
                hours=$(cat $fullPath.txt | grep "Accumulated power on time\|Power_On_Hours" | awk '{print $6}' | cut -d: -f1)
                if [ -z "$hours" ]; then hours="N/A"; fi
        fi

        real=$(cat $fullPath.txt | grep "Reallocated_Sector_Ct" | awk '{print $10}')
        if [ -z "$real" ]; then
                real=$(smartctl -x /dev/$drive | grep 'Successfully reassigned' | wc -l)
                if [ -z "$real" ]; then real="N/A"; fi
        fi

        smartTest=$(cat $fullPath.txt | grep "SMART Health Status\|SMART overall-health" | awk '{print $6}')
        if [ -z "$smartTest" ]; then
                smartTest=$(cat $fullPath.txt | grep "SMART Health Status\|SMART overall-health" | awk '{print $4}')
        	 

	fi
        driveSize=$(cat $fullPath.txt | grep "User Capacity" | rev | cut -d "[" -f 1 | cut -c 2- | rev)
}



function GetDriveAttributes() {

	serial=$(lsblk -o NAME,SERIAL | grep ^"$1" | awk '{print $2}')
	blockSize=$(lsblk -o NAME,PHY-SEC | grep ^"$1" | awk '{print $2}')
	model=$(lsblk -o NAME,Model | grep ^"$1" | cut -d " " -f 5-)
}

function PopulateTable() {
	rowColor=$standardFormat
	if [[ $hours -ge 75000 ]]; then
		rowColor=$flaggedFormat
		badDrives+=($drive)
	fi

	if [[ $real -ge 1 ]]; then
		rowColor=$flaggedFormat
		badDrives+=($drive)
	fi

        if [ "$smartTest" == "FAILED!" ]; then 
		rowColor=$flaggedFormat
		badDrives+=($drive)
        fi

        printf "$rowColor" "$driveBay" "$serial" "$driveSize" "$blockSize" "$real" "$hours" "$smartTest"
        printf "$modelRows" "$drive" "$model"
        printf "%.${TableWidth}s\n" "$seperator"

        printf "$rowColor" "$driveBay" "$serial" "$driveSize" "$blockSize" "$real" "$hours" "$smartTest" >> $filePath"alldrives.txt"
        printf "$modelRows" "$drive" "$model" >> $filePath"alldrives.txt"
        printf "%.${TableWidth}s\n" "$seperator" >> $filePath"alldrives.txt"
}

function AddToArray() {
        if [ -z "$model" ]; then
         model="-"
        fi
        if [ -z $serial ]; then
         serial="-"
        fi
        if [ -z "$driveSize" ]; then
         model="-"
        fi
        if [ -z $blockSize ]; then
         blockSize="-"
        fi
        if [ -z $real ]; then
         real="-"
        fi
        if [ -z $hours ]; then
         hours="-"
        fi
        if [ -z $smartTest ]; then
         smartTest="-"
        fi
        if [ -z $drive ]; then
         drive="-"
        fi

        fullArr+=("TRUE" "$drive" "$model" "$serial" "$blockSize" "$real" "$hours" "$smartTest" "$driveSize")
        rowNumArr+=($rowNum)
        serialArr+=($serial)
        modelArr+=($model)
        driveArr+=($drive)
        blockSizeArr+=($blockSize)
        realArr+=($real)
        hoursArr+=($hours)
        smartTestArr+=($smartTest)

}

function PrintLabel() {

	#        mmmmmmllllllllllllllll
	echo -e "       Serial:" > label.txt
	echo -e "       $serial" >> label.txt
        echo -e "       Hours:$hours" >> label.txt
        echo -e "       RS:$real" >> label.txt

	lp -d printername label.txt 1> /dev/null
}

function LocateBadDrives() {
  for badDrive in ${badDrives[@]}
  do
          echo; echo -e "${NC}Locate drive that is flashing, then ${RED}press enter."
          echo; echo -e "${RED}**DO NOT REMOVE DRIVE WHILE IT IS FLASHING**${NC}\n"

        SetUpTable
	GetDriveAttributes $badDrive
        GetSmartAttributes
        PopulateTable $badDrive

        while true; do
               smartctl -a /dev/$drive > /dev/null
        #ledctl locate={ /dev/$badDrive }
	read input #-n 1 -t 0.1 && break
        done; read -t 0.1 -n 1000000
        ledctl locate_off={ /dev/$badDrive }

  done
}

function GiveUserOptions() {

        while opt=$(zenity --title="Select Option" --text="What would you like do?:" --list --radiolist \
                --column="Select" --column="Options" --width=600 --height=400 \
                FALSE Wipe FALSE Format FALSE Locate)
        do

        case "$opt" in
        "Wipe")break;;
        "Locate")break;;
        "Format")break;;
                *) zenity --error --text="Invalid option. Try another one.";;
        esac
        done

        if [ -z $opt ]; then exit; fi
}


function SelectDrives() {

        answer=$(zenity --list --title="Choose the drives to $opt" --checklist \
                --column="Select" --column="ID" --column="Model" --column="Serial" --column="Block-Size" --column="Re-Sectors" --column="Hours" --column="SMART" --column="Size"\
                --ok-label "$opt" --width=1600 --height=800 "${fullArr[@]}")
        result=$?

        if [ -z $result ]; then
          exit
        fi
}


function FormatDrives() {
	GetDriveAttributes $1

	if [ $blockSize -ge 4000 ]; then
	  error+="4k Drive detected, System will not format $1\n"
	 # zenity --info --text="System will not format $1 bacause it is a 4k drive"
	elif [ $blockSize -eq 512 ]; then
	  error+="512 Drive detected, there is no need to format $1\n"
	else
          echo "Formatting $1"          
	  #sg_format --format /dev/$1 --size=512 &
	  xterm -e "sg_format --format /dev/$1 --size=512; sleep 5" &
	fi
}

## This will pull the SMART data on the drive ove and over until the user hits a button
## This flases the light on the drive allowing the user to find it
function LocateDrives() {

          echo "Locating $1"
   	  echo; echo -e "${NC}Locate drive that is flashing, then ${RED}press enter."
 	  echo; echo -e "${RED}**DO NOT REMOVE DRIVE WHILE IT IS FLASHING**${NC}\n"

        SetUpTable
        GetDriveAttributes $1
	drive=$1
	GetSmartAttributes
        GetPhysicalLocation
	PopulateTable


   	while true; do 
 		smartctl -a /dev/$1 > /dev/null
 	read -n 1 -t 0.1 && break
   	done; read -t 0.1 -n 1000000
}

function WipeDrives() {
        echo "Wiping $1"
        openSeaChest_Erase -d /dev/$1 --showEraseSupport 1> /home/harddrive/$1.txt &
        
        sleep 1

        cat $1.txt | head -n 11 | tail -n 1 | cut -c 4-
        


}

## This takes in all the selected data from the disk selection gui and puts it into an array to be cycled through
## Depending on which action the user chose it runs the cooresponding script
function CollectThoughts() {
	IFS='|' read -r -a selectedDrives <<< "$answer"
	count=1
	for selection in ${selectedDrives[@]}
	do
	  ((count=$count+1))

          case "$opt" in
          
            "Wipe") 
                WipeDrives $selection
                ;;
          
            "Format") 
                FormatDrives $selection;
	        if [ $count -eq ${#selectedDrives[@]} ]; then zenity --warning --title="Could not format the following drives" --text="$error"; fi
	        ;;
          
            "Locate") 
                LocateDrives $selection
                ;;
          
            *) ;;
          esac
	done
}

function GoAgain() {
    if zenity --question --text="Would you like to print Drive Labels?"
    then
    	zenity --info --text="Printing.."
	PrintLabel
    print=TRUE
    else
    print=FALSE
    fi
}

## This is to locate the physical port a disk is plugged into
## Find this by using command   ls -la /dev/disk/by-path | grep ' 9 '
## This will allow programmer to see which physical port a particular disk "/dev/sd?" is connected to
## If script is run on new machine these need to be recalculated manually
function GetPhysicalLocation() {
	driveBay=$(ls -la /dev/disk/by-path | grep ' 9 ' | grep $drive | awk '{print $9}' | cut -d'-' -f5)

       # echo -e """$driveBay"""")driveBay=;;" >> /home/harddrive/bayorder.txt

          case "$driveBay" in
                "phy2")driveBay=3;;
                "phy1")driveBay=2;;
                "phy0")driveBay=1;;
                "phy3")driveBay=4;;
                "phy4")driveBay=5;;
                "phy5")driveBay=6;;
                "phy6")driveBay=7;;
                "phy7")driveBay=8;;
                "phy8")driveBay=9;;
                "phy9")driveBay=10;;
                "phy10")driveBay=11;;
                "phy11")driveBay=12;;
            *);;
           esac

}

main() {
        CountDrives
        PrintSeperatorLine
        echo -e "\t$numOfDrives drives have been detected"
        
        PrintSeperatorLine
        #GiveUserOptions
        SetUpTable
        #GoAgain

        for drive in ${drives[@]}
        do
          SaveSmartData $drive
	  GetDriveAttributes $drive
          GetSmartAttributes
	  GetPhysicalLocation $drive
          PopulateTable
          (( rowNum=$rowNum + 1 ))
          AddToArray

          if [ "$print" == "TRUE" ]; then
	    PrintLabel
          fi
        done

        echo Pushing Files
        PushFilesToGitHub 1> /home/harddrive/gitoutput.txt

        GiveUserOptions
        SelectDrives
        CollectThoughts

        #htop -F /dev/sd


 #    while true; do
    	
    	#CollectThoughts
 #        GoAgain
 #    done
}


## Main function is called while pushing all error messages to /dev/null
main  2>> /home/harddrive/errors.txt

